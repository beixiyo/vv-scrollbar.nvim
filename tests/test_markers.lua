local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local config = require('vv-scrollbar.config')
local projection = require('vv-scrollbar.core.projection')
local layout = require('vv-scrollbar.features.map_view.layout')
local markers = require('vv-scrollbar.features.markers')
local state = require('vv-scrollbar.core.state')

local buf = api.nvim_get_current_buf()
local lines = {}
for index = 1, 100 do lines[index] = 'line ' .. index end
api.nvim_buf_set_lines(buf, 0, -1, false, lines)

config.apply({
  width = 1,
  markers = {
    diagnostics = false,
    git = true,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})
state.git_marks[buf] = {
  staged = { [1] = 'A' },
  unstaged = { [2] = 'C' },
}

local viewport = { buf = buf, line_count = 100, height = 20 }
local function classic_line_to_row(line)
  return projection.line_to_row(line, viewport.line_count, viewport.height)
end
local map_marker = markers.collect(0, viewport, {
  track_width = 8,
  line_to_row = classic_line_to_row,
})[0]

assert(#map_marker.chunks == 2, '地图宽度未保留已暂存与未暂存 Git 轨道')
assert(#map_marker.hits == 2, '双向 Git 轨道未暴露独立命中目标')
assert(
  map_marker.chunks[1][2] == 'VVScrollbarGitStagedA'
    and map_marker.chunks[2][2] == 'VVGitModified',
  '已暂存与未暂存 Git 轨道未使用不同高亮组'
)
assert(
  map_marker.hits[1].source_line == 1
    and map_marker.hits[1].start_col == 0
    and map_marker.hits[1].end_col == 1,
  '已暂存 Git 轨道丢失源行或相对命中范围'
)
assert(
  map_marker.hits[2].source_line == 2
    and map_marker.hits[2].start_col == 1
    and map_marker.hits[2].end_col == 2,
  '未暂存 Git 轨道丢失源行或相对命中范围'
)

local narrow_marker = markers.collect(0, viewport, {
  track_width = 1,
  line_to_row = classic_line_to_row,
})[0]
assert(#narrow_marker.chunks == 1, '1 列轨道未合并 Git 渠道')
assert(
  #narrow_marker.hits == 1 and narrow_marker.hits[1].source_line == 2,
  '合并后的 Git 轨道未保留可见源行'
)

api.nvim_buf_set_lines(buf, 19, 24, false, {
  '<<<<<<< ours',
  'ours',
  '=======',
  'theirs',
  '>>>>>>> theirs',
})
state.git_marks[buf] = {
  staged = { [20] = 'A' },
  unstaged = { [20] = 'D' },
}
local conflict_viewport = { buf = buf, line_count = 100, height = 100 }
local conflict_markers = markers.collect(0, conflict_viewport, {
  track_width = 2,
  line_to_row = function(line) return line - 1 end,
})
for row = 19, 23 do
  local marker = conflict_markers[row]
  assert(marker and #marker.chunks == 2, '冲突块未保留双轨布局宽度')
  assert(marker.chunks[1][2] == 'VVScrollbarTrack'
      and marker.chunks[2][2] == 'VVGitConflict',
    '冲突块应只占右侧 U 轨道')
  assert(#marker.hits == 1 and marker.hits[1].start_col == 1
      and marker.hits[1].end_col == 2 and marker.hits[1].source_line == row + 1,
    '冲突块右轨未保留精确跳转范围')
end

api.nvim_buf_set_lines(buf, 19, 24, false, {
  'resolved one',
  'resolved two',
  'resolved three',
  'resolved four',
  'resolved five',
})
local resolved_markers = markers.collect(0, conflict_viewport, {
  track_width = 2,
  line_to_row = function(line) return line - 1 end,
})
assert(
  resolved_markers[19].chunks[1][2] == 'VVScrollbarGitStagedA'
    and resolved_markers[19].chunks[2][2] == 'VVGitDeleted',
  '解决冲突后未按 changedtick 失效缓存并恢复普通 Git marker'
)

-- 冲突标记本身就是诊断来源：同一投影行上 U 轨道必须压过诊断，压缩投影时跳转目标取块首行
api.nvim_buf_set_lines(buf, 19, 24, false, {
  '<<<<<<< ours',
  'ours',
  '=======',
  'theirs',
  '>>>>>>> theirs',
})
config.apply({
  width = 2,
  markers = { diagnostics = true, git = true, search = false, marks = false, quickfix = false, cursor = false },
})
local conflict_diag_ns = api.nvim_create_namespace('vv-scrollbar-test-conflict')
vim.diagnostic.set(conflict_diag_ns, buf, {
  { lnum = 19, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'unexpected <<<<<<<' },
  { lnum = 21, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'unexpected =======' },
})
local diag_conflict_markers = markers.collect(0, conflict_viewport, {
  track_width = 2,
  line_to_row = function(line) return line - 1 end,
})
for _, row in ipairs({ 19, 21 }) do
  local marker = diag_conflict_markers[row]
  assert(marker.chunks and marker.chunks[2][2] == 'VVGitConflict',
    '冲突块所在行的诊断不应遮住右侧 U 轨道')
end

local compressed_markers = markers.collect(0, conflict_viewport, {
  track_width = 2,
  line_to_row = function(line) return math.floor((line - 1) / 5) end,
})
assert(compressed_markers[3].chunks[1][2] == 'VVScrollbarTrack'
    and compressed_markers[3].chunks[2][2] == 'VVGitConflict',
  '压缩投影下 U 仍应清掉同行 staged 并只占右轨')
assert(#compressed_markers[4].hits == 1 and compressed_markers[4].hits[1].source_line == 21,
  '同一投影行多条冲突行时跳转目标应为最小行号')

vim.diagnostic.reset(conflict_diag_ns, buf)
config.apply({
  width = 1,
  markers = { diagnostics = false, git = true, search = false, marks = false, quickfix = false, cursor = false },
})

local map_viewport = { buf = buf, line_count = 400, height = 20 }
local middle_layout = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 201,
  botline = 220,
  thumb_row = 10,
  thumb_height = 1,
}, {
  mode = 'viewport',
  y_multiplier = 1,
  min_thumb = 2,
})
state.git_marks[buf] = {
  staged = { [1] = 'A', [201] = 'C', [204] = 'C' },
  unstaged = {},
}
local projected_markers = markers.collect(0, map_viewport, {
  track_width = 2,
  line_to_row = function(line) return layout.line_to_row(middle_layout, line) end,
})
assert(
  projected_markers[7]
    and projected_markers[7].hits[1].source_line == 201,
  '地图标记投影或确定性碰撞目标错误'
)
assert(
  projected_markers[0] == nil,
  '窗口外可见范围的标记错误地投影回窗口内'
)

local resized_layout = layout.resolve({
  line_count = 400,
  height = 10,
  topline = 201,
  botline = 220,
  thumb_row = 5,
  thumb_height = 1,
}, {
  mode = 'viewport',
  y_multiplier = 1,
  min_thumb = 2,
})
map_viewport.height = 10
local resized_markers = markers.collect(0, map_viewport, {
  track_width = 2,
  line_to_row = function(line) return layout.line_to_row(resized_layout, line) end,
})
assert(
  resized_markers[2]
    and resized_markers[2].hits[1].source_line == 201,
  '地图标记未跟随重设大小后的投影映射'
)

local diagnostic_ns = api.nvim_create_namespace('vv-scrollbar.marker-test')
vim.diagnostic.set(diagnostic_ns, buf, {
  { lnum = 4, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'first' },
  { lnum = 5, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'second' },
})
config.apply({
  markers = {
    diagnostics = true,
    git = false,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})
viewport.line_count = 100
viewport.height = 20
local diagnostic_marker = markers.collect(0, viewport, {
  line_to_row = classic_line_to_row,
})[1]
assert(
  diagnostic_marker
    and diagnostic_marker.hl == 'VVScrollbarDiagnosticError'
    and diagnostic_marker.source_line == 5,
  '诊断标记未按配置高亮或稳定碰撞目标渲染'
)

local ok, err = pcall(markers.collect, 0, viewport)
assert(
  not ok and tostring(err):find('marker projection is required', 1, true),
  '标记收集静默接受了缺失坐标投影'
)

vim.diagnostic.reset(diagnostic_ns, buf)
state.git_marks[buf] = nil
print('PASS: 标记轨道、精确命中、投影不变性与诊断颜色')
