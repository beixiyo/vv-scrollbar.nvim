---@class VVScrollbarHighlightConfig
---@field track vim.api.keyset.highlight 轨道背景 @default { bg = 'bg' }
---@field separator vim.api.keyset.highlight 与文件窗口之间的分隔列 @default { fg = 'bg', bg = 'bg' }
---@field map_view vim.api.keyset.highlight 代码地图 @default { link = 'Comment' }
---@field map_cursor vim.api.keyset.highlight 当前行 Braille dots、横线或竖线 @default { link = 'LineNr' }
---@field thumb vim.api.keyset.highlight 当前视口 thumb @default { link = 'CursorLine' }
---@field active vim.api.keyset.highlight 按下或拖拽中的 thumb @default { link = 'Visual' }
---@field cursor vim.api.keyset.highlight full 样式的当前行标记 @default { link = 'CursorLineNr' }
---@field search vim.api.keyset.highlight 搜索命中 @default { link = 'Search' }
---@field mark vim.api.keyset.highlight mark 位置 @default { link = 'Special' }
---@field quickfix vim.api.keyset.highlight quickfix / loclist 位置 @default { link = 'QuickFixLine' }
---@field diag_error vim.api.keyset.highlight Error 诊断 @default { link = 'DiagnosticError' }
---@field diag_warn vim.api.keyset.highlight Warn 诊断 @default { link = 'DiagnosticWarn' }
---@field diag_info vim.api.keyset.highlight Info 诊断 @default { link = 'DiagnosticInfo' }
---@field diag_hint vim.api.keyset.highlight Hint 诊断 @default { link = 'DiagnosticHint' }

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
---@field style 'dots'|'line'|'horizontal'|'full'|'hidden' 当前行样式 @default 'horizontal'
---@field side 'left'|'right' 细线所在侧 @default 'right'
---@field width integer 细线宽度 @default 1
---@field symbol string line / horizontal 样式使用的字符 @default '▁'

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
---@field folds 'viewport'|'fit'|'scrollbar' 存在关闭折叠时的降级方式 @default 'fit'
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

---@class VVScrollbarConfigOpts
---@field enabled? boolean
---@field current_only? boolean
---@field width? integer
---@field right_offset? integer
---@field min_thumb? integer
---@field throttle_ms? integer
---@field search_line_limit? integer
---@field show_on_short_buffers? boolean
---@field cursor? VVScrollbarCursorConfigOpts
---@field interaction? VVScrollbarInteractionConfigOpts
---@field excluded_filetypes? string[]
---@field excluded_buftypes? string[]
---@field window_filter? fun(win:integer, buf:integer):boolean
---@field markers? VVScrollbarMarkerConfigOpts
---@field map_view? VVScrollbarMapViewConfigOpts
---@field symbols? VVScrollbarSymbolsConfigOpts
---@field highlights? VVScrollbarHighlightConfigOpts

---@class VVScrollbarHighlightConfigOpts
---@field track? vim.api.keyset.highlight
---@field separator? vim.api.keyset.highlight
---@field map_view? vim.api.keyset.highlight
---@field map_cursor? vim.api.keyset.highlight
---@field thumb? vim.api.keyset.highlight
---@field active? vim.api.keyset.highlight
---@field cursor? vim.api.keyset.highlight
---@field search? vim.api.keyset.highlight
---@field mark? vim.api.keyset.highlight
---@field quickfix? vim.api.keyset.highlight
---@field diag_error? vim.api.keyset.highlight
---@field diag_warn? vim.api.keyset.highlight
---@field diag_info? vim.api.keyset.highlight
---@field diag_hint? vim.api.keyset.highlight

---@class VVScrollbarSymbolsConfigOpts
---@field thumb? string
---@field cursor? string
---@field search? string
---@field mark? string
---@field quickfix? string
---@field diagnostics? table<integer, string>
---@field git? table<'A'|'C'|'D', string>

---@class VVScrollbarMarkerConfigOpts
---@field diagnostics? boolean
---@field git? boolean
---@field search? boolean
---@field marks? boolean
---@field quickfix? boolean
---@field cursor? boolean

---@class VVScrollbarCursorConfigOpts
---@field style? 'dots'|'line'|'horizontal'|'full'|'hidden'
---@field side? 'left'|'right'
---@field width? integer
---@field symbol? string

---@class VVScrollbarInteractionConfigOpts
---@field right_click? VVScrollbarRightClickAction
---@field cursor_on_drag? VVScrollbarDragCursorMode
---@field marker_click? 'center'|'top'|'scrollbar'

---@class VVScrollbarMapViewInteractionConfigOpts
---@field edge_scroll? boolean
---@field edge_margin? integer
---@field edge_speed? integer
---@field edge_interval? integer
---@field snap_to_edges? boolean

---@class VVScrollbarMapViewDegradationConfigOpts
---@field folds? 'viewport'|'fit'|'scrollbar'
---@field wrap? 'viewport'|'fit'|'scrollbar'
---@field diff? 'viewport'|'fit'|'scrollbar'

---@class VVScrollbarMapViewSyntaxConfigOpts
---@field enabled? boolean
---@field max_lines? integer
---@field max_bytes? integer
---@field max_captures? integer
---@field max_time_ms? integer
---@field fallback? 'mono'|'scrollbar'
---@field capture_map? table<string, string|false>

---@class VVScrollbarMapViewConfigOpts
---@field enabled? boolean
---@field mode? 'viewport'|'fit'
---@field width? 'auto'|integer
---@field min_width? integer
---@field max_width? integer
---@field width_ratio? number
---@field x_multiplier? integer
---@field y_multiplier? integer
---@field min_thumb? integer
---@field max_lines_per_dot? integer
---@field tab_width? 'buffer'|integer
---@field include_whitespace? boolean
---@field debounce_ms? integer
---@field max_lines? integer
---@field large_file_behavior? 'scrollbar'
---@field preserve_map_under_thumb? boolean
---@field marker_layout? 'overlay'|'left'|'right'
---@field marker_lane_width? integer
---@field marker_position? 'left'|'right'
---@field interaction? VVScrollbarMapViewInteractionConfigOpts
---@field degradation? VVScrollbarMapViewDegradationConfigOpts
---@field syntax? VVScrollbarMapViewSyntaxConfigOpts

return {}
