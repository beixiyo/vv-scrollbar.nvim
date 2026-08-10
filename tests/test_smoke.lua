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
  map_view = { enabled = false },
  markers = marker_config,
})
view.refresh()

local win, buf = scrollbar_window()
assert(api.nvim_win_get_width(win) == 2, '窗口宽度不是 2')
assert(
  api.nvim_win_get_width(parent) == width_before_scrollbar - 3,
  '滚动条未在父窗口保留宽度和分隔条'
)
assert(api.nvim_win_get_config(win).relative == '', '滚动条仍是浮动窗口')
assert(vim.fn.exists(':VVScrollbarToggleView') == 2, '视图切换命令未注册')

assert(scrollbar.toggle_view(), 'Lua 接口未开启地图视图')
win = scrollbar_window()
assert(scrollbar.get_config().map_view.enabled, 'Lua 接口未更新地图视图配置')
assert(api.nvim_win_get_width(win) >= 8, '地图视图未调整滚动条窗口宽度')

assert(not scrollbar.toggle_view(), 'Lua 接口未恢复经典滚动条')
win = scrollbar_window()
assert(not scrollbar.get_config().map_view.enabled, 'Lua 接口未关闭地图视图')
assert(api.nvim_win_get_width(win) == 2, '经典滚动条宽度未恢复')

vim.cmd('VVScrollbarToggleView')
assert(scrollbar.get_config().map_view.enabled, '视图切换命令未开启地图视图')
vim.cmd('VVScrollbarToggleView')
assert(not scrollbar.get_config().map_view.enabled, '视图切换命令未恢复滚动条')

local top_thumb_row = state.bars[parent].thumb_row
api.nvim_win_call(parent, function() vim.cmd('normal! Gzt') end)
view.refresh()
assert(state.bars[parent].thumb_row > top_thumb_row, '滚到底部后拇指未移动')
api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
view.refresh()
assert(state.bars[parent].thumb_row == top_thumb_row, '滚到顶部后拇指未回位')

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
assert(found_two_cell_thumb, '拇指高亮未覆盖 2 个单元格')

scrollbar.setup({
  width = 3,
  map_view = { enabled = false },
  markers = { git = false },
})
win = scrollbar_window()
assert(api.nvim_win_get_width(win) == 3, '运行时宽度未更新为 3')

scrollbar.setup({
  width = 2,
  map_view = { enabled = false },
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
local found_horizontal_cursor = false
local found_full_cursor = false
for _, extmark in ipairs(cursor_extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] then
    if virt_text[1][2] == 'VVScrollbarMapCursor' then
      found_horizontal_cursor = vim.fn.strdisplaywidth(virt_text[1][1]) == 2
        and extmark[4].virt_text_win_col == 0
    elseif virt_text[1][2] == 'VVScrollbarCursor' then
      found_full_cursor = true
    end
  end
end
assert(found_horizontal_cursor, '经典滚动条未渲染水平光标')
assert(not found_full_cursor, '经典滚动条仍渲染了全宽光标')

api.nvim_buf_set_mark(0, 'a', 200, 0, {})
scrollbar.setup({
  width = 2,
  map_view = {
    enabled = false,
    marker_position = 'right',
  },
  markers = {
    diagnostics = false,
    git = false,
    search = false,
    marks = true,
    quickfix = false,
    cursor = false,
  },
})
view.refresh()
local classic_bar = state.bars[parent]
local mark_row =
  require('vv-scrollbar.core.projection').line_to_row(200, 400, classic_bar.height)
local mark_hits = classic_bar.marker_hits[mark_row]
assert(
  mark_hits
    and #mark_hits == 1
    and mark_hits[1].start_col == 1
    and mark_hits[1].source_line == 200,
  '经典标记未保留其右对齐的精确命中目标'
)
local bar_left = vim.fn.win_screenpos(classic_bar.win)[2]
assert(
  view.marker_at(classic_bar, mark_row, bar_left + 1).source_line == 200,
  '经典标记点击测试未解析出精确源行'
)

vim.w[parent].vv_scrollbar_disabled = true
view.refresh()
assert(state.bars[parent] == nil, '窗口级禁用未隐藏滚动条')

vim.w[parent].vv_scrollbar_disabled = nil
scrollbar.setup({
  map_view = { enabled = false },
  markers = marker_config,
  window_filter = function(win)
    return win ~= parent
  end,
})
assert(state.bars[parent] == nil, '窗口过滤规则未隐藏滚动条')

scrollbar.setup({
  map_view = { enabled = false },
  markers = marker_config,
})
view.refresh()
assert(state.bars[parent], '清理窗口过滤规则后滚动条未恢复')

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
assert(locked_attempts == 1, 'E565 分支未执行锁定重试路径')
assert(lock_retry_succeeded, 'E565 临时锁定后未重试渲染滚动条')

vim.cmd('vsplit')
local split = api.nvim_get_current_win()
api.nvim_win_close(split, true)

local layout_updated = vim.wait(200, function()
  local bar = state.bars[parent]
  if not bar or not api.nvim_win_is_valid(bar.win) then return false end

  local cfg = api.nvim_win_get_config(bar.win)
  return cfg.relative == '' and api.nvim_win_get_width(bar.win) == scrollbar.get_config().width
end, 10)
assert(layout_updated, '关闭分屏后滚动条位置未及时更新')

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
  map_view = { enabled = false },
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
vim.b[staged_buf].vv_git_diff_source = {
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
assert(staged_marker_loaded, '可见的暂存临时缓冲区未加载缓存 git 标记')

view.refresh()
local staged_bar = state.bars[parent]
assert(staged_bar and api.nvim_buf_is_valid(staged_bar.buf), '暂存临时缓冲区未创建滚动条')
local staged_extmarks = api.nvim_buf_get_extmarks(staged_bar.buf, namespace, 0, -1, { details = true })
local found_staged_marker = false

for _, extmark in ipairs(staged_extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] and virt_text[1][2] == 'VVScrollbarGitStagedA' then
    found_staged_marker = true
    break
  end
end
assert(found_staged_marker, '滚动条未渲染暂存 git 标记')

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
assert(dual_git_loaded, '普通缓冲区未同时加载暂存与未暂存标记')

view.refresh()
local dual_bar = state.bars[parent]
local dual_extmarks = api.nvim_buf_get_extmarks(dual_bar.buf, namespace, 0, -1, { details = true })
local found_dual_git_marker = false
for _, extmark in ipairs(dual_extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text and virt_text[1] and virt_text[2]
    and virt_text[1][2] == 'VVScrollbarGitStagedA'
    and virt_text[2][2] == 'VVGitModified'
  then
    found_dual_git_marker = true
    break
  end
end
assert(found_dual_git_marker, '滚动条未在左侧渲染暂存、右侧渲染未暂存')

vim.fn.system({ 'git', '-C', tmp_dir, 'commit', '-qm', 'second' })
local revision_buf = api.nvim_create_buf(false, true)
api.nvim_set_option_value('buftype', 'nowrite', { buf = revision_buf })
api.nvim_buf_set_lines(revision_buf, 0, -1, false, staged_lines)
vim.b[revision_buf].vv_git_diff_source = {
  root = tmp_dir,
  path = 'sample.txt',
  from_rev = 'HEAD^',
  to_rev = 'HEAD',
  side = 'new',
}
api.nvim_win_set_buf(parent, revision_buf)

local revision_marker_loaded = vim.wait(3000, function()
  local sets = state.git_marks[revision_buf]
  return sets and sets.unstaged and sets.unstaged[200] == 'A'
end, 10)
assert(revision_marker_loaded, '修订版临时缓冲区未加载通用 git 标记')

view.refresh()
local revision_bar = state.bars[parent]
local revision_extmarks = api.nvim_buf_get_extmarks(
  revision_bar.buf,
  namespace,
  0,
  -1,
  { details = true }
)
local found_revision_marker = false
for _, extmark in ipairs(revision_extmarks) do
  local virt_text = extmark[4].virt_text
  for _, chunk in ipairs(virt_text or {}) do
    if chunk[2] == 'VVGitAdded' then
      found_revision_marker = true
      break
    end
  end
  if found_revision_marker then break end
end
assert(found_revision_marker, '修订版 git 标记未在滚动条渲染')

api.nvim_win_set_buf(parent, original_buf)
api.nvim_buf_delete(worktree_buf, { force = true })
api.nvim_buf_delete(revision_buf, { force = true })
vim.fn.delete(tmp_dir, 'rf')

scrollbar.disable()
for _, candidate in ipairs(api.nvim_list_wins()) do
  local candidate_buf = api.nvim_win_get_buf(candidate)
  assert(vim.bo[candidate_buf].filetype ~= 'vv-scrollbar', '停用后仍残留滚动条窗口')
end

print('PASS: 宽度、标记、过滤器、分屏生命周期与停用清理')
