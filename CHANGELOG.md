# Changelog

## 0.2.9 - 2026-10-04

### Fixed

- 刷新节流保留尾随调用，修复 Git diff 等异步结果返回后标记未及时显示的问题

## 0.2.8 - 2026-09-02

### Added

- 未解决冲突显示为优先于诊断的右侧 `U` 轨道；`vv-git` 冲突视图仅在上方 theirs diff 显示 ours-to-theirs 范围，Result 不重复显示

### Changed

- `markers.search` 默认改为 `false`，需要时显式开启；标记读取 `/` 寄存器，不随 `hlsearch` 关闭而消失

### Fixed

- 同一地图行覆盖多条冲突行时，点击与拖拽跳转到块内最小行号
- `vv-utils` 缺少冲突解析 API 时仅隐藏冲突标记，不再导致整条滚动条渲染失败
- `with_layout_suspended()` 在 `equalalways` 开启时不再重新均分没有滚动条的窗口

## 0.2.7 - 2026-08-10

### Fixed

- **慢仓库 Git marker**：同一文件在 Git diff 尚未完成时收到连续刷新

## 0.2.6 - 2026-08-03

### Fixed

- source 切换、buffer wipe、停用或重新 setup 时取消旧 Git diff 请求，同一 source 的连续刷新合并为当前请求完成后的一次补刷

## 0.2.5 - 2026-07-29

### Changed

- staged Git marker 默认向滚动条背景混合 70%，与保持原色的 unstaged 轨道区分

## 0.2.4 - 2026-07-28

### Added

- 新增 `cursor.style = 'horizontal'`，在地图内绘制当前行横线并保留独立 marker lane

### Changed

- 当前行默认改为 `▁` 横线，高亮链接到 `LineNr`

### Fixed

- 修复窗口高度快速切换后 map-view marker 绘制越界的问题

## 0.2.3 - 2026-07-27

### Fixed

- 修复 map-view extmark 在瞬态短行上的列坐标越界错误

## 0.2.2 - 2026-07-26

### Fixed

- 按下滚动条或 map-view 时先聚焦源窗口，避免原窗口的 `<LeftDrag>` 映射吞掉后续拖拽

## 0.2.1 - 2026-07-24

### Fixed

- 修复关闭折叠滚出可视区后地图高度跳变、thumb 被隐藏行放大及滚动与点击位置不准的问题

## 0.2.0 - 2026-07-24

### Breaking Changes

- 将 `highlights.hover` 配置迁移为 `highlights.active`，按下 thumb 后立即生效并在拖拽期间保持
- 将 `map_view.cursor`、`map_view.show_on_short_buffers`、`map_view.marker_click`、`map_view.interaction.right_click` 分别迁移为顶层 `cursor`、`show_on_short_buffers`、`interaction.marker_click`、`interaction.right_click`
- 默认高亮改为 Neovim 语义高亮组并跟随主题

### Added

- 默认开启 Braille 全文件 `map_view`，支持自适应宽度、内容缓存、编辑防抖、大文件降级及 thumb 叠层显示
- 支持 viewport 拖拽冻结、持续边缘平移、越界首尾吸附与 Esc 释放，以及右侧固定窗口列浮动布局
- 支持精确源代码行 marker 点击及 overlay、左侧 lane、右侧 lane 布局
- 支持 folds、wrap、diff 的窗口级 `viewport` / `fit` / `scrollbar` 降级策略
- 支持 Tree-sitter 语法着色、注入语言及 capture 映射，过载时降级为单色地图或经典滚动条
- 新增 `:VVScrollbarToggleView` / `toggle_view()` 切换地图与经典滚动条，右键默认触发且可替换或关闭
- 新增 `interaction.cursor_on_drag`，控制拖拽时光标跟随视口或尽量保留原代码行

### Changed

- 默认使用右侧 marker lane 与右侧 `▕` 当前行细线，支持 dots 着色、独立细线及分栏融合色，默认当前行蓝色更明亮且不遮盖 Git marker
- map-view 默认改为固定比例的可滚动 `viewport`，保留 `fit` 模式，短文件不再纵向拉伸
- 同一 buffer 的多个窗口独立维护地图视口、thumb 与生命周期，过期地图重建会被取消，换主题后刷新语法配色
- 父窗口与地图的分隔列默认融入地图背景，关闭时恢复原高亮

### Fixed

- marker 与地图切片保持同步，随窗口高度重算并隐藏切片外标记；同一投影行稳定跳转到最靠前的源代码行
- 诊断 marker 正确使用 `highlights.diag_*`，不再覆盖用户配色
- 经典滚动条遵循 marker 左右位置配置并支持细线 cursor 与精确点击，短文件切换视图后不再消失
- 地图轨道与 marker 点击精确定位源代码行，拖拽默认保持光标屏幕相对行，滚轮仅滚动源窗口
- 按下已有 thumb 不再引起地图抖动，快速多击与拖拽不再误入 Visual 模式
- 修复 Git 双轨空 lane 的背景缺口、错误合并轨道及 staged / unstaged 点击目标混用的问题
- 修复 `fit` 模式下文件尾部上移并留下空白地图行的问题

## [0.1.1] - 2026-07-19

### Changed

- 默认排除 `TelescopePrompt`、`vv-task-panel` 主面板与 `vv-task-panel-tasks` 任务列表

## [0.1.0] - 2026-07-13

### Added

- 基于真实 split 的滚动条与比例 thumb，支持轨道点击和拖拽
- 支持诊断、Git、搜索、mark、quickfix、loclist 与光标标记，以及独立 staged / unstaged Git 轨道
- 支持配置标记优先级、配色、宽度、可见性与排除 buffer
- 提供启用、停用、切换、刷新及抑制自动显示的命令与 Lua API
