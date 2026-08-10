local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api

local source_lines = {}
for index = 1, 400 do
  source_lines[index] = ('local value_%d = function(argument) return argument + %d end'):format(
    index,
    index
  )
end
local parent = api.nvim_get_current_win()
local original_buf = api.nvim_get_current_buf()
local source_buf = api.nvim_create_buf(false, false)
api.nvim_buf_set_lines(source_buf, 0, -1, false, source_lines)
api.nvim_win_set_buf(parent, source_buf)
vim.wo[parent].wrap = false
api.nvim_set_option_value(
  'winhighlight',
  'Normal:Normal,CursorLine:CursorLine',
  { win = parent, scope = 'local' }
)
local original_winhighlight = api.nvim_get_option_value('winhighlight', { win = parent })

local markers = {
  diagnostics = false,
  git = false,
  search = false,
  marks = false,
  quickfix = false,
  cursor = false,
}
local scrollbar = require('vv-scrollbar')
scrollbar.setup({
  throttle_ms = 0,
  markers = markers,
  highlights = {
    map_cursor = { fg = '#abcdef' },
    separator = { fg = '#123456', bg = '#123456' },
  },
})

local view = require('vv-scrollbar.core.view')
local state = require('vv-scrollbar.core.state')
view.refresh()

local bar = state.bars[parent]
assert(bar and api.nvim_win_is_valid(bar.win), '默认地图视图未创建滚动条窗口')
local visual_guards = api.nvim_get_autocmds({ event = 'ModeChanged', buffer = bar.buf })
assert(
  vim.iter(visual_guards):any(function(autocmd)
    return autocmd.desc == 'vv-utils: 面板禁止鼠标拖拽 / 多击进入 visual'
  end),
  '地图缓冲区未安装 nofile visual-mode 防护'
)
assert(bar.track_width >= 8 and bar.track_width <= 16, '自动地图宽度未被限制在配置范围内')
assert(
  bar.map_layout and bar.map_layout.content_height > bar.height,
  '长文件地图高度仍与窗口高度耦合'
)
assert(
  api.nvim_get_option_value('winhighlight', { win = parent })
    == original_winhighlight .. ',WinSeparator:VVScrollbarSeparator',
  '地图分割线未使用可配置的滚动条高亮组'
)
assert(
  api.nvim_get_hl(0, { name = 'VVScrollbarMapCursor' }).fg == 0xabcdef,
  '自定义地图光标颜色被默认语义链接覆盖'
)
local separator_hl = api.nvim_get_hl(0, { name = 'VVScrollbarSeparator' })
assert(
  separator_hl.fg == 0x123456 and separator_hl.bg == 0x123456,
  '自定义分隔符颜色未注册'
)
local map_lines = api.nvim_buf_get_lines(bar.buf, 0, -1, false)
assert(
  table.concat(map_lines):find('[^ ]'),
  '地图视图缓冲区未显示可见代码预览'
)

local content = require('vv-scrollbar.ui.content')
local content_opts = {
  buf = source_buf,
  height = bar.height,
  track_width = bar.track_width,
  width = api.nvim_win_get_width(bar.win),
  winbar_offset = 0,
  map_layout = bar.map_layout,
  map_columns = bar.map_columns,
  refresh = function() end,
}
local short_lines, short_id = content.build(content_opts)
content_opts.height = content_opts.height + 1
local tall_lines, tall_id = content.build(content_opts)
assert(
  #tall_lines == #short_lines + 1 and tall_id ~= short_id,
  '地图内容身份未随窗口高度变化'
)

local original_ensure = content.ensure
local original_notify = vim.notify
local render_error

vim.bo[bar.buf].modifiable = true
api.nvim_buf_set_lines(bar.buf, 0, 1, false, { '' })
vim.bo[bar.buf].modifiable = false
---@diagnostic disable-next-line: duplicate-set-field
content.ensure = function() end
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(message, level, opts)
  if message:find('vv-scrollbar: render failed:', 1, true) then
    render_error = message
  end
  return original_notify(message, level, opts)
end
view.refresh()
vim.wait(20)
content.ensure = original_ensure
vim.notify = original_notify
assert(not render_error, render_error)

view.refresh()
assert(
  api.nvim_buf_get_lines(bar.buf, 0, 1, false)[1] == map_lines[1],
  '缓存地图内容未修复过时的滚动条缓冲行'
)

api.nvim_win_call(parent, function() vim.cmd('normal! 201Gzt') end)
view.refresh()
bar = state.bars[parent]
assert(bar.map_layout.top_row > 0, '源码滚动未带动地图视口移动')
assert(
  bar.thumb_row > 0 and bar.thumb_row + bar.thumb_height < bar.height,
  '源码居中区域未保持地图 thumb 可见'
)

api.nvim_win_call(parent, function() vim.cmd('normal! Gzt') end)
view.refresh()
bar = state.bars[parent]
assert(
  bar.map_layout.top_row == bar.map_layout.content_height - bar.height,
  '文件末尾未锚定地图视口终点'
)
assert(
  bar.thumb_row + bar.thumb_height == bar.height,
  '文件末尾未锚定地图 thumb'
)

api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
view.refresh()

local blank_buf = api.nvim_create_buf(false, false)
local blank_lines = {}
for index = 1, 400 do blank_lines[index] = '' end
api.nvim_buf_set_lines(blank_buf, 0, -1, false, blank_lines)
assert(
  api.nvim_buf_get_changedtick(blank_buf) == api.nvim_buf_get_changedtick(source_buf),
  '缓冲区切换回归用例未共享同一 changedtick'
)

api.nvim_win_set_buf(parent, blank_buf)
view.refresh()
local blank_map = table.concat(api.nvim_buf_get_lines(bar.buf, 0, -1, false))
assert(not blank_map:find('[^ ]'), '空源码缓冲却产出代码地图点')

api.nvim_win_set_buf(parent, source_buf)
view.refresh()
local restored_map = table.concat(api.nvim_buf_get_lines(bar.buf, 0, -1, false))
assert(
  restored_map:find('[^ ]'),
  '共享 changedtick 的缓冲切换复用了其他缓冲地图'
)
api.nvim_buf_delete(blank_buf, { force = true })

local runtime_config = scrollbar.get_config()
runtime_config.markers.git = true
runtime_config.markers.cursor = true
runtime_config.map_view.marker_layout = 'right'
runtime_config.cursor.style = 'line'
runtime_config.cursor.symbol = '▕'
scrollbar.setup(runtime_config)
local geometry = require('vv-scrollbar.core.geometry')
local projection = require('vv-scrollbar.core.projection')
local map_view = require('vv-scrollbar.features.map_view')

state.git_marks[source_buf] = {
  staged = { [1] = 'A' },
  unstaged = {},
}
view.refresh()
bar = state.bars[parent]
local layer_namespace = api.nvim_get_namespaces()['vv-scrollbar']
local function empty_git_lane_uses(expected_hl)
  local extmarks = api.nvim_buf_get_extmarks(
    bar.buf,
    layer_namespace,
    0,
    -1,
    { details = true }
  )
  for _, extmark in ipairs(extmarks) do
    local virt_text = extmark[4].virt_text
    if virt_text
        and virt_text[1] and virt_text[1][2] == 'VVScrollbarGitStagedA'
        and virt_text[2] and virt_text[2][1] == ' '
    then
      return virt_text[2][2] == expected_hl
    end
  end
  return false
end

assert(
  empty_git_lane_uses('VVScrollbarThumb'),
  '空 Git 轨道打了 thumb 背景空洞'
)
assert(
  bar.row_markers[0].chunks[2][2] == 'VVScrollbarTrack',
  'thumb 组合污染了缓存的 Git 标记 chunk'
)
state.dragging = {
  parent = parent,
  offset = 0,
  moved = false,
  map_top = bar.map_layout.top_row,
}
view.refresh()
bar = state.bars[parent]
assert(
  empty_git_lane_uses('VVScrollbarActive'),
  '拖拽前空 Git 轨道打了 active 背景空洞'
)
state.dragging = nil
view.refresh()

api.nvim_win_call(parent, function() vim.cmd('normal! 201Gzt') end)
state.git_marks[source_buf] = {
  staged = { [201] = 'A' },
  unstaged = { [400] = 'D' },
}
view.refresh()
bar = state.bars[parent]
local visible_git_row = map_view.line_to_row(bar.map_layout, 201)
assert(
  visible_git_row ~= projection.line_to_row(201, #source_lines, bar.height),
  '长文件坐标映射用例未区分地图坐标与标准坐标'
)
assert(
  bar.row_markers[visible_git_row]
    and bar.row_markers[visible_git_row].hits[1].source_line == 201,
  '长文件 Git 标记未对齐其可见地图行'
)
for _, marker in pairs(bar.row_markers) do
  for _, hit in ipairs(marker.hits or {}) do
    assert(hit.source_line ~= 400, '超出切片范围的 Git 标记仍在地图中可见')
  end
end

api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
view.refresh()
bar = state.bars[parent]

local staged_line
local unstaged_line
for line = 6, #source_lines do
  local previous_row = map_view.line_to_row(bar.map_layout, line - 1)
  local current_row = map_view.line_to_row(bar.map_layout, line)
  if previous_row == current_row then
    staged_line = line - 1
    unstaged_line = line
    break
  end
end
assert(staged_line and unstaged_line, 'Git 轨道用例未找到共享投影行')

state.git_marks[source_buf] = {
  staged = { [1] = 'A', [staged_line] = 'A' },
  unstaged = { [1] = 'C', [unstaged_line] = 'D' },
}
api.nvim_win_set_cursor(parent, { 1, 0 })
view.refresh()
bar = state.bars[parent]

local git_row = map_view.line_to_row(bar.map_layout, unstaged_line)
local git_marker = bar.row_markers[git_row]
assert(git_marker and #git_marker.hits == 2, 'Git 标记未保留独立点击命中目标')

local git_hits = bar.marker_hits[git_row]
assert(git_hits and #git_hits == 2, 'Git 轨道未保留独立点击命中目标')
assert(git_hits[1].start_col == bar.track_width - 2, 'Git 轨道未靠右对齐')
local bar_left = vim.fn.win_screenpos(bar.win)[2]
assert(
  view.marker_at(bar, git_row, bar_left + git_hits[1].start_col).source_line == staged_line,
  '已暂存 Git 标记未保留准确源行'
)
assert(
  view.marker_at(bar, git_row, bar_left + git_hits[2].start_col).source_line == unstaged_line,
  '未暂存 Git 标记未保留准确源行'
)
assert(
  view.marker_at(bar, git_row, bar_left) == nil,
  'Git 标记点击区域仍覆盖左侧代码地图'
)

local cursor_row = map_view.line_to_row(bar.map_layout, 1)
assert(
  bar.row_markers[cursor_row] and bar.row_markers[cursor_row].hits,
  '地图光标仍挤占同一投影行的 Git 标记'
)

api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
geometry.scroll_to_line(parent, unstaged_line, 'center')
local centered_top = vim.fn.line('w0', parent)
local centered_bottom = vim.fn.line('w$', parent)
assert(
  centered_top <= unstaged_line and centered_bottom >= unstaged_line,
  '精确标记跳转未将源行滚入可见范围'
)
geometry.set_cursor_line(parent, unstaged_line)
assert(
  api.nvim_win_get_cursor(parent)[1] == unstaged_line,
  '精确标记跳转未将光标移动到源行'
)

local namespace = api.nvim_get_namespaces()['vv-scrollbar']
local extmarks = api.nvim_buf_get_extmarks(bar.buf, namespace, 0, -1, { details = true })
local map_hl = api.nvim_get_hl_id_by_name('VVScrollbarMapView')
local thumb_hl = api.nvim_get_hl_id_by_name('VVScrollbarThumb')
local found_map = false
local found_thumb = false
local found_right_git = false
local found_cursor_line = false
local found_cursor_span = false
for _, extmark in ipairs(extmarks) do
  found_map = found_map
    or extmark[4].hl_group == map_hl
    or extmark[4].hl_group == 'VVScrollbarMapView'
  found_thumb = found_thumb
    or extmark[4].hl_group == thumb_hl
    or extmark[4].hl_group == 'VVScrollbarThumb'
  found_cursor_span = found_cursor_span
    or extmark[4].hl_group == api.nvim_get_hl_id_by_name('VVScrollbarMapCursor')
    or extmark[4].hl_group == 'VVScrollbarMapCursor'
  local virt_text = extmark[4].virt_text
  if virt_text then
    for _, chunk in ipairs(virt_text) do
      found_cursor_line = found_cursor_line or chunk[2] == 'VVScrollbarMapCursor'
      if chunk[2] == 'VVGitDeleted' then
        found_right_git = extmark[4].virt_text_win_col == bar.track_width - 2
      end
    end
  end
end
assert(found_map, '地图前景高亮未应用')
assert(found_thumb, 'thumb 背景未叠加到地图上')
assert(found_right_git, 'Git 标记未浮在右侧边缘')
assert(found_cursor_line, '地图光标未绘制配置的细线')
assert(not found_cursor_span, '细线光标仍重色了地图点')

runtime_config.cursor.style = 'horizontal'
runtime_config.cursor.symbol = '▁'
scrollbar.setup(runtime_config)
view.refresh()
bar = state.bars[parent]
extmarks = api.nvim_buf_get_extmarks(bar.buf, namespace, 0, -1, { details = true })
local found_horizontal_cursor = false
for _, extmark in ipairs(extmarks) do
  local virt_text = extmark[4].virt_text
  if virt_text
      and virt_text[1]
      and virt_text[1][1] == string.rep('▁', bar.map_columns.map_width)
      and virt_text[1][2] == 'VVScrollbarMapCursor'
      and extmark[4].virt_text_win_col == bar.map_columns.map_start_col
  then
    found_horizontal_cursor = true
    break
  end
end
assert(found_horizontal_cursor, '横向光标未横跨完整地图列')

api.nvim_set_hl(0, 'VVScrollbarTestSeparator', { fg = '#654321' })
local latest_winhighlight = 'Normal:Normal,WinSeparator:VVScrollbarTestSeparator'
api.nvim_set_option_value(
  'winhighlight',
  latest_winhighlight,
  { win = parent, scope = 'local' }
)
view.refresh()
local active_winhighlight = api.nvim_get_option_value('winhighlight', { win = parent })
assert(
  active_winhighlight:find('Normal:Normal', 1, true)
    and active_winhighlight:find('WinSeparator:VVScrollbarSeparator', 1, true),
  '滚动条生命周期错误改写了无关父窗口高亮: ' .. active_winhighlight
)
scrollbar.disable()
local restored_winhighlight = api.nvim_get_option_value('winhighlight', { win = parent })
assert(
  restored_winhighlight == latest_winhighlight,
  ('禁用滚动条后未恢复父窗口高亮: %q ~= %q')
    :format(restored_winhighlight, latest_winhighlight)
)
api.nvim_win_set_buf(parent, original_buf)
api.nvim_buf_delete(source_buf, { force = true })
print('PASS: 地图窗口、高亮、分层、精确 Git 命中与分隔符生命周期')
