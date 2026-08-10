local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local scrollbar = require('vv-scrollbar')
local state = require('vv-scrollbar.core.state')

local lines = {}
for index = 1, 200 do lines[index] = ('line %03d'):format(index) end
api.nvim_buf_set_lines(0, 0, -1, false, lines)

local parent = api.nvim_get_current_win()
local width_before = api.nvim_win_get_width(parent)
scrollbar.setup({
  map_view = { enabled = false },
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

assert(state.bars[parent], 'setup 未创建滚动条分割窗口')

local callback_width
scrollbar.with_layout_suspended(function()
  assert(next(state.bars) == nil, '布局回调期间滚动条分割仍可见')
  assert(api.nvim_get_current_win() == parent, '布局回调未保留父窗口')
  callback_width = api.nvim_win_get_width(parent)
end)

assert(callback_width == width_before, '回调期间父窗口宽度未恢复滚动条列宽')
assert(state.bars[parent], '布局回调成功后滚动条未恢复')

scrollbar.with_layout_suspended(function()
  scrollbar.with_layout_suspended(function()
    assert(next(state.bars) == nil, '嵌套回调过早恢复了滚动条分割')
  end)
  assert(next(state.bars) == nil, '嵌套挂起在外层回调结束前恢复了滚动条分割')
end)
assert(state.bars[parent], '嵌套布局回调完成后滚动条未恢复')

local returned, nil_result, final_result = scrollbar.with_layout_suspended(function()
  vim.api.nvim_exec_autocmds('WinResized', { modeline = false })
  vim.wait(30)
  assert(next(state.bars) == nil, '定时布局刷新在回调执行中提前恢复了滚动条')
  return 'layout-result', nil, 'final-result'
end)
assert(returned == 'layout-result', '布局包装器未保留回调返回值')
assert(nil_result == nil and final_result == 'final-result',
  '布局包装器未保留含 nil 的多返回值')
assert(state.bars[parent], '延迟布局刷新后滚动条未恢复')

local ok = pcall(scrollbar.with_layout_suspended, function()
  scrollbar.with_layout_suspended(function()
    error('expected layout failure')
  end)
end)
assert(not ok, '嵌套布局回调错误未向上传播')
assert(state.layout_suspend_depth == 0, '嵌套布局回调错误导致挂起深度未清零')
assert(state.bars[parent], '嵌套布局回调失败后滚动条未恢复')

local window = require('vv-scrollbar.ui.window')
local original_sync = window.sync
window.sync = function(...)
  original_sync(...)
  error('expected render failure')
end
local recovery_ok, recovery_error = pcall(scrollbar.with_layout_suspended, function() end)
window.sync = original_sync
assert(not recovery_ok and tostring(recovery_error):find('expected render failure', 1, true),
  '布局包装器隐藏了渲染恢复失败')
assert(state.bars[parent] == nil, '恢复失败后留下了无效的滚动条状态条目')
require('vv-scrollbar.core.view').refresh()
assert(state.bars[parent] and api.nvim_win_is_valid(state.bars[parent].win),
  '渲染失败桩移除后滚动条未能恢复')

scrollbar.disable()
print('PASS: 暂停布局所有权与错误恢复')
