local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local win = api.nvim_get_current_win()
local lines = {
  string.rep('line-1 ', 110),
  string.rep('line-2 ', 110),
}
api.nvim_buf_set_lines(0, 0, -1, false, lines)
api.nvim_set_option_value('wrap', true, { win = win, scope = 'local' })

local scrollbar = require('vv-scrollbar')
scrollbar.setup({
  throttle_ms = 0,
  markers = {
    diagnostics = false,
    git = false,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})

local view = require('vv-scrollbar.core.view')
local state = require('vv-scrollbar.core.state')

local function move(command)
  api.nvim_win_call(win, function() vim.cmd('normal! ' .. command) end)
  view.refresh()
end

move('ggzt')
vim.w[win].vv_scrollbar_always_show = true
view.refresh()
local bar = state.bars[win]
assert(bar and api.nvim_win_is_valid(bar.win), 'always_show did not create the marker track at the top')

move('Gzt')
bar = state.bars[win]
assert(bar and api.nvim_win_is_valid(bar.win), 'always_show track disappeared after scrolling down')

move('ggzt')
bar = state.bars[win]
assert(bar and api.nvim_win_is_valid(bar.win), 'always_show track disappeared after returning to the top')

for _, ft in ipairs({ 'vv-task-panel', 'vv-task-panel-tasks' }) do
  vim.bo.filetype = ft
  view.refresh()
  assert(state.bars[win] == nil, ft .. ' should not create a scrollbar')

  vim.bo.filetype = 'lua'
  view.refresh()
  bar = state.bars[win]
  assert(bar and api.nvim_win_is_valid(bar.win), 'scrollbar did not return after leaving ' .. ft)
end

scrollbar.disable()
print('PASS: stable visibility and private panel filetype exclusions')
