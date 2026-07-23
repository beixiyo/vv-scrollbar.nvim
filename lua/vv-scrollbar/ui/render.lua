-- 滚动条 buffer 内容与 map/thumb/cursor/marker extmark 图层

local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local map_view = require('vv-scrollbar.features.map_view')
local markers = require('vv-scrollbar.features.markers')

local M = {}

local ns = api.nvim_create_namespace('vv-scrollbar')
local LAYER_PRIORITY = {
  map = 1,
  thumb = 2,
  cursor = 3,
}

---@param bar VVScrollbarBar
---@param lines string[]
---@param width integer
---@param content_id string
local function ensure_lines(bar, lines, width, content_id)
  if bar.content_id == content_id and bar.width == width then return end

  vim.bo[bar.buf].modifiable = true
  api.nvim_buf_set_lines(bar.buf, 0, -1, false, lines)
  vim.bo[bar.buf].modifiable = false
  bar.width = width
  bar.content_id = content_id
end

---@param chunks string[][]
---@return integer
local function chunks_width(chunks)
  local width = 0
  for _, chunk in ipairs(chunks) do
    width = width + fn.strdisplaywidth(chunk[1])
  end
  return width
end

---@param marker VVScrollbarMarker
---@param track_width integer
---@param cfg VVScrollbarConfig
---@param background_hl? string
---@return string[][]
---@return 'left'|'right'
local function marker_chunks(marker, track_width, cfg, background_hl)
  local marker_text = marker.text
  if marker.fill_width then marker_text = string.rep(marker.text, track_width) end
  local chunks = marker.chunks or { { marker_text, marker.hl } }
  if background_hl then
    local composed = {}
    for index, chunk in ipairs(chunks) do
      composed[index] = chunk[2] == 'VVScrollbarTrack' and { chunk[1], background_hl } or chunk
    end
    chunks = composed
  end
  return chunks, cfg.map_view.marker_position
end

---@param bar VVScrollbarBar
---@param row integer
---@param marker VVScrollbarMarker
---@param win_col integer
---@param marker_width integer
local function set_marker_hits(bar, row, marker, win_col, marker_width)
  local hits = {}
  if marker.hits then
    for _, hit in ipairs(marker.hits) do
      hits[#hits + 1] = {
        start_col = win_col + hit.start_col,
        end_col = win_col + hit.end_col,
        source_line = hit.source_line,
      }
    end
  elseif marker.source_line then
    hits[1] = {
      start_col = win_col,
      end_col = win_col + marker_width,
      source_line = marker.source_line,
    }
  end
  if #hits > 0 then bar.marker_hits[row] = hits end
end

---@param buf integer
---@param height integer
---@param track_width integer
---@param width integer
---@param winbar_offset integer
---@param map_layout? VVScrollbarMapLayout
---@param refresh fun()
---@return string[]
---@return string
local function content(buf, height, track_width, width, winbar_offset, map_layout, refresh)
  local lines = {}
  if map_layout then
    local map_lines, cache_id = map_view.lines(
      buf,
      map_layout.content_height,
      track_width,
      refresh
    )
    local right_fill = string.rep(' ', math.max(width - track_width, 0))
    if winbar_offset > 0 then lines[1] = string.rep(' ', width) end

    for index = 1, height do
      local line = map_lines[map_layout.top_row + index] or string.rep(' ', track_width)
      lines[index + winbar_offset] = line .. right_fill
    end
    return lines, table.concat({
      'map',
      buf,
      cache_id,
      width,
      winbar_offset,
      map_layout.top_row,
    }, ':')
  end

  local fill = string.rep(' ', width)
  for index = 1, height + winbar_offset do lines[index] = fill end
  return lines, table.concat({ 'track', height, width, winbar_offset }, ':')
end

---@param parent integer
---@param bar VVScrollbarBar
---@param viewport table
---@param has_map_view boolean
---@param winbar_offset integer
---@param dragging? VVScrollbarDragState
---@param refresh fun()
function M.render(parent, bar, viewport, has_map_view, winbar_offset, dragging, refresh)
  local cfg = config.current()
  local width = api.nvim_win_get_width(bar.win)
  local track_width = bar.track_width
  local map_layout = has_map_view
      and map_view.resolve_layout(viewport, dragging and dragging.map_top)
    or nil
  local content_lines, content_id = content(
    viewport.buf,
    viewport.height,
    track_width,
    width,
    winbar_offset,
    map_layout,
    refresh
  )

  bar.map_layout = map_layout
  if map_layout then
    bar.thumb_row = map_layout.thumb_row
    bar.thumb_height = map_layout.thumb_height
  end

  ensure_lines(bar, content_lines, width, content_id)
  api.nvim_buf_clear_namespace(bar.buf, ns, 0, -1)

  local row_markers = markers.collect(parent, viewport, {
    cursor = not has_map_view,
    track_width = track_width,
  })
  local cursor_row
  if map_layout and cfg.markers.cursor and parent == api.nvim_get_current_win() then
    local cursor = api.nvim_win_get_cursor(parent)
    cursor_row = map_view.line_to_row(map_layout, cursor[1])
  end

  bar.row_markers = row_markers
  bar.marker_hits = {}

  local thumb_hl = dragging and dragging.moved and 'VVScrollbarHover' or 'VVScrollbarThumb'
  local thumb_text = string.rep(markers.cell(cfg.symbols.thumb), track_width)
  local track_text = string.rep(' ', track_width)

  for row = 0, viewport.height - 1 do
    local buf_row = row + winbar_offset
    local in_thumb = row >= bar.thumb_row and row < bar.thumb_row + bar.thumb_height
    if has_map_view then
      local line = content_lines[buf_row + 1] or ''
      local map_end_col = #line - math.max(width - track_width, 0)
      if map_end_col > 0 then
        api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
          end_col = map_end_col,
          hl_group = 'VVScrollbarMapView',
          priority = LAYER_PRIORITY.map,
        })
      end

      if in_thumb then
        if cfg.map_view.preserve_map_under_thumb and map_end_col > 0 then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            end_col = map_end_col,
            hl_group = thumb_hl,
            priority = LAYER_PRIORITY.thumb,
          })
        else
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            virt_text = { { thumb_text, thumb_hl } },
            virt_text_pos = 'overlay',
            priority = LAYER_PRIORITY.thumb,
          })
        end
      end

      if row == cursor_row and map_end_col > 0 then
        local cursor = cfg.map_view.cursor
        if cursor.style == 'dots' then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            end_col = map_end_col,
            hl_group = 'VVScrollbarMapCursor',
            priority = LAYER_PRIORITY.cursor,
          })
        elseif cursor.style == 'line' then
          local symbol = markers.cell(cursor.symbol)
          local cursor_width = math.min(cursor.width, track_width)
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            virt_text = { { string.rep(symbol, cursor_width), 'VVScrollbarMapCursor' } },
            virt_text_win_col = cursor.side == 'right' and track_width - cursor_width or 0,
            hl_mode = 'combine',
            priority = LAYER_PRIORITY.cursor,
          })
        elseif cursor.style == 'full' then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            virt_text = {
              { string.rep(markers.cell(cfg.symbols.cursor), track_width), 'VVScrollbarCursor' },
            },
            virt_text_win_col = 0,
            hl_mode = 'combine',
            priority = LAYER_PRIORITY.cursor,
          })
        end
      end
    else
      api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
        virt_text = {
          { in_thumb and thumb_text or track_text, in_thumb and thumb_hl or 'VVScrollbarTrack' },
        },
        virt_text_pos = 'overlay',
        priority = LAYER_PRIORITY.map,
      })
    end

    local marker = row_markers[row]
    if marker then
      local chunks, side = marker_chunks(
        marker,
        track_width,
        cfg,
        in_thumb and thumb_hl or nil
      )
      local marker_width = chunks_width(chunks)
      local win_col = side == 'right' and math.max(track_width - marker_width, 0) or 0
      local extmark = {
        virt_text = chunks,
        hl_mode = 'combine',
        priority = marker.priority,
      }
      if has_map_view then
        extmark.virt_text_win_col = win_col
        set_marker_hits(bar, row, marker, win_col, marker_width)
      else
        extmark.virt_text_pos = 'overlay'
      end
      api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, extmark)
    end
  end
end

return M
