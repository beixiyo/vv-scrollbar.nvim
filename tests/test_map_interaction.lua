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
    and defaults.snap_to_edges,
  'viewport interaction defaults are incomplete'
)
assert(
  config.current().interaction.right_click == 'toggle_view'
    and config.current().interaction.cursor_on_drag == 'follow',
  'shared interaction defaults are incomplete'
)
assert(
  config.current().cursor.style == 'line'
    and config.current().cursor.symbol == '▕'
    and config.current().map_view.marker_layout == 'right',
  'shared visual defaults are incomplete'
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
    },
  },
  interaction = {
    right_click = 'invalid',
    cursor_on_drag = 'invalid',
  },
})
local sanitized_interaction = sanitized.map_view.interaction
assert(
  sanitized_interaction.edge_scroll
    and sanitized_interaction.edge_margin == 0
    and sanitized_interaction.edge_speed == 1
    and sanitized_interaction.edge_interval == 1
    and sanitized_interaction.snap_to_edges
    and sanitized.interaction.right_click == 'toggle_view'
    and sanitized.interaction.cursor_on_drag == 'follow',
  'invalid viewport interaction options were not normalized'
)

local custom_right_click = function() end
local right_click_options = config.apply({
  interaction = {
    right_click = custom_right_click,
  },
}).interaction
assert(
  right_click_options.right_click == custom_right_click,
  'custom right-click callback was not preserved'
)

right_click_options = config.apply({
  interaction = {
    right_click = false,
  },
}).interaction
assert(right_click_options.right_click == false, 'disabled right-click action was not preserved')

local kept_cursor = config.apply({
  interaction = {
    cursor_on_drag = 'keep',
  },
}).interaction
assert(kept_cursor.cursor_on_drag == 'keep', 'keep cursor drag mode was not preserved')

local invalid_shared = config.apply({
  cursor = false,
  interaction = false,
  show_on_short_buffers = 'invalid',
})
assert(
  invalid_shared.cursor.style == 'line'
    and invalid_shared.interaction.right_click == 'toggle_view'
    and invalid_shared.interaction.cursor_on_drag == 'follow'
    and invalid_shared.show_on_short_buffers,
  'invalid shared options were not normalized'
)

print('PASS: grab offset, edge pan, continuous scroll, snapping and configurable fallbacks')
