local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local config = require('vv-scrollbar.config')
local projection = require('vv-scrollbar.core.projection')
local layout = require('vv-scrollbar.features.map_view.layout')
local markers = require('vv-scrollbar.features.markers')
local state = require('vv-scrollbar.core.state')

local buf = api.nvim_get_current_buf()
local lines = {}
for index = 1, 100 do lines[index] = 'line ' .. index end
api.nvim_buf_set_lines(buf, 0, -1, false, lines)

config.apply({
  width = 1,
  markers = {
    diagnostics = false,
    git = true,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})
state.git_marks[buf] = {
  staged = { [1] = 'A' },
  unstaged = { [2] = 'C' },
}

local viewport = { buf = buf, line_count = 100, height = 20 }
local function classic_line_to_row(line)
  return projection.line_to_row(line, viewport.line_count, viewport.height)
end
local map_marker = markers.collect(0, viewport, {
  track_width = 8,
  line_to_row = classic_line_to_row,
})[0]
assert(#map_marker.chunks == 2, 'map width did not preserve staged and unstaged Git tracks')
assert(#map_marker.hits == 2, 'dual Git tracks did not expose independent hit targets')
assert(
  map_marker.hits[1].source_line == 1
    and map_marker.hits[1].start_col == 0
    and map_marker.hits[1].end_col == 1,
  'staged Git track lost its source line or relative hit span'
)
assert(
  map_marker.hits[2].source_line == 2
    and map_marker.hits[2].start_col == 1
    and map_marker.hits[2].end_col == 2,
  'unstaged Git track lost its source line or relative hit span'
)

local narrow_marker = markers.collect(0, viewport, {
  track_width = 1,
  line_to_row = classic_line_to_row,
})[0]
assert(#narrow_marker.chunks == 1, 'one-cell track did not merge Git channels')
assert(
  #narrow_marker.hits == 1 and narrow_marker.hits[1].source_line == 2,
  'merged Git track did not retain the visible channel source line'
)

local map_viewport = { buf = buf, line_count = 400, height = 20 }
local middle_layout = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 201,
  botline = 220,
  thumb_row = 10,
  thumb_height = 1,
}, {
  mode = 'viewport',
  y_multiplier = 1,
  min_thumb = 2,
})
state.git_marks[buf] = {
  staged = { [1] = 'A', [201] = 'C', [204] = 'C' },
  unstaged = {},
}
local projected_markers = markers.collect(0, map_viewport, {
  track_width = 2,
  line_to_row = function(line) return layout.line_to_row(middle_layout, line) end,
})
assert(
  projected_markers[7]
    and projected_markers[7].hits[1].source_line == 201,
  'map marker projection or deterministic collision target is incorrect'
)
assert(
  projected_markers[0] == nil,
  'marker outside the visible map slice was projected back into the window'
)

local resized_layout = layout.resolve({
  line_count = 400,
  height = 10,
  topline = 201,
  botline = 220,
  thumb_row = 5,
  thumb_height = 1,
}, {
  mode = 'viewport',
  y_multiplier = 1,
  min_thumb = 2,
})
map_viewport.height = 10
local resized_markers = markers.collect(0, map_viewport, {
  track_width = 2,
  line_to_row = function(line) return layout.line_to_row(resized_layout, line) end,
})
assert(
  resized_markers[2]
    and resized_markers[2].hits[1].source_line == 201,
  'map marker did not follow the resized map-slice projection'
)

local diagnostic_ns = api.nvim_create_namespace('vv-scrollbar.marker-test')
vim.diagnostic.set(diagnostic_ns, buf, {
  { lnum = 4, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'first' },
  { lnum = 5, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'second' },
})
config.apply({
  markers = {
    diagnostics = true,
    git = false,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})
viewport.line_count = 100
viewport.height = 20
local diagnostic_marker = markers.collect(0, viewport, {
  line_to_row = classic_line_to_row,
})[1]
assert(
  diagnostic_marker
    and diagnostic_marker.hl == 'VVScrollbarDiagnosticError'
    and diagnostic_marker.source_line == 5,
  'diagnostic marker ignored its configured highlight or stable collision target'
)

local ok, err = pcall(markers.collect, 0, viewport)
assert(
  not ok and tostring(err):find('marker projection is required', 1, true),
  'marker collection silently accepted a missing coordinate projection'
)

vim.diagnostic.reset(diagnostic_ns, buf)
state.git_marks[buf] = nil
print('PASS: marker lanes, stable exact hits, projection invariant, diagnostic colors')
