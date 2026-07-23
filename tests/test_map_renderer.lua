local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local renderer = require('vv-scrollbar.features.map_view.renderer')

local function render(lines, width, opts)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local result = renderer.render(buf, 1, width, vim.tbl_deep_extend('force', {
    mode = 'fit',
    x_multiplier = 1,
    y_multiplier = 1,
    max_lines_per_dot = 8,
    tab_width = 4,
    include_whitespace = false,
  }, opts or {}))
  api.nvim_buf_delete(buf, { force = true })
  return result
end

local vertical = render({ 'x', 'x', 'x', 'x' }, 1)
assert(vim.fn.str2list(vertical[1])[1] == 0x2847, 'vertical dots did not use Braille rows')

local fullwidth = render({ '界' }, 1)
assert(vim.fn.str2list(fullwidth[1])[1] == 0x2809, 'full-width codepoint lost a screen cell')

local tabbed = render({ '\tx' }, 3)
assert(
  vim.fn.strcharpart(tabbed[1], 2, 1) ~= ' ',
  'tab width did not move following code to its display column'
)

local whitespace = render({ '  ' }, 1, { include_whitespace = true })
assert(whitespace[1] ~= ' ', 'include_whitespace did not add map points')

local tail_lines = {}
for index = 1, 398 do tail_lines[index] = index == 398 and 'return M' or '' end
local tail_buf = api.nvim_create_buf(false, true)
api.nvim_buf_set_lines(tail_buf, 0, -1, false, tail_lines)
local fitted_tail = renderer.render(tail_buf, 55, 16, {
  x_multiplier = 4,
  max_lines_per_dot = 8,
  tab_width = 'buffer',
  include_whitespace = false,
})
api.nvim_buf_delete(tail_buf, { force = true })
assert(
  fitted_tail[55]:find('[^ ]'),
  'fit projection left the final source lines above the map bottom'
)

local compact_buf = api.nvim_create_buf(false, true)
api.nvim_buf_set_lines(compact_buf, 0, -1, false, { 'x', 'x' })
local compact = renderer.render(compact_buf, 2, 1, {
  mode = 'viewport',
  x_multiplier = 1,
  y_multiplier = 1,
  max_lines_per_dot = 8,
  tab_width = 4,
  include_whitespace = false,
})
api.nvim_buf_delete(compact_buf, { force = true })
assert(
  vim.fn.str2list(compact[1])[1] == 0x2803 and compact[2] == ' ',
  'viewport projection stretched a short file instead of keeping fixed scale'
)

print('PASS: Braille renderer, UTF-8, tabs, whitespace, fit and viewport projection')
