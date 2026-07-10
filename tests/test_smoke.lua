local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')

local marker_config = {
  diagnostics = false,
  git = false,
  search = false,
  marks = false,
  quickfix = false,
  cursor = false,
}

local function scrollbar_window()
  for _, win in ipairs(api.nvim_list_wins()) do
    local buf = api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'vv-scrollbar' then return win, buf end
  end
  error('scrollbar window not found')
end

local lines = {}
for index = 1, 400 do lines[index] = ('line %03d'):format(index) end
api.nvim_buf_set_lines(0, 0, -1, false, lines)

local scrollbar = require('vv-scrollbar')
scrollbar.setup({
  markers = marker_config,
})
view.refresh()

local win, buf = scrollbar_window()
assert(scrollbar.get_config().width == 2, 'default width is not 2')
assert(api.nvim_win_get_width(win) == 2, 'window width is not 2')

local namespace = api.nvim_get_namespaces()['vv-scrollbar']
local extmarks = api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
local found_two_cell_thumb = false
for _, extmark in ipairs(extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] and virt_text[1][2] == 'VVScrollbarThumb' then
    found_two_cell_thumb = vim.fn.strdisplaywidth(virt_text[1][1]) == 2
    if found_two_cell_thumb then break end
  end
end
assert(found_two_cell_thumb, 'thumb highlight does not cover 2 cells')

scrollbar.setup({ width = 3, markers = { git = false } })
win = scrollbar_window()
assert(api.nvim_win_get_width(win) == 3, 'runtime width did not update to 3')

scrollbar.setup({
  width = 2,
  markers = {
    diagnostics = false,
    git = false,
    search = false,
    marks = false,
    quickfix = false,
    cursor = true,
  },
})
view.refresh()
win, buf = scrollbar_window()

local cursor_extmarks = api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
local found_two_cell_cursor = false
for _, extmark in ipairs(cursor_extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] and virt_text[1][2] == 'VVScrollbarCursor' then
    found_two_cell_cursor = vim.fn.strdisplaywidth(virt_text[1][1]) == 2
    if found_two_cell_cursor then break end
  end
end
assert(found_two_cell_cursor, 'cursor marker does not cover 2 cells')

local parent = api.nvim_get_current_win()
vim.w[parent].vv_scrollbar_disabled = true
view.refresh()
assert(state.bars[parent] == nil, 'window-local disable did not hide the scrollbar')

vim.w[parent].vv_scrollbar_disabled = nil
scrollbar.setup({
  markers = marker_config,
  window_filter = function(win)
    return win ~= parent
  end,
})
assert(state.bars[parent] == nil, 'window_filter did not hide the scrollbar')

scrollbar.setup({ markers = marker_config })
view.refresh()
assert(state.bars[parent], 'scrollbar did not return after clearing window filters')

view.close(parent)
local original_open_win = api.nvim_open_win
local locked_attempts = 0
api.nvim_open_win = function(...)
  locked_attempts = locked_attempts + 1
  if locked_attempts == 1 then error('E565: Not allowed to change text or change window') end
  return original_open_win(...)
end

view.refresh()
api.nvim_open_win = original_open_win

local lock_retry_succeeded = vim.wait(200, function()
  local bar = state.bars[parent]
  return bar and api.nvim_win_is_valid(bar.win)
end, 10)
assert(locked_attempts == 1, 'E565 path did not exercise the locked render attempt')
assert(lock_retry_succeeded, 'scrollbar did not retry after a transient E565 lock')

vim.cmd('vsplit')
local split = api.nvim_get_current_win()
api.nvim_win_close(split, true)

local layout_updated = vim.wait(200, function()
  local bar = state.bars[parent]
  if not bar or not api.nvim_win_is_valid(bar.win) then return false end

  local cfg = api.nvim_win_get_config(bar.win)
  return cfg.col == api.nvim_win_get_width(parent) - cfg.width
end, 10)
assert(layout_updated, 'scrollbar position stayed stale after closing a split')

scrollbar.disable()
for _, candidate in ipairs(api.nvim_list_wins()) do
  local candidate_buf = api.nvim_win_get_buf(candidate)
  assert(vim.bo[candidate_buf].filetype ~= 'vv-scrollbar', 'disable left a scrollbar window')
end

print('PASS: width, markers, filters, split lifecycle, disable cleanup')
