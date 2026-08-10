local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local api = vim.api
local config = require('vv-scrollbar.config')
local map_view = require('vv-scrollbar.features.map_view')

local win = api.nvim_get_current_win()
local buf = api.nvim_get_current_buf()
local lines = {}
for index = 1, 100 do lines[index] = 'line ' .. index end
api.nvim_buf_set_lines(buf, 0, -1, false, lines)

vim.wo[win].wrap = false
vim.wo[win].diff = false
vim.wo[win].foldenable = false
config.apply()
assert(map_view.resolve_mode(win, buf) == 'viewport', '普通窗口未使用 viewport 模式')

vim.wo[win].wrap = true
assert(map_view.resolve_mode(win, buf) == 'viewport', '默认 wrap 策略将 viewport 模式改写')

config.apply({
  map_view = {
    degradation = { wrap = 'fit' },
  },
})
assert(map_view.resolve_mode(win, buf) == 'fit', '显式 wrap fit 降级策略未生效')

config.apply({
  map_view = {
    degradation = { wrap = 'scrollbar' },
  },
})
assert(map_view.resolve_mode(win, buf) == nil, 'wrap scrollbar 降级策略未关闭地图显示')

config.apply()
vim.wo[win].wrap = false
vim.wo[win].diff = true
assert(map_view.resolve_mode(win, buf) == 'fit', 'diff 窗口未降级到 fit')

vim.wo[win].diff = false
vim.wo[win].foldmethod = 'manual'
vim.wo[win].foldenable = true
vim.wo[win].wrap = true
api.nvim_win_call(win, function()
  vim.cmd('2,10fold')
  vim.cmd('normal! ggzt')
end)
assert(
  map_view.resolve_mode(win, buf) == 'fit',
  '默认 viewport wrap 策略遮蔽了可见折叠 fallback'
)

api.nvim_win_call(win, function() vim.cmd('normal! 50Gzt') end)
assert(
  map_view.resolve_mode(win, buf) == 'fit',
  '滚动越过已闭合折叠后，地图从 fit 切回 viewport'
)

api.nvim_win_call(win, function() vim.cmd('normal! zR') end)
assert(
  map_view.resolve_mode(win, buf) == 'viewport',
  '全部展开折叠后未恢复配置的 viewport 模式'
)

api.nvim_win_call(win, function() vim.cmd('normal! zM') end)
config.apply({
  map_view = {
    degradation = { folds = 'viewport' },
  },
})
assert(
  map_view.resolve_mode(win, buf) == 'viewport',
  '显式折叠 viewport 策略未生效'
)

print('PASS: 普通窗口、wrap、diff 与稳定闭合折叠地图降级策略')
