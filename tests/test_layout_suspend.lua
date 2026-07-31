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

assert(state.bars[parent], 'setup did not create a scrollbar split')

local callback_width
scrollbar.with_layout_suspended(function()
  assert(next(state.bars) == nil, 'scrollbar splits remained visible during the layout callback')
  assert(api.nvim_get_current_win() == parent, 'layout callback did not retain the parent window')
  callback_width = api.nvim_win_get_width(parent)
end)

assert(callback_width == width_before, 'parent width did not recover the scrollbar cells during the callback')
assert(state.bars[parent], 'scrollbar did not return after a successful layout callback')

scrollbar.with_layout_suspended(function()
  scrollbar.with_layout_suspended(function()
    assert(next(state.bars) == nil, 'nested callback restored scrollbar splits too early')
  end)
  assert(next(state.bars) == nil, 'nested suspension restored scrollbar splits before the outer callback finished')
end)
assert(state.bars[parent], 'scrollbar did not return after nested layout callbacks finished')

local returned, nil_result, final_result = scrollbar.with_layout_suspended(function()
  vim.api.nvim_exec_autocmds('WinResized', { modeline = false })
  vim.wait(30)
  assert(next(state.bars) == nil, 'scheduled layout refresh restored scrollbar during callback')
  return 'layout-result', nil, 'final-result'
end)
assert(returned == 'layout-result', 'layout wrapper did not preserve the callback return value')
assert(nil_result == nil and final_result == 'final-result',
  'layout wrapper did not preserve multiple return values with a nil hole')
assert(state.bars[parent], 'scrollbar did not return after scheduled refresh was deferred')

local ok = pcall(scrollbar.with_layout_suspended, function()
  scrollbar.with_layout_suspended(function()
    error('expected layout failure')
  end)
end)
assert(not ok, 'nested layout callback error did not propagate')
assert(state.layout_suspend_depth == 0, 'nested layout callback error left suspension depth active')
assert(state.bars[parent], 'scrollbar did not return after a failed nested layout callback')

local window = require('vv-scrollbar.ui.window')
local original_sync = window.sync
window.sync = function(...)
  original_sync(...)
  error('expected render failure')
end
local recovery_ok, recovery_error = pcall(scrollbar.with_layout_suspended, function() end)
window.sync = original_sync
assert(not recovery_ok and tostring(recovery_error):find('expected render failure', 1, true),
  'layout wrapper hid a render recovery failure')
assert(state.bars[parent] == nil, 'failed recovery left an invalid scrollbar state entry')
require('vv-scrollbar.core.view').refresh()
assert(state.bars[parent] and api.nvim_win_is_valid(state.bars[parent].win),
  'scrollbar could not recover after the render fixture was removed')

scrollbar.disable()
print('PASS: suspended layout ownership and error recovery')
