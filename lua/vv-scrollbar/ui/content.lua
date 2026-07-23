-- 滚动条 buffer 行内容：地图切片、marker lane 留白与缓存 identity

local api = vim.api

local map_view = require('vv-scrollbar.features.map_view')

local M = {}

---@param bar VVScrollbarBar
---@param lines string[]
---@param width integer
---@param content_id string
function M.ensure(bar, lines, width, content_id)
  if bar.content_id == content_id and bar.width == width then return end

  vim.bo[bar.buf].modifiable = true
  api.nvim_buf_set_lines(bar.buf, 0, -1, false, lines)
  vim.bo[bar.buf].modifiable = false
  bar.width = width
  bar.content_id = content_id
end

---@param opts { buf: integer, height: integer, track_width: integer, width: integer, winbar_offset: integer, map_layout?: VVScrollbarMapLayout, map_columns?: VVScrollbarMapColumns, refresh: fun() }
---@return string[]
---@return string
function M.build(opts)
  local lines = {}
  local map_layout = opts.map_layout
  local map_columns = opts.map_columns
  if map_layout and map_columns then
    local map_lines, cache_id = map_view.lines(
      opts.buf,
      map_layout.content_height,
      map_columns.map_width,
      opts.refresh,
      map_layout.mode
    )
    local left_fill = string.rep(' ', map_columns.map_start_col)
    local track_right_fill = string.rep(
      ' ',
      opts.track_width - map_columns.map_start_col - map_columns.map_width
    )
    local window_right_fill = string.rep(' ', math.max(opts.width - opts.track_width, 0))
    if opts.winbar_offset > 0 then lines[1] = string.rep(' ', opts.width) end

    for index = 1, opts.height do
      local line = map_lines[map_layout.top_row + index]
        or string.rep(' ', map_columns.map_width)
      lines[index + opts.winbar_offset] =
        left_fill .. line .. track_right_fill .. window_right_fill
    end
    return lines, table.concat({
      'map',
      opts.buf,
      cache_id,
      opts.width,
      opts.winbar_offset,
      map_layout.top_row,
      map_columns.mode,
      map_columns.map_width,
    }, ':')
  end

  local fill = string.rep(' ', opts.width)
  for index = 1, opts.height + opts.winbar_offset do lines[index] = fill end
  return lines, table.concat({
    'track',
    opts.height,
    opts.width,
    opts.winbar_offset,
  }, ':')
end

return M
