local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local geometry = require('vv-scrollbar.core.geometry')

local win = api.nvim_get_current_win()
local buf = api.nvim_get_current_buf()
local lines = {}
local long_text = string.rep('x', api.nvim_win_get_width(win) + 20)
for index = 1, 400 do lines[index] = long_text .. index end
api.nvim_buf_set_lines(buf, 0, -1, false, lines)

vim.wo[win].foldmethod = 'manual'
vim.wo[win].foldenable = true
api.nvim_win_set_height(win, 20)
vim.cmd('101,300fold')

local function viewport_at(command)
  api.nvim_win_call(win, function() vim.cmd(command) end)
  return geometry.viewport(win)
end

local function assert_stable_geometry(label)
  local top = viewport_at('normal! ggzt')
  local folded = viewport_at('normal! 91Gzt')
  local after = viewport_at('normal! 301Gzt')
  local bottom = viewport_at('normal! Gzb')

  assert(
    top.thumb_height == folded.thumb_height
      and folded.thumb_height == after.thumb_height,
    label .. ': 闭合折叠滚动时改变了缩略条高度'
  )
  assert(
    top.thumb_row < folded.thumb_row
      and folded.thumb_row <= after.thumb_row
      and after.thumb_row < bottom.thumb_row,
    label .. ': 闭合折叠导致缩略条位置不再单调'
  )
  assert(
    bottom.thumb_row == bottom.max_row,
    label .. ': 折叠缓冲区末尾未锚定缩略条'
  )

  local middle_line = geometry.bar_row_to_line(win, math.floor(bottom.height / 2))
  local closed_start = api.nvim_win_call(win, function()
    return vim.fn.foldclosed(middle_line)
  end)
  assert(
    closed_start == -1 or closed_start == middle_line,
    label .. ': 滚动条投影指向了闭合折叠内的隐藏行'
  )

  viewport_at('normal! ggzt')
  geometry.scroll_to_bar_row(win, bottom.max_row)
  local scrolled = geometry.viewport(win)
  assert(
    scrolled.thumb_row == scrolled.max_row,
    label .. ': 拖动到轨道末端未展示折叠缓冲区末尾'
  )
end

vim.wo[win].wrap = false
assert_stable_geometry('nowrap')

vim.wo[win].wrap = true
assert_stable_geometry('wrap')

print('PASS: 折叠感知的缩略条尺寸、位置、边界与轨道投影')
