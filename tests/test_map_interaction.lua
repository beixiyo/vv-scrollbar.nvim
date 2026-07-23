local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local config = require('vv-scrollbar.config')
local drag = require('vv-scrollbar.input.viewport_drag')

local defaults = config.current().map_view.interaction
assert(
  defaults.edge_scroll
    and defaults.edge_margin == 2
    and defaults.edge_speed == 2
    and defaults.edge_interval == 50
    and defaults.snap_to_edges
    and defaults.right_click == 'toggle_view',
  'viewport interaction defaults are incomplete'
)

local layout = {
  mode = 'viewport',
  line_count = 400,
  window_height = 20,
  content_height = 100,
  top_row = 43,
  thumb_row = 7,
  thumb_height = 5,
  rows_per_cell = 4,
}
local opts = {
  edge_scroll = true,
  edge_margin = 2,
  edge_speed = 2,
  edge_interval = 50,
  snap_to_edges = true,
}

local center = drag.update(layout, 10, 2, opts)
assert(center.top_row == 43, 'center drag unexpectedly moved the map viewport')
assert(center.source_line == 205, 'center drag lost the thumb grab offset')
assert(not center.repeat_edge, 'center drag incorrectly started edge scrolling')

local top_edge = drag.update(layout, 0, 2, opts)
assert(top_edge.top_row == 41, 'top edge did not pan the map upward')
assert(top_edge.source_line == 165, 'top edge pan did not update the source target')
assert(top_edge.repeat_edge, 'top edge did not request continuous scrolling')

local bottom_edge = drag.update(layout, 19, 2, opts)
assert(bottom_edge.top_row == 45, 'bottom edge did not pan the map downward')
assert(bottom_edge.source_line == 241, 'bottom edge pan did not update the source target')
assert(bottom_edge.repeat_edge, 'bottom edge did not request continuous scrolling')

local above = drag.update(layout, -1, 2, opts)
assert(
  above.snapped == 'top' and above.top_row == 0 and above.source_line == 1,
  'dragging above the map did not snap to the file start'
)

local below = drag.update(layout, 20, 2, opts)
assert(
  below.snapped == 'bottom' and below.top_row == 80 and below.source_line == 400,
  'dragging below the map did not snap to the file end'
)

local at_top = vim.tbl_extend('force', layout, { top_row = 0 })
local top_limit = drag.update(at_top, 0, 2, opts)
assert(top_limit.top_row == 0 and not top_limit.repeat_edge, 'top edge repeated past its limit')

local no_edge = vim.tbl_extend('force', opts, { edge_scroll = false })
local stationary = drag.update(layout, 0, 2, no_edge)
assert(stationary.top_row == 43, 'disabled edge scrolling still moved the map')

local no_snap = vim.tbl_extend('force', opts, { snap_to_edges = false })
local clamped = drag.update(layout, -1, 2, no_snap)
assert(not clamped.snapped and clamped.top_row == 41, 'disabled edge snapping ignored edge pan')

local sanitized = config.apply({
  map_view = {
    interaction = {
      edge_scroll = 'invalid',
      edge_margin = -2,
      edge_speed = 0,
      edge_interval = 0,
      snap_to_edges = 'invalid',
      right_click = 'invalid',
    },
  },
}).map_view.interaction
assert(
  sanitized.edge_scroll
    and sanitized.edge_margin == 0
    and sanitized.edge_speed == 1
    and sanitized.edge_interval == 1
    and sanitized.snap_to_edges
    and sanitized.right_click == 'toggle_view',
  'invalid viewport interaction options were not normalized'
)

local custom_right_click = function() end
local right_click_options = config.apply({
  map_view = {
    interaction = {
      right_click = custom_right_click,
    },
  },
}).map_view.interaction
assert(
  right_click_options.right_click == custom_right_click,
  'custom right-click callback was not preserved'
)

right_click_options = config.apply({
  map_view = {
    interaction = {
      right_click = false,
    },
  },
}).map_view.interaction
assert(right_click_options.right_click == false, 'disabled right-click action was not preserved')

print('PASS: grab offset, edge pan, continuous scroll, snapping and configurable fallbacks')
