local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')

local lines = {}
for index = 1, 600 do lines[index] = 'local value_' .. index .. ' = ' .. index end
api.nvim_buf_set_lines(0, 0, -1, false, lines)

local first = api.nvim_get_current_win()
vim.wo[first].wrap = false
local scrollbar = require('vv-scrollbar')
scrollbar.setup({
  throttle_ms = 0,
  current_only = false,
  markers = {
    diagnostics = false,
    git = false,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})
view.refresh()

api.nvim_set_current_win(first)
vim.cmd('leftabove vsplit')
local second = api.nvim_get_current_win()
vim.wo[second].wrap = false

api.nvim_win_call(first, function() vim.cmd('normal! ggzt') end)
api.nvim_win_call(second, function() vim.cmd('normal! 401Gzt') end)
view.refresh()

local first_bar = state.bars[first]
local second_bar = state.bars[second]
assert(first_bar and second_bar, 'same-buffer source windows did not receive independent bars')
assert(first_bar ~= second_bar and first_bar.buf ~= second_bar.buf, 'source windows shared bar state')
assert(
  first_bar.map_layout.content_height == second_bar.map_layout.content_height,
  'same-buffer windows disagreed on cached map height'
)
assert(
  first_bar.map_layout.top_row == 0
    and second_bar.map_layout.top_row > first_bar.map_layout.top_row,
  'same-buffer windows did not preserve independent map viewports'
)

local second_top = second_bar.map_layout.top_row
api.nvim_win_call(first, function() vim.cmd('normal! 201Gzt') end)
view.refresh()
assert(state.bars[first].map_layout.top_row > 0, 'first window map did not move independently')
assert(
  state.bars[second].map_layout.top_row == second_top,
  'scrolling one source window moved the other map viewport'
)

api.nvim_win_close(second, true)
view.refresh()
assert(state.bars[second] == nil, 'closing a source window leaked its map state')
assert(state.bars[first], 'closing a sibling removed the remaining map')

scrollbar.disable()
print('PASS: same-buffer windows keep independent viewport, thumb, bar and cleanup state')
