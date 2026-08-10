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
assert(bar and api.nvim_win_is_valid(bar.win), '始终显示（always_show）未在顶部创建标记轨道')

move('Gzt')
bar = state.bars[win]
assert(bar and api.nvim_win_is_valid(bar.win), '向下滚动后，始终显示（always_show）轨道消失')

move('ggzt')
bar = state.bars[win]
assert(bar and api.nvim_win_is_valid(bar.win), '回到顶部后始终显示（always_show）轨道消失')

for _, ft in ipairs({ 'vv-task-panel', 'vv-task-panel-tasks' }) do
  vim.bo.filetype = ft
  view.refresh()
  assert(state.bars[win] == nil, ft .. ' 不应创建滚动条')

  vim.bo.filetype = 'lua'
  view.refresh()
  bar = state.bars[win]
  assert(bar and api.nvim_win_is_valid(bar.win), '离开 ' .. ft .. ' 后滚动条未返回')
end

vim.w[win].vv_scrollbar_always_show = nil
api.nvim_set_option_value('wrap', false, { win = win, scope = 'local' })
api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two' })
view.refresh()
bar = state.bars[win]
assert(bar and bar.map_layout, '短缓冲区未保留地图视图')

assert(not scrollbar.toggle_view(), '短缓冲区未切换到经典视图')
bar = state.bars[win]
assert(bar and not bar.map_layout, '短缓冲区经典视图移除了自己的切换目标')

assert(scrollbar.toggle_view(), '短缓冲区未切回地图视图')
bar = state.bars[win]
assert(bar and bar.map_layout, '短缓冲区未恢复地图视图')

scrollbar.disable()
print('PASS: 稳定显示与私有面板文件类型排除')
