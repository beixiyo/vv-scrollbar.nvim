-- Viewport 地图拖拽坐标：全文比例定位、局部边缘平移与首尾吸附

local projection = require('vv-scrollbar.core.projection')

local M = {}

---@param row integer
---@param height integer
---@param opts VVScrollbarMapViewInteractionConfig
---@return integer
local function edge_delta(row, height, opts)
  if not opts.edge_scroll or opts.edge_margin <= 0 then return 0 end

  local margin = math.min(opts.edge_margin, math.max(math.floor(height / 2), 1))
  if row < margin then
    local distance = margin - row
    return -math.max(math.ceil(opts.edge_speed * distance / margin), 1)
  end

  local bottom_start = height - margin
  if row >= bottom_start then
    local distance = row - bottom_start + 1
    return math.max(math.ceil(opts.edge_speed * distance / margin), 1)
  end
  return 0
end

---@param layout VVScrollbar.MapLayout
---@param mouse_row integer
---@param offset integer
---@param opts VVScrollbarMapViewInteractionConfig
---@return VVScrollbar.ViewportDragResult
function M.update(layout, mouse_row, offset, opts)
  local max_top = math.max(layout.content_height - layout.window_height, 0)
  if mouse_row < 0 and opts.snap_to_edges then
    return { top_row = 0, source_line = 1, repeat_edge = false, snapped = 'top' }
  end
  if mouse_row >= layout.window_height and opts.snap_to_edges then
    return {
      top_row = max_top,
      source_line = layout.line_count,
      repeat_edge = false,
      snapped = 'bottom',
    }
  end

  local row = projection.clamp(mouse_row, 0, layout.window_height - 1)
  local max_thumb_row = math.max(layout.window_height - layout.thumb_height, 0)
  local thumb_row = projection.clamp(row - offset, 0, max_thumb_row)

  if opts.drag_mode == 'proportional' and max_top > 0 and max_thumb_row > 0 then
    local top_row = math.floor(thumb_row / max_thumb_row * max_top + 0.5)
    -- 保留抓取偏移；thumb 抵达轨道末端时直接展示 EOF，不等鼠标移出地图或松手
    local source_line = thumb_row == max_thumb_row and layout.line_count
      or (top_row + thumb_row) * layout.rows_per_cell + 1
    return {
      top_row = top_row,
      source_line = projection.clamp(source_line, 1, layout.line_count),
      repeat_edge = false,
    }
  end

  local delta = edge_delta(row, layout.window_height, opts)
  local top_row = projection.clamp(layout.top_row + delta, 0, max_top)
  local max_absolute_thumb = math.max(layout.content_height - layout.thumb_height, 0)
  local absolute_thumb = projection.clamp(top_row + thumb_row, 0, max_absolute_thumb)
  local source_line = projection.clamp(
    absolute_thumb * layout.rows_per_cell + 1,
    1,
    layout.line_count
  )
  local repeat_edge = delta < 0 and top_row > 0
    or delta > 0 and top_row < max_top

  return {
    top_row = top_row,
    source_line = source_line,
    repeat_edge = repeat_edge,
  }
end

return M
