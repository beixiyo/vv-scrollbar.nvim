local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')

local parent = api.nvim_get_current_win()
local buf = api.nvim_get_current_buf()
local lines = {}
for index = 1, 200 do lines[index] = 'local value_' .. index .. ' = ' .. index end
api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.wo[parent].wrap = false

local scrollbar = require('vv-scrollbar')
local function configure(marker_layout, marker_position)
  scrollbar.setup({
    throttle_ms = 0,
    map_view = {
      width = 8,
      marker_layout = marker_layout,
      marker_lane_width = 2,
      marker_position = marker_position or 'right',
    },
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
    unstaged = { [1] = 'C' },
  }
  view.refresh()
  return state.bars[parent]
end

local left = configure('left')
assert(
  left.map_columns.map_start_col == 2 and left.map_columns.map_width == 6,
  '左侧通道未移动且未收缩渲染地图'
)
assert(
  left.marker_hits[0][1].start_col == 0 and left.marker_hits[0][2].start_col == 1,
  '左侧通道的 Git 命中目标越过了保留列'
)
local namespace = api.nvim_get_namespaces()['vv-scrollbar']
local left_extmarks = api.nvim_buf_get_extmarks(left.buf, namespace, 0, -1, { details = true })
local found_shifted_map = false
for _, extmark in ipairs(left_extmarks) do
  if extmark[4].hl_group == 'VVScrollbarMapView' then
    found_shifted_map = found_shifted_map or extmark[3] == 2
  end
end
assert(found_shifted_map, '左侧通道未移动地图高亮字节范围')

local right = configure('right')
assert(
  right.map_columns.map_start_col == 0 and right.map_columns.map_width == 6,
  '右侧通道更改了地图起始列或未预留宽度'
)
assert(
  right.marker_hits[0][1].start_col == 6 and right.marker_hits[0][2].start_col == 7,
  '右侧通道的 Git 命中目标超出了保留列'
)

local overlay = configure('overlay', 'left')
assert(overlay.map_columns.map_width == 8, '覆盖层意外缩小了地图')
assert(
  overlay.marker_hits[0][1].start_col == 0,
  '左侧 overlay 未尊重 marker_position'
)

scrollbar.disable()
print('PASS: 集成 overlay、左通道、右通道、地图宽度与 Git 命中目标')
