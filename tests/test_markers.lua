local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local config = require('vv-scrollbar.config')
local markers = require('vv-scrollbar.features.markers')
local state = require('vv-scrollbar.core.state')

local lines = {}
for index = 1, 100 do lines[index] = 'line ' .. index end
api.nvim_buf_set_lines(0, 0, -1, false, lines)

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
state.git_marks[0] = {
  staged = { [1] = 'A' },
  unstaged = { [2] = 'C' },
}

local viewport = { buf = 0, line_count = 100, height = 20 }
local map_marker = markers.collect(0, viewport, { track_width = 8 })[0]
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

local narrow_marker = markers.collect(0, viewport, { track_width = 1 })[0]
assert(#narrow_marker.chunks == 1, 'one-cell track did not merge Git channels')
assert(
  #narrow_marker.hits == 1 and narrow_marker.hits[1].source_line == 2,
  'merged Git track did not retain the visible channel source line'
)

state.git_marks[0] = nil
print('PASS: actual track width and per-lane Git marker hit targets')
