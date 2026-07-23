-- Map View 纵向坐标：完整地图、可见切片与 source viewport 的相互换算

local M = {}

local DOT_ROWS = 4

---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

---@param line integer
---@param line_count integer
---@param height integer
---@return integer
local function fit_row(line, line_count, height)
  if line_count <= 1 or height <= 1 then return 0 end
  return clamp(
    math.floor(((line - 1) / math.max(line_count - 1, 1)) * (height - 1) + 0.5),
    0,
    height - 1
  )
end

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
  local thumb_height = clamp(
    thumb_end - thumb_start + 1,
    math.min(opts.min_thumb or 1, max_thumb_height),
    max_thumb_height
  )
  thumb_start = clamp(thumb_start, 0, math.max(content_height - thumb_height, 0))

  local max_top = math.max(content_height - height, 0)
  local centered_top = thumb_start - math.floor((height - thumb_height) / 2)
  local top_row = clamp(top_override or centered_top, 0, max_top)

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
    return fit_row(line, layout.line_count, layout.window_height)
  end
  return math.floor((line - 1) / layout.rows_per_cell) - layout.top_row
end

---@param layout VVScrollbarMapLayout
---@param row integer
---@return integer
function M.row_to_line(layout, row)
  if layout.mode == 'fit' then
    if layout.window_height <= 1 then return 1 end
    local ratio = clamp(row, 0, layout.window_height - 1) / (layout.window_height - 1)
    return math.floor(ratio * math.max(layout.line_count - 1, 0) + 1.5)
  end

  local absolute_row = layout.top_row + clamp(row, 0, layout.window_height - 1)
  return clamp(absolute_row * layout.rows_per_cell + 1, 1, layout.line_count)
end

return M
