local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local layout = require('vv-scrollbar.features.map_view.layout')
local projection = require('vv-scrollbar.core.projection')

local opts = {
  mode = 'viewport',
  y_multiplier = 1,
  min_thumb = 2,
}

local top = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 1,
  botline = 20,
  thumb_row = 0,
  thumb_height = 1,
}, opts)
assert(top.content_height == 100, 'viewport map height did not use fixed vertical scale')
assert(top.top_row == 0 and top.thumb_row == 0, 'top viewport did not anchor the map start')

local middle = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 201,
  botline = 220,
  thumb_row = 10,
  thumb_height = 1,
}, opts)
assert(middle.top_row == 43, 'middle source viewport was not centered in the map viewport')
assert(middle.thumb_row == 7 and middle.thumb_height == 5, 'middle thumb coordinates drifted')
assert(layout.line_to_row(middle, 201) == 7, 'source line did not map into the visible slice')
assert(layout.row_to_line(middle, 7) == 201, 'visible map row did not map back to source')

local bottom = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 381,
  botline = 400,
  thumb_row = 19,
  thumb_height = 1,
}, opts)
assert(bottom.top_row == 80, 'bottom viewport did not anchor the map end')
assert(bottom.thumb_row + bottom.thumb_height == 20, 'bottom thumb escaped the visible map')

local short = layout.resolve({
  line_count = 10,
  height = 20,
  topline = 1,
  botline = 10,
  thumb_row = 0,
  thumb_height = 20,
}, opts)
assert(short.content_height == 3, 'short file map was stretched instead of staying compact')
assert(short.top_row == 0 and short.thumb_height == 3, 'short file viewport was unstable')

local resized = layout.resolve({
  line_count = 400,
  height = 10,
  topline = 201,
  botline = 220,
  thumb_row = 5,
  thumb_height = 1,
}, opts)
assert(resized.content_height == middle.content_height, 'window resize changed fixed map scale')
assert(resized.top_row == 48 and resized.thumb_row == 2, 'resize did not recenter the map viewport')

local fit = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 201,
  botline = 220,
  thumb_row = 10,
  thumb_height = 2,
}, { mode = 'fit' })
assert(fit.content_height == 20 and fit.top_row == 0, 'fit compatibility mode became scrollable')
assert(fit.thumb_row == 10 and fit.thumb_height == 2, 'fit mode changed classic thumb geometry')

assert(projection.row_to_line(0, 400, 20) == 1, 'classic projection lost the first line')
assert(projection.row_to_line(19, 400, 20) == 400, 'classic projection lost the last line')
assert(
  projection.line_to_row(projection.row_to_line(10, 400, 20), 400, 20) == 10,
  'classic row-to-line projection did not round-trip to the clicked row'
)

print('PASS: viewport scale, source sync, short files, boundaries, resize, fit fallback')
