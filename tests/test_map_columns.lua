local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local columns = require('vv-scrollbar.features.map_view.columns')

local overlay = columns.resolve(12, {
  marker_layout = 'overlay',
  marker_lane_width = 2,
})
assert(overlay.map_width == 12 and overlay.marker_width == 12, 'overlay reserved a lane')
assert(columns.marker_col(overlay, 2, 'right') == 10, 'right overlay marker drifted')
assert(columns.marker_col(overlay, 1, 'left') == 0, 'left overlay marker drifted')

local left = columns.resolve(12, {
  marker_layout = 'left',
  marker_lane_width = 2,
})
assert(
  left.map_start_col == 2
    and left.map_width == 10
    and left.marker_start_col == 0
    and left.marker_width == 2,
  'left marker lane did not reserve the expected columns'
)
assert(columns.marker_col(left, 1, 'right') == 1, 'left lane marker was not lane-aligned')

local right = columns.resolve(12, {
  marker_layout = 'right',
  marker_lane_width = 3,
})
assert(
  right.map_start_col == 0
    and right.map_width == 9
    and right.marker_start_col == 9
    and right.marker_width == 3,
  'right marker lane did not reserve the expected columns'
)
assert(columns.marker_col(right, 2, 'left') == 10, 'right lane marker was not lane-aligned')

local narrow = columns.resolve(1, {
  marker_layout = 'right',
  marker_lane_width = 2,
})
assert(
  narrow.mode == 'overlay' and narrow.map_width == 1,
  'one-cell map did not fall back to overlay'
)

print('PASS: marker overlay, left lane, right lane and narrow fallback')
