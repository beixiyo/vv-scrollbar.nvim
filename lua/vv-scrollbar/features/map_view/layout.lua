-- Map View 纵向坐标：完整地图、可见切片与 source viewport 的相互换算

local projection = require('vv-scrollbar.core.projection')

local M = {}

local DOT_ROWS = 4

---@param viewport table
---@param opts VVScrollbarMapViewConfig
---@param top_override? integer
---@return VVScrollbarMapLayout
function M.resolve(viewport, opts, top_override)
  local height = viewport.height
  local line_count = viewport.line_count
  if opts.mode == 'fit' then
    return {
      mode = 'fit',
      line_count = line_count,
      window_height = height,
      content_height = height,
      top_row = 0,
      thumb_row = viewport.thumb_row,
      thumb_height = viewport.thumb_height,
      rows_per_cell = line_count / math.max(height, 1),
    }
  end

  local rows_per_cell = DOT_ROWS * opts.y_multiplier
  local content_height = math.max(math.ceil(line_count / rows_per_cell), 1)
  local thumb_start = math.floor((viewport.topline - 1) / rows_per_cell)
  local thumb_end = math.floor((viewport.botline - 1) / rows_per_cell)
  local max_thumb_height = math.min(height, content_height)
  local thumb_height = projection.clamp(
    thumb_end - thumb_start + 1,
    math.min(opts.min_thumb or 1, max_thumb_height),
    max_thumb_height
  )
  thumb_start = projection.clamp(
    thumb_start,
    0,
    math.max(content_height - thumb_height, 0)
  )

  local max_top = math.max(content_height - height, 0)
  local centered_top = thumb_start - math.floor((height - thumb_height) / 2)
  local top_row = projection.clamp(top_override or centered_top, 0, max_top)

  return {
    mode = 'viewport',
    line_count = line_count,
    window_height = height,
    content_height = content_height,
    top_row = top_row,
    thumb_row = thumb_start - top_row,
    thumb_height = thumb_height,
    rows_per_cell = rows_per_cell,
  }
end

---@param layout VVScrollbarMapLayout
---@param line integer
---@return integer
function M.line_to_row(layout, line)
  if layout.mode == 'fit' then
    return projection.line_to_row(line, layout.line_count, layout.window_height)
  end
  return math.floor((line - 1) / layout.rows_per_cell) - layout.top_row
end

---@param layout VVScrollbarMapLayout
---@param row integer
---@return integer
function M.row_to_line(layout, row)
  if layout.mode == 'fit' then
    return projection.row_to_line(row, layout.line_count, layout.window_height)
  end

  local absolute_row =
    layout.top_row + projection.clamp(row, 0, layout.window_height - 1)
  return projection.clamp(
    absolute_row * layout.rows_per_cell + 1,
    1,
    layout.line_count
  )
end

return M
