# Changelog

## Unreleased

### Breaking Changes

- `highlights.hover` 重命名为 `highlights.active`；按下 thumb 时立即生效，并在拖拽期间保持
- `map_view.cursor`、`map_view.show_on_short_buffers` 与 `map_view.interaction.right_click` 移到顶层 `cursor`、`show_on_short_buffers` 与 `interaction.right_click`

### Added

- 默认开启的 `map_view` 单色 Braille 全文件预览
- 自适应地图宽度、按 buffer 缓存、文本变化 debounce 与大文件降级
- thumb 背景与代码地图叠层渲染，保留原有点击和拖拽语义
- viewport 拖拽冻结、持续边缘平移、越界首尾吸附与 Esc 释放
- marker 精确源代码行点击，以及右侧固定窗口列浮动布局
- marker overlay、左侧 lane、右侧 lane 三种布局
- folds、wrap、diff 的窗口级 `viewport` / `fit` / `scrollbar` 降级策略
- Tree-sitter capture 语法着色、injected language 与可配置 capture 映射
- 语法着色过载保护：大文件可退回单色地图或经典滚动条，高亮片段过多或处理过久时退回单色地图
- `make test` 一键运行全部 headless 测试
- `:VVScrollbarToggleView` / `toggle_view()` 切换 map-view 与经典滚动条，右键默认触发且可替换或关闭

### Changed

- 默认使用右侧 marker lane 与右侧 `▕` 当前行细线，并将共享 cursor、右键和短文件显示配置移到顶层
- map view 默认改为固定比例的可滚动 `viewport`，并保留 `fit` 兼容模式
- source viewport、地图切片和绝对 thumb 坐标保持同步，短文件不再纵向拉伸
- 同一 buffer 的多个窗口分别维护 map viewport、thumb 与窗口生命周期
- map view 当前行支持 Braille dots 着色或独立细线，不再覆盖 Git marker
- map view 当前行改用更明亮的默认蓝色，并允许独立配置分栏融合色
- 父窗口与 map view 之间的 split 分隔列默认融入地图背景，关闭时恢复原高亮
- 将窗口生命周期、extmark 渲染和刷新编排拆分为独立模块
- map cache 改为模块私有状态，避免污染全局运行状态
- marker 优先级集中为具名常量
- map cache 使用逐尺寸 generation token 取消过期重建，并在 `ColorScheme` 后刷新语法调色板

### Fixed

- 基础滚动条 marker 现在遵循左右位置配置并保留精确点击目标；短文件切换形态后不再丢失滚动条
- 基础滚动条复用细线 cursor 样式，点击轨道时按投影源代码行精确放置光标
- 点击 map-view 轨道或 marker 后将 cursor 精确落到对应源代码行，拖拽与滚轮仍只滚动视口
- map-view 上的滚轮事件改为滚动对应源窗口，不再滚走绘制内容
- 点击已有 thumb 时不再重复换算滚动位置，地图只在实际拖拽后冻结，避免按下与松开时抖动
- 拦截滚动条上的快速多击并为 nofile 窗口增加 Visual 守卫，避免误入选择模式
- Git 双轨空 lane 在 thumb / active 上继承当前背景，避免高优先级占位符切出遮罩缺口
- `fit` 投影改用完整高度比例分桶，避免整数压缩倍数导致文件尾部上移并留下空白地图行
- Git 双轨根据实际 map track 宽度布局，不再错误回退为合并轨道
- staged / unstaged Git marker 分别保存精确源代码行，点击同一地图行的不同轨道可独立跳转

## [0.1.1] - 2026-07-19

### Changed

- 默认排除 `TelescopePrompt` `vv-task-panel` 主面板与 `vv-task-panel-tasks` 任务列表

## [0.1.0] - 2026-07-13

### Added

- Real split-based scrollbar with proportional thumb rendering
- Diagnostic, Git, search, mark, quickfix, loclist, and cursor markers
- Independent staged and unstaged Git marker tracks
- Mouse track navigation and draggable thumb support
- Configurable marker priorities, colors, width, visibility, and excluded buffers
- Commands and Lua API for enabling, disabling, toggling, refreshing, and suppressing automatic display
