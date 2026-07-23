local M = {}

---@class VVScrollbarHighlightConfig
---@field track vim.api.keyset.highlight 轨道背景 @default { bg = '#20242b' }
---@field separator vim.api.keyset.highlight 与文件窗口之间的分隔列 @default { fg = '#20242b', bg = '#20242b' }
---@field map_view vim.api.keyset.highlight 代码地图 @default { fg = '#565f89' }
---@field map_cursor vim.api.keyset.highlight 当前行 Braille dots 或细线 @default { fg = '#7aa2f7' }
---@field thumb vim.api.keyset.highlight 当前视口 thumb @default { bg = '#3b4252' }
---@field active vim.api.keyset.highlight 按下或拖拽中的 thumb @default { bg = '#5b6478' }
---@field cursor vim.api.keyset.highlight full 样式的当前行标记 @default { fg = '#7aa2f7' }
---@field search vim.api.keyset.highlight 搜索命中 @default { fg = '#ff9e64' }
---@field mark vim.api.keyset.highlight mark 位置 @default { fg = '#bb9af7' }
---@field quickfix vim.api.keyset.highlight quickfix / loclist 位置 @default { fg = '#e0af68' }
---@field diag_error vim.api.keyset.highlight Error 诊断 @default { fg = '#f7768e' }
---@field diag_warn vim.api.keyset.highlight Warn 诊断 @default { fg = '#e0af68' }
---@field diag_info vim.api.keyset.highlight Info 诊断 @default { fg = '#7dcfff' }
---@field diag_hint vim.api.keyset.highlight Hint 诊断 @default { fg = '#1abc9c' }

---@class VVScrollbarSymbolsConfig
---@field thumb string thumb 填充字符 @default ' '
---@field cursor string full 样式的当前行字符 @default '█'
---@field search string 搜索标记 @default '•'
---@field mark string mark 标记 @default '◆'
---@field quickfix string quickfix / loclist 标记 @default '■'
---@field diagnostics table<integer,string> 诊断 severity -> 标记 @default { [ERROR] = '●', [WARN] = '●', [INFO] = '●', [HINT] = '●' }
---@field git table<'A'|'C'|'D', string> git 行级标记 @default { A = '▎', C = '▎', D = '󰆐' }

---@class VVScrollbarMarkerConfig
---@field diagnostics boolean 是否显示诊断标记 @default true
---@field git boolean 是否显示 git 行级标记 @default true
---@field search boolean 是否显示当前 / 搜索命中 @default true
---@field marks boolean 是否显示 Vim marks @default true
---@field quickfix boolean 是否显示 quickfix / loclist @default true
---@field cursor boolean 是否显示光标位置 @default true

---@class VVScrollbarCursorConfig
---@field style 'dots'|'line'|'full'|'hidden' 当前行样式 @default 'line'
---@field side 'left'|'right' 细线所在侧 @default 'right'
---@field width integer 细线宽度 @default 1
---@field symbol string 细线字符 @default '▕'

---@class VVScrollbarRightClickContext
---@field win integer 源代码窗口
---@field scrollbar_win integer 滚动条窗口
---@field row integer 滚动条内的零基行号
---@field screenrow integer 屏幕行号
---@field screencol integer 屏幕列号
---@field view 'map_view'|'scrollbar' 点击时的滚动条形态

---@alias VVScrollbarRightClickAction false|'toggle_view'|fun(context: VVScrollbarRightClickContext)
---@alias VVScrollbarDragCursorMode 'follow'|'keep'

---@class VVScrollbarInteractionConfig
---@field right_click VVScrollbarRightClickAction 右键动作；false 关闭动作，自定义函数接收点击上下文 @default 'toggle_view'
---@field cursor_on_drag VVScrollbarDragCursorMode 拖拽时让 cursor 跟随视口或尽量保留原行 @default 'follow'
---@field marker_click 'center'|'top'|'scrollbar' 点击 marker 后的定位方式 @default 'center'

---@class VVScrollbarMapViewInteractionConfig
---@field edge_scroll boolean 拖拽接近上下边缘时是否自动平移地图 @default true
---@field edge_margin integer 触发边缘平移的地图行数 @default 2
---@field edge_speed integer 每次边缘平移的最大地图行数 @default 2
---@field edge_interval integer 持续边缘平移的时间间隔，单位 ms @default 50
---@field snap_to_edges boolean 拖出地图顶部或底部时是否吸附文件首尾 @default true

---@class VVScrollbarMapViewDegradationConfig
---@field folds 'viewport'|'fit'|'scrollbar' 可见关闭折叠时的降级方式 @default 'fit'
---@field wrap 'viewport'|'fit'|'scrollbar' wrap 窗口的降级方式 @default 'viewport'
---@field diff 'viewport'|'fit'|'scrollbar' diff 窗口的降级方式 @default 'fit'

---@class VVScrollbarMapViewSyntaxConfig
---@field enabled boolean 是否使用 Tree-sitter capture 为地图着色 @default true
---@field max_lines integer 语法着色最大文件行数，0 表示不限制 @default 2000
---@field max_bytes integer 语法着色最大文件字节数，0 表示不限制 @default 524288
---@field max_captures integer 一次地图重建最多读取的 Tree-sitter 高亮片段数；超出后整张地图使用基础单色，0 表示不限制 @default 30000
---@field max_time_ms integer 读取高亮片段并生成颜色区间的软时间上限，不含语法树解析和 Braille 绘制；超时后整张地图使用基础单色，0 表示不限制 @default 100
---@field fallback 'mono'|'scrollbar' 文件超过 max_lines 或 max_bytes 时保留单色地图或仅显示经典滚动条 @default 'mono'
---@field capture_map table<string,string|false> capture 名或根类别到高亮组的覆盖，false 表示使用单色 @default {}

---@class VVScrollbarMapViewConfig
---@field enabled boolean 是否显示代码地图 @default true
---@field mode 'viewport'|'fit' 地图布局模式 @default 'viewport'
---@field width 'auto'|integer 地图模式宽度 @default 'auto'
---@field min_width integer 自动宽度下限 @default 8
---@field max_width integer 自动宽度上限 @default 16
---@field width_ratio number 自动宽度占父布局的比例 @default 0.14
---@field x_multiplier integer 每个横向采样点覆盖的源代码屏幕列数 @default 4
---@field y_multiplier integer 每个纵向 Braille dot 覆盖的源代码行数 @default 1
---@field min_thumb integer viewport 模式的 thumb 最小高度 @default 2
---@field max_lines_per_dot integer 每个纵向地图点最多采样的源代码行数，0 表示不限制 @default 8
---@field tab_width 'buffer'|integer tab 显示宽度 @default 'buffer'
---@field include_whitespace boolean 是否把空白字符绘制为代码点 @default false
---@field debounce_ms integer 文本变化后重建地图的延迟 @default 150
---@field max_lines integer 允许生成地图的最大文件行数 @default 50000
---@field large_file_behavior 'scrollbar' 超过行数限制时的降级方式 @default 'scrollbar'
---@field preserve_map_under_thumb boolean thumb 是否仅叠加背景并保留地图字符 @default true
---@field marker_layout 'overlay'|'left'|'right' marker 与地图的列布局 @default 'right'
---@field marker_lane_width integer 独立 marker lane 宽度 @default 2
---@field marker_position 'left'|'right' marker 浮动侧 @default 'right'
---@field interaction VVScrollbarMapViewInteractionConfig 鼠标交互配置
---@field degradation VVScrollbarMapViewDegradationConfig 特殊窗口降级策略
---@field syntax VVScrollbarMapViewSyntaxConfig Tree-sitter 语法着色配置

---@class VVScrollbarConfig
---@field enabled boolean 是否启用 @default true
---@field current_only boolean 是否只显示当前窗口 @default false
---@field width integer 轨道宽度，单位为屏幕列 @default 2
---@field right_offset integer 距窗口右边缘的偏移列数 @default 0
---@field min_thumb integer thumb 最小高度 @default 2
---@field throttle_ms integer UI 刷新节流间隔 @default 30
---@field search_line_limit integer 搜索投影最大行数 @default 20000
---@field show_on_short_buffers boolean 文件无需滚动时是否仍显示当前视图 @default true
---@field cursor VVScrollbarCursorConfig 当前行样式
---@field interaction VVScrollbarInteractionConfig 通用鼠标交互配置
---@field excluded_filetypes string[] 排除的 filetype @default { 'terminal', 'toggleterm', ... }
---@field excluded_buftypes string[] 排除的 buftype @default { 'nofile', 'terminal', 'prompt', 'quickfix' }
---@field window_filter? fun(win:integer, buf:integer):boolean 窗口过滤器，返回 false 时隐藏滚动条 @default nil
---@field markers VVScrollbarMarkerConfig 标记开关
---@field map_view VVScrollbarMapViewConfig 代码地图配置
---@field symbols VVScrollbarSymbolsConfig 标记字符
---@field highlights VVScrollbarHighlightConfig 高亮定义

local defaults = require('vv-scrollbar.config.defaults')

---@type VVScrollbarConfig
local current = vim.deepcopy(defaults)

---@param value any
---@param fallback integer
---@return integer
local function positive_integer(value, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(math.floor(number), 1)
end

---@param value any
---@param fallback number
---@return number
local function positive_number(value, fallback)
  local number = tonumber(value)
  if not number or number <= 0 then return fallback end
  return number
end

---@param value any
---@param fallback integer
---@return integer
local function non_negative_integer(value, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(math.floor(number), 0)
end

---@param opts? VVScrollbarConfig
---@return VVScrollbarConfig
function M.apply(opts)
  current = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

  current.width = positive_integer(current.width, defaults.width)
  current.min_thumb = positive_integer(current.min_thumb, defaults.min_thumb)

  current.map_view.min_width = positive_integer(
    current.map_view.min_width,
    defaults.map_view.min_width
  )

  current.map_view.max_width = math.max(
    positive_integer(current.map_view.max_width, defaults.map_view.max_width),
    current.map_view.min_width
  )

  if current.map_view.width ~= 'auto' then
    current.map_view.width = positive_integer(current.map_view.width, defaults.map_view.max_width)
  end

  current.map_view.width_ratio = positive_number(
    current.map_view.width_ratio,
    defaults.map_view.width_ratio
  )

  current.map_view.x_multiplier = positive_integer(
    current.map_view.x_multiplier,
    defaults.map_view.x_multiplier
  )

  current.map_view.y_multiplier = positive_integer(
    current.map_view.y_multiplier,
    defaults.map_view.y_multiplier
  )

  current.map_view.min_thumb = positive_integer(
    current.map_view.min_thumb,
    defaults.map_view.min_thumb
  )

  current.map_view.max_lines_per_dot = math.max(
    math.floor(
      tonumber(current.map_view.max_lines_per_dot) or defaults.map_view.max_lines_per_dot
    ),
    0
  )

  if current.map_view.tab_width ~= 'buffer' then
    current.map_view.tab_width = positive_integer(
      current.map_view.tab_width,
      vim.o.tabstop
    )
  end

  current.map_view.debounce_ms = math.max(
    math.floor(tonumber(current.map_view.debounce_ms) or defaults.map_view.debounce_ms),
    0
  )

  current.map_view.max_lines = positive_integer(
    current.map_view.max_lines,
    defaults.map_view.max_lines
  )

  if not vim.tbl_contains({ 'viewport', 'fit' }, current.map_view.mode) then
    current.map_view.mode = defaults.map_view.mode
  end
  current.map_view.large_file_behavior = 'scrollbar'
  if not vim.tbl_contains({ 'overlay', 'left', 'right' }, current.map_view.marker_layout) then
    current.map_view.marker_layout = defaults.map_view.marker_layout
  end
  current.map_view.marker_lane_width = positive_integer(
    current.map_view.marker_lane_width,
    defaults.map_view.marker_lane_width
  )
  if current.map_view.marker_position ~= 'left' then
    current.map_view.marker_position = 'right'
  end
  if type(current.cursor) ~= 'table' then current.cursor = vim.deepcopy(defaults.cursor) end
  if not vim.tbl_contains({ 'dots', 'line', 'full', 'hidden' }, current.cursor.style) then
    current.cursor.style = defaults.cursor.style
  end
  if current.cursor.side ~= 'left' then
    current.cursor.side = 'right'
  end
  current.cursor.width = positive_integer(
    current.cursor.width,
    defaults.cursor.width
  )
  if type(current.cursor.symbol) ~= 'string'
      or current.cursor.symbol == ''
  then
    current.cursor.symbol = defaults.cursor.symbol
  end
  if type(current.show_on_short_buffers) ~= 'boolean' then
    current.show_on_short_buffers = defaults.show_on_short_buffers
  end
  if type(current.interaction) ~= 'table' then
    current.interaction = vim.deepcopy(defaults.interaction)
  end
  local global_interaction = current.interaction
  local default_global_interaction = defaults.interaction
  if global_interaction.right_click ~= false
      and global_interaction.right_click ~= 'toggle_view'
      and type(global_interaction.right_click) ~= 'function'
  then
    global_interaction.right_click = default_global_interaction.right_click
  end
  if not vim.tbl_contains({ 'follow', 'keep' }, global_interaction.cursor_on_drag) then
    global_interaction.cursor_on_drag = default_global_interaction.cursor_on_drag
  end
  if not vim.tbl_contains({ 'center', 'top', 'scrollbar' }, global_interaction.marker_click) then
    global_interaction.marker_click = default_global_interaction.marker_click
  end
  local interaction = current.map_view.interaction
  local default_interaction = defaults.map_view.interaction
  if type(interaction.edge_scroll) ~= 'boolean' then
    interaction.edge_scroll = default_interaction.edge_scroll
  end
  interaction.edge_margin = non_negative_integer(
    interaction.edge_margin,
    default_interaction.edge_margin
  )
  interaction.edge_speed = positive_integer(
    interaction.edge_speed,
    default_interaction.edge_speed
  )
  interaction.edge_interval = positive_integer(
    interaction.edge_interval,
    default_interaction.edge_interval
  )
  if type(interaction.snap_to_edges) ~= 'boolean' then
    interaction.snap_to_edges = default_interaction.snap_to_edges
  end
  local degradation = current.map_view.degradation
  local default_degradation = defaults.map_view.degradation
  for _, key in ipairs({ 'folds', 'wrap', 'diff' }) do
    if not vim.tbl_contains({ 'viewport', 'fit', 'scrollbar' }, degradation[key]) then
      degradation[key] = default_degradation[key]
    end
  end
  current.map_view.syntax = require('vv-scrollbar.config.syntax').normalize(
    current.map_view.syntax,
    defaults.map_view.syntax
  )
  current.right_offset = math.max(
    math.floor(tonumber(current.right_offset) or defaults.right_offset),
    0
  )
  current.throttle_ms = math.max(
    math.floor(tonumber(current.throttle_ms) or defaults.throttle_ms),
    0
  )
  return current
end

---@return VVScrollbarConfig
function M.current()
  return current
end

---@return VVScrollbarConfig
function M.get()
  return vim.deepcopy(current)
end

return M
