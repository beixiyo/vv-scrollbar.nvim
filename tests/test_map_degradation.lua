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
assert(map_view.resolve_mode(win, buf) == 'viewport', 'ordinary window did not use viewport')

vim.wo[win].wrap = true
assert(map_view.resolve_mode(win, buf) == 'viewport', 'default wrap strategy changed viewport mode')

config.apply({
  map_view = {
    degradation = { wrap = 'fit' },
  },
})
assert(map_view.resolve_mode(win, buf) == 'fit', 'explicit wrap fit fallback was ignored')

config.apply({
  map_view = {
    degradation = { wrap = 'scrollbar' },
  },
})
assert(map_view.resolve_mode(win, buf) == nil, 'wrap scrollbar fallback kept the map active')

config.apply()
vim.wo[win].wrap = false
vim.wo[win].diff = true
assert(map_view.resolve_mode(win, buf) == 'fit', 'diff window did not fall back to fit')

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
  'default viewport wrap strategy masked the visible-fold fallback'
)

api.nvim_win_call(win, function() vim.cmd('normal! 50Gzt') end)
assert(
  map_view.resolve_mode(win, buf) == 'fit',
  'scrolling past a closed fold switched the map from fit back to viewport'
)

api.nvim_win_call(win, function() vim.cmd('normal! zR') end)
assert(
  map_view.resolve_mode(win, buf) == 'viewport',
  'opening every fold did not restore the configured viewport mode'
)

api.nvim_win_call(win, function() vim.cmd('normal! zM') end)
config.apply({
  map_view = {
    degradation = { folds = 'viewport' },
  },
})
assert(
  map_view.resolve_mode(win, buf) == 'viewport',
  'explicit fold viewport strategy was ignored'
)

print('PASS: ordinary, wrap, diff and stable closed-fold map degradation strategies')
