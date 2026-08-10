local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local config = require('vv-scrollbar.config')
local drag = require('vv-scrollbar.input.viewport_drag')

local layout = {
  mode = 'viewport',
  line_count = 400,
  window_height = 20,
  content_height = 100,
  top_row = 43,
  thumb_row = 7,
  thumb_height = 5,
  rows_per_cell = 4,
}
local opts = {
  edge_scroll = true,
  edge_margin = 2,
  edge_speed = 2,
  edge_interval = 50,
  snap_to_edges = true,
}

local center = drag.update(layout, 10, 2, opts)
assert(center.top_row == 43, '中心拖拽意外移动了地图视口')
assert(center.source_line == 205, '中心拖拽丢失了拇指抓取偏移')
assert(not center.repeat_edge, '中心拖拽错误触发边缘滚动')

local top_edge = drag.update(layout, 0, 2, opts)
assert(top_edge.top_row == 41, '顶部边缘未上移地图')
assert(top_edge.source_line == 165, '顶部边缘未更新源目标行')
assert(top_edge.repeat_edge, '顶部边缘未请求持续滚动')

local bottom_edge = drag.update(layout, 19, 2, opts)
assert(bottom_edge.top_row == 45, '底部边缘未下移地图')
assert(bottom_edge.source_line == 241, '底部边缘未更新源目标行')
assert(bottom_edge.repeat_edge, '底部边缘未请求持续滚动')

local above = drag.update(layout, -1, 2, opts)
assert(
  above.snapped == 'top' and above.top_row == 0 and above.source_line == 1,
  '在地图上方拖拽时未吸附到文件起始'
)

local below = drag.update(layout, 20, 2, opts)
assert(
  below.snapped == 'bottom' and below.top_row == 80 and below.source_line == 400,
  '在地图下方拖拽时未吸附到文件末尾'
)

local at_top = vim.tbl_extend('force', layout, { top_row = 0 })
local top_limit = drag.update(at_top, 0, 2, opts)
assert(top_limit.top_row == 0 and not top_limit.repeat_edge, '顶部边界已到顶仍重复触发边缘滚动')

local no_edge = vim.tbl_extend('force', opts, { edge_scroll = false })
local stationary = drag.update(layout, 0, 2, no_edge)
assert(stationary.top_row == 43, '禁用边缘滚动后地图仍发生位移')

local no_snap = vim.tbl_extend('force', opts, { snap_to_edges = false })
local clamped = drag.update(layout, -1, 2, no_snap)
assert(not clamped.snapped and clamped.top_row == 41, '禁用边缘吸附时仍发生边缘平移')

local sanitized = config.apply({
  map_view = {
    interaction = {
      edge_scroll = 'invalid',
      edge_margin = -2,
      edge_speed = 0,
      edge_interval = 0,
      snap_to_edges = 'invalid',
    },
  },
  interaction = {
    right_click = 'invalid',
    cursor_on_drag = 'invalid',
    marker_click = 'invalid',
  },
})
local sanitized_interaction = sanitized.map_view.interaction
assert(
  sanitized_interaction.edge_scroll
    and sanitized_interaction.edge_margin == 0
    and sanitized_interaction.edge_speed == 1
    and sanitized_interaction.edge_interval == 1
    and sanitized_interaction.snap_to_edges
    and sanitized.interaction.right_click == 'toggle_view'
    and sanitized.interaction.cursor_on_drag == 'follow'
    and sanitized.interaction.marker_click == 'center',
  '无效的视口交互配置未标准化'
)

local custom_right_click = function() end
local right_click_options = config.apply({
  interaction = {
    right_click = custom_right_click,
  },
}).interaction
assert(
  right_click_options.right_click == custom_right_click,
  '自定义右键回调未保留'
)

right_click_options = config.apply({
  interaction = {
    right_click = false,
  },
}).interaction
assert(right_click_options.right_click == false, '禁用右键动作未保留')

local kept_cursor = config.apply({
  interaction = {
    cursor_on_drag = 'keep',
    marker_click = 'top',
  },
}).interaction
assert(
  kept_cursor.cursor_on_drag == 'keep' and kept_cursor.marker_click == 'top',
  '共享标记与光标交互模式未保留'
)

local invalid_shared = config.apply({
  cursor = false,
  interaction = false,
  show_on_short_buffers = 'invalid',
})
assert(
  invalid_shared.cursor.style == 'horizontal'
    and invalid_shared.interaction.right_click == 'toggle_view'
    and invalid_shared.interaction.cursor_on_drag == 'follow'
    and invalid_shared.interaction.marker_click == 'center'
    and invalid_shared.show_on_short_buffers,
  '共享配置中的非法项未标准化'
)

print('PASS: 抓取偏移、边缘平移、持续滚动、吸附与可配置回退')
