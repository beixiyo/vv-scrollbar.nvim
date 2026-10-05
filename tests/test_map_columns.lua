local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['地图标记列与窄宽度回退'] = function()
  child.lua_func(function()
    local columns = require('vv-scrollbar.features.map_view.columns')

    local overlay = columns.resolve(12, {
      marker_layout = 'overlay',
      marker_lane_width = 2,
    })
    assert(overlay.map_width == 12 and overlay.marker_width == 12, '覆盖模式未保留专用列')
    assert(columns.marker_col(overlay, 2, 'right') == 10, '右侧覆盖标记偏移')
    assert(columns.marker_col(overlay, 1, 'left') == 0, '左侧覆盖标记偏移')

    local left = columns.resolve(12, {
      marker_layout = 'left',
      marker_lane_width = 2,
    })
    assert(
      left.map_start_col == 2
        and left.map_width == 10
        and left.marker_start_col == 0
        and left.marker_width == 2,
      '左侧标记槽未预留预期列宽'
    )
    assert(columns.marker_col(left, 1, 'right') == 1, '左侧标记槽未对齐')

    local right = columns.resolve(12, {
      marker_layout = 'right',
      marker_lane_width = 3,
    })
    assert(
      right.map_start_col == 0
        and right.map_width == 9
        and right.marker_start_col == 9
        and right.marker_width == 3,
      '右侧标记槽未预留预期列宽'
    )
    assert(columns.marker_col(right, 2, 'left') == 10, '右侧标记槽未对齐')

    local narrow = columns.resolve(1, {
      marker_layout = 'right',
      marker_lane_width = 2,
    })
    assert(
      narrow.mode == 'overlay' and narrow.map_width == 1,
      '一格地图未回退到 overlay 模式'
    )
  end)
end

return T
