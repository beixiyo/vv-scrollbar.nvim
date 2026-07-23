# Changelog

## Unreleased

### Added

- 默认开启的 `map_view` 单色 Braille 全文件预览
- 自适应地图宽度、按 buffer 缓存、文本变化 debounce 与大文件降级
- thumb 背景与代码地图叠层渲染，保留原有点击和拖拽语义
- viewport 拖拽冻结、持续边缘平移、越界首尾吸附与 Esc 释放
- marker 精确源代码行点击，以及右侧固定窗口列浮动布局
- marker overlay、左侧 lane、右侧 lane 三种布局
- folds、wrap、diff 的窗口级 `viewport` / `fit` / `scrollbar` 降级策略
- `make test` 一键运行全部 headless 测试

### Changed

- map view 默认改为固定比例的可滚动 `viewport`，并保留 `fit` 兼容模式
- source viewport、地图切片和绝对 thumb 坐标保持同步，短文件不再纵向拉伸
- 同一 buffer 的多个窗口分别维护 map viewport、thumb 与窗口生命周期
- map view 当前行默认只改变已有 Braille dots 的颜色，不再占用额外列或覆盖 Git marker
- map view 当前行改用更明亮的默认蓝色，并允许独立配置分栏融合色
- 父窗口与 map view 之间的 split 分隔列默认融入地图背景，关闭时恢复原高亮
- 将窗口生命周期、extmark 渲染和刷新编排拆分为独立模块
- map cache 改为模块私有状态，避免污染全局运行状态
- marker 优先级集中为具名常量

### Fixed

- Git 双轨空 lane 在 thumb / hover 上继承当前背景，避免高优先级占位符切出遮罩缺口
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
