<div align="center">

<h1>vv-scrollbar.nvim</h1>

<a href="./README.md">English</a> | 中文

<img src="./docs/assets/vv-scrollbar.png" alt="vv-scrollbar 演示" width="900" />

想要我的 Neovim 配置？查看 <a href="https://github.com/beixiyo/dotfiles">dotfiles</a>

  <em>Neovim 自绘滚动条 — 完整轨道、点击跳转、原生拖拽与代码状态标记</em>

<br />

  <img src="https://img.shields.io/badge/Neovim-0.11+-57A143?style=flat-square&logo=neovim&logoColor=white" alt="Requires Neovim 0.11+" />
  <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua" />
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License" />
</div>

---

## 依赖

- [vv-utils.nvim](https://github.com/beixiyo/vv-utils.nvim) — 必须，提供滚动、Git、高亮与计时器等共享能力
- [Git](https://github.com/git/git) — 可选，仅 staged / unstaged 标记轨道需要

## 特性

在 Neovim 中提供类似 VSCode Minimap 的代码滚动地图体验：

- 点击地图或标记快速跳转
- 拖拽可视区域滚动代码
- 在地图区域使用鼠标滚轮滚动对应源窗口

## 安装

```lua
{
  'beixiyo/vv-scrollbar.nvim',
  dependencies = { 'beixiyo/vv-utils.nvim' },
  event = { 'BufReadPost', 'BufNewFile' },
  ---@type VVScrollbarConfig
  opts = {},
}
```

需要 Neovim `0.11+`。滚动条是一个 `style = 'minimal'` 的分屏窗口；鼠标交互完全由
`vim.on_key()` 拦截左键按下、拖拽、松开事件（包括快速多击）与垂直滚轮事件，再用 `getmousepos()`
的屏幕坐标命中滚动条实现

## 完整配置

```lua
require('vv-scrollbar').setup({
  enabled = true,
  current_only = false,
  width = 2,
  right_offset = 0,
  min_thumb = 2,
  throttle_ms = 30,
  search_line_limit = 20000,
  window_filter = nil,

  excluded_filetypes = {
    'terminal', 'toggleterm', 'blink-cmp-menu', 'cmp_docs', 'cmp_menu',
    'dropbar_menu', 'dropbar_menu_fzf', 'DressingInput', 'noice',
    'prompt', 'TelescopePrompt', 'dashboard', 'vv-explorer', 'vv-git',
    'vv-task-panel', 'vv-task-panel-tasks',
  },
  excluded_buftypes = { 'nofile', 'terminal', 'prompt', 'quickfix' },

  map_view = {
    enabled = true,
    mode = 'viewport',
    width = 'auto',
    min_width = 8,
    max_width = 16,
    width_ratio = 0.14,
    x_multiplier = 4,
    y_multiplier = 1,
    min_thumb = 2,
    max_lines_per_dot = 8,
    tab_width = 'buffer',
    include_whitespace = false,
    debounce_ms = 150,
    max_lines = 50000,
    large_file_behavior = 'scrollbar',
    show_on_short_buffers = true,
    preserve_map_under_thumb = true,
    marker_layout = 'overlay',
    marker_lane_width = 2,
    marker_position = 'right',
    marker_click = 'center',
    cursor = {
      style = 'dots',
      side = 'right',
      width = 1,
      symbol = '▎',
    },
    interaction = {
      edge_scroll = true,
      edge_margin = 2,
      edge_speed = 2,
      edge_interval = 50,
      snap_to_edges = true,
    },
    degradation = {
      folds = 'fit',
      wrap = 'viewport',
      diff = 'fit',
    },
    syntax = {
      enabled = true,
      max_lines = 2000,
      max_bytes = 524288,
      max_captures = 30000,
      max_time_ms = 100,
      fallback = 'mono',
      capture_map = {
        -- keyword = 'Keyword',
        -- comment = false,
      },
    },
  },

  markers = {
    diagnostics = true,
    git = true,
    search = true,
    marks = true,
    quickfix = true,
    cursor = true,
  },

  symbols = {
    thumb = ' ',
    cursor = '█',
    search = '•',
    mark = '◆',
    quickfix = '■',
    diagnostics = {
      [vim.diagnostic.severity.ERROR] = '●',
      [vim.diagnostic.severity.WARN] = '●',
      [vim.diagnostic.severity.INFO] = '●',
      [vim.diagnostic.severity.HINT] = '●',
    },
    git = {
      A = '▎',
      C = '▎',
      D = '󰆐',
    },
  },

  highlights = {
    track = { bg = '#20242b' },
    separator = { fg = '#20242b', bg = '#20242b' },
    map_view = { fg = '#565f89' },
    map_cursor = { fg = '#7aa2f7' },
    thumb = { bg = '#3b4252' },
    active = { bg = '#5b6478' },
    cursor = { fg = '#7aa2f7' },
    search = { fg = '#ff9e64' },
    mark = { fg = '#bb9af7' },
    quickfix = { fg = '#e0af68' },
    diag_error = { fg = '#f7768e' },
    diag_warn = { fg = '#e0af68' },
    diag_info = { fg = '#7dcfff' },
    diag_hint = { fg = '#1abc9c' },
  },
})
```

`setup()` 每次都从默认配置重新合并传入值，不会继承上一次调用中未再次提供的字段

## 基础配置

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | `boolean` | `true` | `setup()` 后是否立即启用 |
| `current_only` | `boolean` | `false` | 只为当前窗口显示滚动条 |
| `width` | `integer` | `2` | 轨道宽度，单位为屏幕格；最小值为 `1` |
| `right_offset` | `integer` | `0` | 距父窗口右边缘的偏移格数；最小值为 `0` |
| `min_thumb` | `integer` | `2` | thumb 最小高度；最小值为 `1` |
| `throttle_ms` | `integer` | `30` | 非鼠标直接交互的刷新节流时间；`0` 表示不延迟 |
| `search_line_limit` | `integer` | `20000` | 超过该行数时跳过搜索结果投影 |
| `excluded_filetypes` | `string[]` | 见完整配置 | 不显示滚动条的 filetype |
| `excluded_buftypes` | `string[]` | 见完整配置 | 不显示滚动条的 buftype |
| `window_filter` | `fun(win, buf): boolean` | `nil` | 返回 `false` 时不为该窗口显示滚动条 |

当窗口比配置宽度更窄时，实际宽度会自动收缩，避免浮窗越过父窗口

## Map View 配置

`map_view` 默认开启。`viewport` 模式按固定 Braille 比例渲染完整 buffer，再根据源窗口
滚动位置显示对应地图切片；thumb 使用地图绝对坐标，并通过背景色叠在地图上，不遮住字符
需要把全文压入当前窗口高度时，可以切换为 `fit`

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `map_view.enabled` | `boolean` | `true` | 显示代码地图；设为 `false` 恢复经典滚动条 |
| `map_view.mode` | `'viewport'\|'fit'` | `'viewport'` | 滚动固定比例地图，或将完整 buffer 压入窗口高度 |
| `map_view.width` | `'auto'\|integer` | `'auto'` | 自动或固定地图宽度 |
| `map_view.min_width` | `integer` | `8` | 自动宽度下限 |
| `map_view.max_width` | `integer` | `16` | 自动宽度上限 |
| `map_view.width_ratio` | `number` | `0.14` | 自动宽度占父布局的比例 |
| `map_view.x_multiplier` | `integer` | `4` | 一个横向点代表的源代码屏幕列数 |
| `map_view.y_multiplier` | `integer` | `1` | 一个纵向 Braille dot 代表的源代码行数 |
| `map_view.min_thumb` | `integer` | `2` | `viewport` 模式的 thumb 最小高度 |
| `map_view.max_lines_per_dot` | `integer` | `8` | 每个纵向点最多采样的源代码行数；`0` 表示不限制 |
| `map_view.tab_width` | `'buffer'\|integer` | `'buffer'` | 投影时使用的 tab 显示宽度 |
| `map_view.include_whitespace` | `boolean` | `false` | 把空白字符也绘制为地图点 |
| `map_view.debounce_ms` | `integer` | `150` | buffer 变化后重建地图的延迟 |
| `map_view.max_lines` | `integer` | `50000` | 超过该行数时回退经典滚动条 |
| `map_view.show_on_short_buffers` | `boolean` | `true` | 文件无需滚动时仍显示地图 |
| `map_view.preserve_map_under_thumb` | `boolean` | `true` | thumb 背景下继续显示地图字符 |
| `map_view.marker_layout` | `'overlay'\|'left'\|'right'` | `'overlay'` | marker 浮在地图上，或保留左/右独立 lane |
| `map_view.marker_lane_width` | `integer` | `2` | 左/右 marker lane 占用的列数 |
| `map_view.marker_position` | `'left'\|'right'` | `'right'` | 把代码状态 marker 浮动到地图指定侧 |
| `map_view.marker_click` | `'center'\|'top'\|'scrollbar'` | `'center'` | 点击 marker 后按精确源代码行定位 |
| `map_view.cursor.style` | `'dots'\|'line'\|'full'\|'hidden'` | `'dots'` | 改变地图点颜色、绘制细线、使用旧整行样式或隐藏 |
| `map_view.cursor.side` | `'left'\|'right'` | `'right'` | 当前行细线所在侧 |
| `map_view.cursor.width` | `integer` | `1` | 当前行细线宽度 |
| `map_view.cursor.symbol` | `string` | `'▎'` | 当前行细线字符 |
| `map_view.interaction.edge_scroll` | `boolean` | `true` | 拖拽接近地图上下边缘时自动平移 |
| `map_view.interaction.edge_margin` | `integer` | `2` | 触发边缘平移的地图行数 |
| `map_view.interaction.edge_speed` | `integer` | `2` | 每次边缘平移的最大地图行数 |
| `map_view.interaction.edge_interval` | `integer` | `50` | 持续边缘平移间隔，单位 ms |
| `map_view.interaction.snap_to_edges` | `boolean` | `true` | 拖出地图时吸附到文件开头或结尾 |
| `map_view.degradation.folds` | `'viewport'\|'fit'\|'scrollbar'` | `'fit'` | 出现可见关闭折叠时的行为 |
| `map_view.degradation.wrap` | `'viewport'\|'fit'\|'scrollbar'` | `'viewport'` | wrap 窗口的行为 |
| `map_view.degradation.diff` | `'viewport'\|'fit'\|'scrollbar'` | `'fit'` | diff 窗口的行为 |
| `map_view.syntax.enabled` | `boolean` | `true` | 使用 Tree-sitter capture 为地图点着色 |
| `map_view.syntax.max_lines` | `integer` | `2000` | 语法着色最大文件行数；`0` 表示不限制 |
| `map_view.syntax.max_bytes` | `integer` | `524288` | 语法着色最大文件字节数；`0` 表示不限制 |
| `map_view.syntax.max_captures` | `integer` | `30000` | 一次地图重建最多读取的 Tree-sitter 高亮片段数；超出后整张地图使用基础单色；`0` 表示不限制 |
| `map_view.syntax.max_time_ms` | `integer` | `100` | 读取高亮片段并生成颜色区间的软时间上限，不含语法树解析和 Braille 绘制；超时后整张地图使用基础单色；`0` 表示不限制 |
| `map_view.syntax.fallback` | `'mono'\|'scrollbar'` | `'mono'` | 文件超过 `max_lines` 或 `max_bytes` 时，保留单色地图或关闭地图并显示经典滚动条 |
| `map_view.syntax.capture_map` | `table<string,string\|false>` | `{}` | 按完整 capture 或根类别覆盖高亮组；`false` 使用单色 |

地图内容按 buffer 与投影配置缓存，滚动和拖拽不会重复扫描源代码。语法着色默认跟随
当前 Tree-sitter 主题并支持 injected language；可通过 `capture_map` 覆盖颜色，或设为
`false` 使用基础地图色。缺少 parser / highlight query，或高亮片段过多、处理过久时，也会
自动使用基础地图色

### 窗口级控制

插件或临时窗口可以通过窗口变量关闭自己的滚动条：

```lua
vim.w[win].vv_scrollbar_disabled = true
```

恢复时将变量设为 `nil` 或 `false`，再执行 `:VVScrollbarRefresh`。`vv-git.nvim`
会自动为左侧基准 diff 窗口设置该变量，仅保留右侧工作区的滚动条

需要把滚动条作为 marker 轨道常驻时，可设置：

```lua
vim.w[win].vv_scrollbar_always_show = true
```

`vv-git.nvim` 会为右侧 diff 窗口自动设置，避免折叠、换行或 diff filler 导致轨道
随滚动位置出现或消失

## Marker 配置

| 选项 | 默认值 | 数据来源 |
|------|--------|----------|
| `markers.diagnostics` | `true` | `vim.diagnostic.get()`，同一投影行优先显示最高严重级别 |
| `markers.git` | `true` | 普通文件通过 `diff_line_sets()` 显示 staged / unstaged 双轨；支持 `vv-git` scratch buffer |
| `markers.search` | `true` | 当前 `/` 寄存器匹配结果 |
| `markers.marks` | `true` | 当前 buffer 与全局的字母 mark |
| `markers.quickfix` | `true` | quickfix 与当前窗口 loclist |
| `markers.cursor` | `true` | 当前活动窗口的光标行，横向占满滚动条宽度 |

同一投影行出现多个 marker 时按优先级只显示一个：光标 > 诊断 > Git >
quickfix / loclist > mark > 搜索

## 符号配置

| 选项 | 默认值 | 说明 |
|------|--------|------|
| `symbols.thumb` | `' '` | thumb 填充字符，会重复填满滚动条宽度 |
| `symbols.cursor` | `'█'` | 当前光标标记，会重复填满滚动条宽度 |
| `symbols.search` | `'•'` | 搜索命中标记 |
| `symbols.mark` | `'◆'` | Vim mark 标记 |
| `symbols.quickfix` | `'■'` | quickfix / loclist 标记 |
| `symbols.diagnostics` | 四种 severity 映射 | 诊断标记字符 |
| `symbols.git` | `{ A, C, D }` | Git 新增、修改、删除标记字符 |

每个符号只读取第一个字符。除 thumb 和 cursor 外，其余 marker 不会横向重复

## 高亮配置

| 配置项 | 注册的高亮组 | 用途 |
|--------|--------------|------|
| `highlights.track` | `VVScrollbarTrack` | 背景轨道 |
| `highlights.separator` | `VVScrollbarSeparator` | 与文件窗口之间的分隔列 |
| `highlights.map_view` | `VVScrollbarMapView` | 单色代码地图前景 |
| `highlights.map_cursor` | `VVScrollbarMapCursor` | 当前行 Braille dots 或细线 |
| `highlights.thumb` | `VVScrollbarThumb` | 当前可见范围 |
| `highlights.active` | `VVScrollbarActive` | 按下或拖拽中的 thumb |
| `highlights.cursor` | `VVScrollbarCursor` | 当前光标位置 |
| `highlights.search` | `VVScrollbarSearch` | 搜索命中 |
| `highlights.mark` | `VVScrollbarMark` | Vim mark |
| `highlights.quickfix` | `VVScrollbarQuickfix` | quickfix / loclist |
| `highlights.diag_error` | `VVScrollbarDiagnosticError` | Error 诊断 |
| `highlights.diag_warn` | `VVScrollbarDiagnosticWarn` | Warn 诊断 |
| `highlights.diag_info` | `VVScrollbarDiagnosticInfo` | Info 诊断 |
| `highlights.diag_hint` | `VVScrollbarDiagnosticHint` | Hint 诊断 |

Git marker 使用 `vv-utils.git.register_hl()` 提供的 `VVGitAdded`、
`VVGitModified`、`VVGitDeleted`。所有高亮会在 `ColorScheme` 后重新注册

`highlights` 中的每一项都接受标准 `vim.api.nvim_set_hl()` 配置。若使用主题色板，
可以在插件管理配置中读取当前主题后传入，例如：

```lua
local p = require('tools.palette').get()

require('vv-scrollbar').setup({
  highlights = {
    track = { bg = p.bg_highlight },
    separator = { fg = p.bg, bg = p.bg },
    map_view = { fg = p.comment },
    map_cursor = { fg = p.blue },
  },
})
```

真实 split 固定保留一格 `WinSeparator`，无法缩成零宽。让 `separator` 使用编辑器
背景色，可以避免它在视觉上成为 map view 的左侧 padding；改成浮窗才能完全移除该格，
但浮窗会覆盖文件窗口最右侧内容

## 鼠标交互

| 操作 | 行为 |
|------|------|
| 点击轨道 | 以点击点为中心放置 thumb，并立即跳转对应视口 |
| 按下 thumb | 保持原位置并立即切换为 active 色 |
| 拖动 thumb | 保留按下时的抓取偏移，并实时更新视口 |
| 停在地图上下边缘 | 按配置速度持续平移冻结的地图 viewport |
| 拖出轨道顶部或底部 | 吸附到文件开头或结尾 |
| 松开鼠标或按 Esc | 结束拖拽、恢复 source/map 同步和普通 thumb 高亮 |

滚动条跳转和拖拽使用 `vv-utils.scroll.with_auto_suppressed()`，因此即使启用了
`vv-utils.scroll` 的自动跳转动画，也不会出现先跳到目标、回到旧位置、再动画到目标的回弹

## 命令

| 命令 | 说明 |
|------|------|
| `:VVScrollbarEnable` | 启用滚动条 |
| `:VVScrollbarDisable` | 禁用滚动条并关闭所有滚动条浮窗 |
| `:VVScrollbarToggle` | 切换启用状态 |
| `:VVScrollbarRefresh` | 重新获取可见文件的 Git marker 并立即刷新 |

## Lua API

```lua
local scrollbar = require('vv-scrollbar')

scrollbar.setup({ width = 2 })
scrollbar.enable()
scrollbar.disable()
scrollbar.toggle()

local current_config = scrollbar.get_config()
```

`get_config()` 返回深拷贝，修改返回值不会影响插件内部配置

## 模块结构

```text
lua/vv-scrollbar/
├── core/        几何计算、运行状态与窗口刷新编排
├── features/    Git、marker、map renderer 与私有缓存
├── input/       鼠标 press / drag / release 状态机
├── lifecycle/   autocmd 生命周期
├── ui/          split 生命周期、extmark 渲染与高亮注册
├── config.lua   默认配置与合并
└── init.lua     对外生命周期 API
```

## 测试

```bash
make test
```

可以通过 `NVIM` 指定 Neovim 可执行文件，例如 `NVIM=nvim-nightly make test`
