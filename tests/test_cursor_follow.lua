local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

package.loaded['vv-utils.scroll'] = {
  with_auto_suppressed = function(_, callback) callback() end,
}

local api = vim.api
local geometry = require('vv-scrollbar.core.geometry')

local lines = {}
for index = 1, 200 do
  lines[index] = ('line %03d content'):format(index)
end
api.nvim_buf_set_lines(0, 0, -1, false, lines)

local win = api.nvim_get_current_win()
api.nvim_win_set_height(win, 20)
vim.wo[win].wrap = false
vim.wo[win].diff = false
vim.wo[win].foldenable = false
vim.wo[win].scrolloff = 5

api.nvim_win_call(win, function()
  vim.fn.winrestview({
    topline = 40,
    lnum = 50,
    col = 7,
    curswant = 7,
  })
end)

local anchor = geometry.begin_cursor_follow(win)
assert(anchor and anchor.screen_row == 11, '普通视图未正确捕获光标屏幕行')
assert(vim.wo[win].scrolloff == 0, '跟随拖拽时未暂停 scrolloff')

geometry.scroll_to_line(win, 80, 'top', anchor)
local cursor = api.nvim_win_get_cursor(win)
assert(vim.fn.line('w0', win) == 80, '拖拽跟随后未保持请求的 topline')
assert(cursor[1] == 90 and cursor[2] == 7, '拖拽跟随未保持光标行和列')
assert(
  api.nvim_win_call(win, function() return vim.fn.winline() end) == 11,
  '拖拽跟随未保持光标屏幕行'
)

geometry.scroll_to_line(win, 120, 'top', anchor)
cursor = api.nvim_win_get_cursor(win)
assert(
  vim.fn.line('w0', win) == 120 and cursor[1] == 130,
  '连续拖拽跟随偏离了光标锚点'
)

vim.wo[win].wrap = true
api.nvim_win_call(win, function()
  vim.fn.winrestview({
    topline = 40,
    lnum = 50,
    col = 7,
    curswant = 7,
  })
end)
geometry.end_cursor_follow(win, anchor)
anchor = assert(geometry.begin_cursor_follow(win))
geometry.scroll_to_line(win, 150, 'center', anchor, 150)
cursor = api.nvim_win_get_cursor(win)
assert(
  cursor[1] == 150
    and api.nvim_win_call(win, function() return vim.fn.winline() end) == anchor.screen_row,
  '拖拽追踪未在开始前将光标定位到首选行'
)

api.nvim_buf_set_lines(0, 49, 50, false, { string.rep('x', 200) })
api.nvim_win_call(win, function()
  vim.fn.winrestview({
    topline = 40,
    lnum = 50,
    col = 100,
    curswant = 100,
  })
end)
geometry.end_cursor_follow(win, anchor)
anchor = assert(geometry.begin_cursor_follow(win))
local wrapped_screen_row = anchor.screen_row
geometry.scroll_to_line(win, 80, 'top', anchor)
assert(
  api.nvim_win_call(win, function() return vim.fn.winline() end) == wrapped_screen_row,
  '软换行拖拽未保持光标显示行'
)
api.nvim_buf_set_lines(0, 49, 50, false, { 'line 050 content' })
vim.wo[win].wrap = false

api.nvim_win_call(win, function()
  vim.fn.winrestview({
    topline = 40,
    lnum = 50,
    col = 7,
    curswant = 7,
  })
end)
geometry.end_cursor_follow(win, anchor)
anchor = assert(geometry.begin_cursor_follow(win))
local namespace = api.nvim_create_namespace('vv-scrollbar.cursor-follow-test')
api.nvim_buf_set_extmark(0, namespace, 84, 0, {
  virt_lines = { { { 'virtual line' } } },
})
geometry.scroll_to_line(win, 80, 'top', anchor)
assert(
  api.nvim_win_call(win, function() return vim.fn.winline() end) == anchor.screen_row,
  '虚拟显示行将光标拉到了视口边缘'
)
api.nvim_buf_clear_namespace(0, namespace, 0, -1)

vim.wo[win].foldenable = true
vim.wo[win].foldmethod = 'manual'
api.nvim_win_call(win, function()
  vim.cmd('85,88fold')
  vim.fn.winrestview({
    topline = 80,
    lnum = 90,
    col = 7,
    curswant = 7,
  })
end)
geometry.end_cursor_follow(win, anchor)
anchor = assert(geometry.begin_cursor_follow(win))
local folded_screen_row = anchor.screen_row
geometry.scroll_to_line(win, 100, 'top', anchor)
assert(
  api.nvim_win_call(win, function() return vim.fn.winline() end) == folded_screen_row,
  '闭合折叠将光标拉到了视口边缘'
)

vim.wo[win].foldenable = false
api.nvim_win_call(win, function()
  vim.fn.winrestview({
    topline = 40,
    lnum = 50,
    col = 7,
    curswant = 7,
  })
end)
geometry.end_cursor_follow(win, anchor)
anchor = assert(geometry.begin_cursor_follow(win))
geometry.end_cursor_follow(win, anchor)
assert(vim.wo[win].scrolloff == 5, '拖拽后未恢复 scrolloff')

print('PASS: 显示行光标跟随、列锚点、scrolloff、换行与折叠')
