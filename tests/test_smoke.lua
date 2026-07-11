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
local parent = api.nvim_get_current_win()
local width_before_scrollbar = api.nvim_win_get_width(parent)
scrollbar.setup({
  markers = marker_config,
})
view.refresh()

local win, buf = scrollbar_window()
assert(scrollbar.get_config().width == 2, 'default width is not 2')
assert(api.nvim_win_get_width(win) == 2, 'window width is not 2')
assert(
  api.nvim_win_get_width(parent) == width_before_scrollbar - 3,
  'scrollbar did not reserve its width and split separator from the parent window'
)
assert(api.nvim_win_get_config(win).relative == '', 'scrollbar is still a floating window')

local top_thumb_row = state.bars[parent].thumb_row
api.nvim_win_call(parent, function() vim.cmd('normal! Gzt') end)
view.refresh()
assert(state.bars[parent].thumb_row > top_thumb_row, 'thumb did not move after scrolling to the bottom')
api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
view.refresh()
assert(state.bars[parent].thumb_row == top_thumb_row, 'thumb did not return after scrolling to the top')

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
  return cfg.relative == '' and api.nvim_win_get_width(bar.win) == scrollbar.get_config().width
end, 10)
assert(layout_updated, 'scrollbar position stayed stale after closing a split')

local tmp_dir = vim.fn.tempname()
vim.fn.mkdir(tmp_dir, 'p')
local git_path = tmp_dir .. '/sample.txt'
local base_lines = {}
for index = 1, 399 do base_lines[index] = ('line %03d'):format(index) end
vim.fn.writefile(base_lines, git_path)
vim.fn.system({ 'git', '-C', tmp_dir, 'init', '-q' })
vim.fn.system({ 'git', '-C', tmp_dir, 'config', 'user.name', 'vv-scrollbar test' })
vim.fn.system({ 'git', '-C', tmp_dir, 'config', 'user.email', 'test@example.com' })
vim.fn.system({ 'git', '-C', tmp_dir, 'add', 'sample.txt' })
vim.fn.system({ 'git', '-C', tmp_dir, 'commit', '-qm', 'initial' })

local staged_lines = vim.deepcopy(base_lines)
table.insert(staged_lines, 200, 'staged line')
vim.fn.writefile(staged_lines, git_path)
vim.fn.system({ 'git', '-C', tmp_dir, 'add', 'sample.txt' })

scrollbar.setup({
  markers = {
    diagnostics = false,
    git = true,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})

local original_buf = api.nvim_win_get_buf(parent)
local staged_buf = api.nvim_create_buf(false, true)
api.nvim_set_option_value('buftype', 'nowrite', { buf = staged_buf })
api.nvim_buf_set_lines(staged_buf, 0, -1, false, staged_lines)
api.nvim_set_option_value('modifiable', false, { buf = staged_buf })
vim.b[staged_buf].vv_scrollbar_git_source = {
  root = tmp_dir,
  path = 'sample.txt',
  mode = 'staged',
  side = 'new',
}
api.nvim_win_set_buf(parent, staged_buf)

local staged_marker_loaded = vim.wait(3000, function()
  local git_marks = state.git_marks[staged_buf]
  return git_marks and git_marks.staged and git_marks.staged[200] == 'A'
end, 10)
assert(staged_marker_loaded, 'visible staged scratch buffer did not load cached git markers')

view.refresh()
local staged_bar = state.bars[parent]
assert(staged_bar and api.nvim_buf_is_valid(staged_bar.buf), 'staged scratch buffer has no scrollbar')
local staged_extmarks = api.nvim_buf_get_extmarks(staged_bar.buf, namespace, 0, -1, { details = true })
local found_staged_marker = false
for _, extmark in ipairs(staged_extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] and virt_text[1][2] == 'VVGitAdded' then
    found_staged_marker = true
    break
  end
end
assert(found_staged_marker, 'staged git marker was not rendered on the scrollbar')

local worktree_lines = vim.deepcopy(staged_lines)
worktree_lines[200] = 'staged line edited again'
vim.fn.writefile(worktree_lines, git_path)
local worktree_buf = vim.fn.bufadd(git_path)
vim.fn.bufload(worktree_buf)
api.nvim_win_set_buf(parent, worktree_buf)
require('vv-scrollbar.features.git').refresh(worktree_buf, view.refresh)

local dual_git_loaded = vim.wait(3000, function()
  local sets = state.git_marks[worktree_buf]
  return sets
    and sets.staged and sets.staged[200] == 'A'
    and sets.unstaged and sets.unstaged[200] == 'C'
end, 10)
assert(dual_git_loaded, 'ordinary buffer did not load staged and unstaged markers together')

view.refresh()
local dual_bar = state.bars[parent]
local dual_extmarks = api.nvim_buf_get_extmarks(dual_bar.buf, namespace, 0, -1, { details = true })
local found_dual_git_marker = false
for _, extmark in ipairs(dual_extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] and virt_text[2]
    and virt_text[1][2] == 'VVGitAdded'
    and virt_text[2][2] == 'VVGitModified'
  then
    found_dual_git_marker = true
    break
  end
end
assert(found_dual_git_marker, 'scrollbar did not render staged left and unstaged right')

api.nvim_win_set_buf(parent, original_buf)
api.nvim_buf_delete(worktree_buf, { force = true })
vim.fn.delete(tmp_dir, 'rf')

scrollbar.disable()
for _, candidate in ipairs(api.nvim_list_wins()) do
  local candidate_buf = api.nvim_win_get_buf(candidate)
  assert(vim.bo[candidate_buf].filetype ~= 'vv-scrollbar', 'disable left a scrollbar window')
end

print('PASS: width, markers, filters, split lifecycle, disable cleanup')
