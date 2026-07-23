-- 滚动条 buffer 内容与 map/thumb/cursor/marker extmark 图层

local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local map_view = require('vv-scrollbar.features.map_view')
local markers = require('vv-scrollbar.features.markers')
local content = require('vv-scrollbar.ui.content')

local M = {}

local ns = api.nvim_create_namespace('vv-scrollbar')
local LAYER_PRIORITY = {
  map = 1,
  syntax = 2,
  thumb = 3,
  cursor = 4,
}

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

---@param parent integer
---@param bar VVScrollbarBar
---@param viewport table
---@param map_mode? 'viewport'|'fit'
---@param winbar_offset integer
---@param dragging? VVScrollbarDragState
---@param refresh fun()
function M.render(parent, bar, viewport, map_mode, winbar_offset, dragging, refresh)
  local cfg = config.current()
  local width = api.nvim_win_get_width(bar.win)
  local track_width = bar.track_width
  local has_map_view = map_mode ~= nil
  local map_layout = map_mode
      and map_view.resolve_layout(viewport, dragging and dragging.map_top, map_mode)
    or nil
  local map_columns = has_map_view and map_view.resolve_columns(track_width) or nil
  local content_lines, content_id, map_highlights = content.build({
    buf = viewport.buf,
    height = viewport.height,
    track_width = track_width,
    width = width,
    winbar_offset = winbar_offset,
    map_layout = map_layout,
    map_columns = map_columns,
    refresh = refresh,
  })

  bar.map_layout = map_layout
  bar.map_mode = map_mode
  bar.map_columns = map_columns
  if map_layout then
    bar.thumb_row = map_layout.thumb_row
    bar.thumb_height = map_layout.thumb_height
  end

  content.ensure(bar, content_lines, width, content_id)
  api.nvim_buf_clear_namespace(bar.buf, ns, 0, -1)

  local row_markers = markers.collect(parent, viewport, {
    cursor = not has_map_view,
    track_width = map_columns and map_columns.marker_width or track_width,
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
      local map_start_col = vim.str_byteindex(line, map_columns.map_start_col)
      local map_end_col = vim.str_byteindex(
        line,
        map_columns.map_start_col + map_columns.map_width
      )
      local track_end_col = vim.str_byteindex(line, map_columns.track_width)
      if map_end_col > map_start_col then
        api.nvim_buf_set_extmark(bar.buf, ns, buf_row, map_start_col, {
          end_col = map_end_col,
          hl_group = 'VVScrollbarMapView',
          priority = LAYER_PRIORITY.map,
        })
      end

      for _, span in ipairs(map_highlights and map_highlights[buf_row + 1] or {}) do
        local start_col = vim.str_byteindex(line, span.start_col)
        local end_col = vim.str_byteindex(line, span.end_col)
        if end_col > start_col then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, start_col, {
            end_col = end_col,
            hl_group = span.hl_group,
            priority = LAYER_PRIORITY.syntax,
          })
        end
      end

      if in_thumb then
        if cfg.map_view.preserve_map_under_thumb and track_end_col > 0 then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            end_col = track_end_col,
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

      if row == cursor_row and map_end_col > map_start_col then
        local cursor = cfg.map_view.cursor
        if cursor.style == 'dots' then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, map_start_col, {
            end_col = map_end_col,
            hl_group = 'VVScrollbarMapCursor',
            priority = LAYER_PRIORITY.cursor,
          })
        elseif cursor.style == 'line' then
          local symbol = markers.cell(cursor.symbol)
          local cursor_width = math.min(cursor.width, map_columns.map_width)
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            virt_text = { { string.rep(symbol, cursor_width), 'VVScrollbarMapCursor' } },
            virt_text_win_col = map_columns.map_start_col
              + (cursor.side == 'right' and map_columns.map_width - cursor_width or 0),
            hl_mode = 'combine',
            priority = LAYER_PRIORITY.cursor,
          })
        elseif cursor.style == 'full' then
          api.nvim_buf_set_extmark(bar.buf, ns, buf_row, 0, {
            virt_text = {
              {
                string.rep(markers.cell(cfg.symbols.cursor), map_columns.map_width),
                'VVScrollbarCursor',
              },
            },
            virt_text_win_col = map_columns.map_start_col,
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
      local marker_track_width = map_columns and map_columns.marker_width or track_width
      local chunks, side = marker_chunks(
        marker,
        marker_track_width,
        cfg,
        in_thumb and thumb_hl or nil
      )
      local marker_width = chunks_width(chunks)
      local win_col = map_columns
          and map_view.marker_col(map_columns, marker_width)
        or (side == 'right' and math.max(track_width - marker_width, 0) or 0)
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
