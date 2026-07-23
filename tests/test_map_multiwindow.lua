local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')

local function assert_bar_attached(parent, bar, label)
  local parent_position = vim.fn.win_screenpos(parent)
  local bar_position = vim.fn.win_screenpos(bar.win)
  local expected_col = parent_position[2] + api.nvim_win_get_width(parent) + 1

  assert(
    bar_position[1] == parent_position[1]
      and bar_position[2] == expected_col
      and api.nvim_win_get_height(bar.win) == api.nvim_win_get_height(parent),
    ('%s bar detached: parent=(%d,%d,%dx%d), bar=(%d,%d,%d)'):format(
      label,
      parent_position[1],
      parent_position[2],
      api.nvim_win_get_width(parent),
      api.nvim_win_get_height(parent),
      bar_position[1],
      bar_position[2],
      api.nvim_win_get_height(bar.win)
    )
  )
end

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
vim.o.splitright = true
vim.cmd('vsplit')
local second = api.nvim_get_current_win()
vim.wo[second].wrap = false

api.nvim_win_call(first, function() vim.cmd('normal! ggzt') end)
api.nvim_win_call(second, function() vim.cmd('normal! 401Gzt') end)
view.refresh()

local first_bar = state.bars[first]
local second_bar = state.bars[second]
assert(first_bar and second_bar, 'same-buffer source windows did not receive independent bars')
assert(first_bar ~= second_bar and first_bar.buf ~= second_bar.buf, 'source windows shared bar state')
assert_bar_attached(first, first_bar, 'first')
assert_bar_attached(second, second_bar, 'second')
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

api.nvim_set_current_win(first)
vim.o.splitbelow = true
vim.cmd('split')
local third = api.nvim_get_current_win()
vim.wo[third].wrap = false
view.refresh()

assert_bar_attached(first, state.bars[first], 'top')
assert_bar_attached(third, state.bars[third], 'bottom')

api.nvim_win_close(third, true)
view.refresh()
assert(state.bars[third] == nil, 'closing a horizontal sibling leaked its map state')
assert_bar_attached(first, state.bars[first], 'remaining')

scrollbar.disable()
print('PASS: vertical and horizontal splits keep independent attached map viewports')
