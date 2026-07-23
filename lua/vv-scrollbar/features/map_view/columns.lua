-- Map View 横向列布局：代码地图与 marker overlay / lane 的空间分配

local M = {}

---@param track_width integer
---@param opts VVScrollbarMapViewConfig
---@return VVScrollbarMapColumns
function M.resolve(track_width, opts)
  local mode = opts.marker_layout
  if mode == 'overlay' or track_width <= 1 then
    return {
      mode = 'overlay',
      track_width = track_width,
      map_start_col = 0,
      map_width = track_width,
      marker_start_col = 0,
      marker_width = track_width,
    }
  end

  local lane_width = math.min(opts.marker_lane_width, track_width - 1)
  local map_width = track_width - lane_width
  local left = mode == 'left'
  return {
    mode = mode,
    track_width = track_width,
    map_start_col = left and lane_width or 0,
    map_width = map_width,
    marker_start_col = left and 0 or map_width,
    marker_width = lane_width,
  }
end

---@param columns VVScrollbarMapColumns
---@param marker_width integer
---@param overlay_side 'left'|'right'
---@return integer
function M.marker_col(columns, marker_width, overlay_side)
  if columns.mode == 'overlay' then
    if overlay_side == 'left' then return columns.map_start_col end
    return columns.map_start_col + math.max(columns.map_width - marker_width, 0)
  end

  return columns.marker_start_col + math.max(columns.marker_width - marker_width, 0)
end

return M
