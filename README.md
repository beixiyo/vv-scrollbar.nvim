<div align="center">

# vv-scrollbar.nvim

English | <a href="./README.zh-CN.md">中文</a>

<img src="./docs/assets/vv-scrollbar.png" alt="vv-scrollbar demo" width="900" />

Want my Neovim config? See <a href="https://github.com/beixiyo/dotfiles">dotfiles</a>.

<em>A custom Neovim scrollbar with a full track, click-to-jump, native dragging, and code-state markers</em>

<br />

<img src="https://img.shields.io/badge/Neovim-0.11+-57A143?style=flat-square&logo=neovim&logoColor=white" alt="Requires Neovim 0.11+" />
<img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua" />
<img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License" />

</div>

---

## Requirements

- [vv-utils.nvim](https://github.com/beixiyo/vv-utils.nvim) — required for shared scrolling, Git, highlighting, and timer utilities
- [Git](https://github.com/git/git) — optional; required only for staged and unstaged marker tracks

## Features

- A default-enabled Braille code map with adaptive width and a cached, debounced renderer
- A full-height background track and a thumb sized from the visible-content ratio
- Click the track to jump, or drag the thumb while preserving the original grab offset
- Pressing the thumb immediately shows its active color; dragging keeps the same feedback
- Integration with `vv-utils.scroll` prevents automatic smooth scrolling from pulling interactions back to an old view
- A real split reserves width, so the scrollbar never covers text at the end of a parent-window line
- Configurable width with track and thumb filling the available cells; the default is two cells
- Neovim's separator cell blends into the map background and restores its previous highlight on close
- Cursor markers fill the scrollbar width, Git uses two tracks, and other markers remain one character wide
- Multiple windows are supported, with an option to display only the current window
- Built-in diagnostics, Git diff, search, Vim marks, quickfix/loclist, and cursor markers
- Automatic updates for scrolling, window changes, resizing, text edits, diagnostics, and Git state
- Pure Lua implementation sharing UI and async infrastructure through `vv-utils.nvim`

## Dual Git tracks

The two cells in a normal file window carry independent Git states. The left cell represents staged changes from `HEAD` to the index, while the right cell represents unstaged changes from the index to the worktree. A line modified again after staging can color both tracks instead of losing one state to priority. Staged coordinates are mapped from the index onto the current worktree buffer. A staged scratch buffer created by `vv-git` uses only the left track.

## Installation

```lua
{
  'beixiyo/vv-scrollbar.nvim',
  dependencies = { 'beixiyo/vv-utils.nvim' },
  event = { 'BufReadPost', 'BufNewFile' },
  ---@type VVScrollbarConfig
  opts = {},
}
```

Neovim 0.11 or newer is required. The scrollbar is a `style = 'minimal'` split window; mouse interaction is handled entirely by `vim.on_key()`, which intercepts `<LeftMouse>`/`<LeftDrag>`/`<LeftRelease>` and maps the `getmousepos()` screen coordinates onto the bar via a hit-test.

## Complete configuration

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
    thumb = ' ', cursor = '█', search = '•', mark = '◆', quickfix = '■',
    diagnostics = {
      [vim.diagnostic.severity.ERROR] = '●',
      [vim.diagnostic.severity.WARN] = '●',
      [vim.diagnostic.severity.INFO] = '●',
      [vim.diagnostic.severity.HINT] = '●',
    },
    git = { A = '▎', C = '▎', D = '󰆐' },
  },

  highlights = {
    track = { bg = '#20242b' },
    separator = { fg = '#20242b', bg = '#20242b' },
    map_view = { fg = '#565f89' },
    map_cursor = { fg = '#7aa2f7' },
    thumb = { bg = '#3b4252' },
    active = { bg = '#5b6478' }, cursor = { fg = '#7aa2f7' },
    search = { fg = '#ff9e64' }, mark = { fg = '#bb9af7' },
    quickfix = { fg = '#e0af68' }, diag_error = { fg = '#f7768e' },
    diag_warn = { fg = '#e0af68' }, diag_info = { fg = '#7dcfff' },
    diag_hint = { fg = '#1abc9c' },
  },
})
```

Every `setup()` call merges its arguments into the defaults from scratch. It does not inherit fields omitted from the latest call.

## Basic configuration

| Option | Type | Default | Description |
|---|---|---|---|
| `enabled` | `boolean` | `true` | Enable immediately after setup |
| `current_only` | `boolean` | `false` | Show a scrollbar only for the current window |
| `width` | `integer` | `2` | Track width in screen cells; minimum one |
| `right_offset` | `integer` | `0` | Offset from the parent window's right edge; minimum zero |
| `min_thumb` | `integer` | `2` | Minimum thumb height; minimum one |
| `throttle_ms` | `integer` | `30` | Refresh throttle outside direct mouse interaction; zero disables delay |
| `search_line_limit` | `integer` | `20000` | Skip search projection above this line count |
| `excluded_filetypes` | `string[]` | See complete config | Filetypes without scrollbars |
| `excluded_buftypes` | `string[]` | See complete config | Buftypes without scrollbars |
| `window_filter` | `fun(win, buf): boolean` | `nil` | Return false to suppress a window |

The effective width shrinks automatically when a window is narrower than the configured value.

## Map view configuration

`map_view` is enabled by default. `viewport` mode renders the complete buffer at a fixed Braille
scale, then follows the source window with a scrollable map slice. The thumb uses absolute map
coordinates, and its background is layered over the preview without hiding the Braille cells.
Use `fit` to compress the complete buffer into the current window height.

| Option | Type | Default | Description |
|---|---|---|---|
| `map_view.enabled` | `boolean` | `true` | Show the code map; false restores the classic scrollbar |
| `map_view.mode` | `'viewport'\|'fit'` | `'viewport'` | Scroll a fixed-scale map or fit the complete buffer into the window |
| `map_view.width` | `'auto'\|integer` | `'auto'` | Automatic or fixed map width |
| `map_view.min_width` | `integer` | `8` | Lower bound for automatic width |
| `map_view.max_width` | `integer` | `16` | Upper bound for automatic width |
| `map_view.width_ratio` | `number` | `0.14` | Share of the parent layout used by automatic width |
| `map_view.x_multiplier` | `integer` | `4` | Source screen columns represented by one horizontal dot |
| `map_view.y_multiplier` | `integer` | `1` | Source lines represented by one vertical Braille dot |
| `map_view.min_thumb` | `integer` | `2` | Minimum thumb height in viewport mode |
| `map_view.max_lines_per_dot` | `integer` | `8` | Maximum sampled source lines per vertical dot; zero disables the limit |
| `map_view.tab_width` | `'buffer'\|integer` | `'buffer'` | Tab display width used during projection |
| `map_view.include_whitespace` | `boolean` | `false` | Render whitespace as map points |
| `map_view.debounce_ms` | `integer` | `150` | Delay before rebuilding a changed buffer |
| `map_view.max_lines` | `integer` | `50000` | Fall back to the classic scrollbar above this line count |
| `map_view.show_on_short_buffers` | `boolean` | `true` | Keep the map visible when the file does not need scrolling |
| `map_view.preserve_map_under_thumb` | `boolean` | `true` | Preserve preview characters under the thumb background |
| `map_view.marker_layout` | `'overlay'\|'left'\|'right'` | `'overlay'` | Float markers over the map or reserve a left/right lane |
| `map_view.marker_lane_width` | `integer` | `2` | Width reserved by left/right marker lanes |
| `map_view.marker_position` | `'left'\|'right'` | `'right'` | Float code-state markers over the selected map edge |
| `map_view.marker_click` | `'center'\|'top'\|'scrollbar'` | `'center'` | Exact source-line behavior when clicking a marker |
| `map_view.cursor.style` | `'dots'\|'line'\|'full'\|'hidden'` | `'dots'` | Recolor map dots, draw a line, use the legacy full marker, or hide it |
| `map_view.cursor.side` | `'left'\|'right'` | `'right'` | Side used by the slim current-line marker |
| `map_view.cursor.width` | `integer` | `1` | Width of the slim current-line marker |
| `map_view.cursor.symbol` | `string` | `'▎'` | Character used by the slim current-line marker |
| `map_view.interaction.edge_scroll` | `boolean` | `true` | Pan the map while dragging near its top or bottom edge |
| `map_view.interaction.edge_margin` | `integer` | `2` | Map rows that activate edge panning |
| `map_view.interaction.edge_speed` | `integer` | `2` | Maximum map rows advanced per edge-panning tick |
| `map_view.interaction.edge_interval` | `integer` | `50` | Continuous edge-panning interval in milliseconds |
| `map_view.interaction.snap_to_edges` | `boolean` | `true` | Snap to the file start or end when dragging outside the map |
| `map_view.degradation.folds` | `'viewport'\|'fit'\|'scrollbar'` | `'fit'` | Behavior while a closed fold is visible |
| `map_view.degradation.wrap` | `'viewport'\|'fit'\|'scrollbar'` | `'viewport'` | Behavior for wrapped windows |
| `map_view.degradation.diff` | `'viewport'\|'fit'\|'scrollbar'` | `'fit'` | Behavior for diff windows |
| `map_view.syntax.enabled` | `boolean` | `true` | Color map cells from Tree-sitter captures |
| `map_view.syntax.max_lines` | `integer` | `2000` | Maximum lines for syntax coloring; zero disables the limit |
| `map_view.syntax.max_bytes` | `integer` | `524288` | Maximum bytes for syntax coloring; zero disables the limit |
| `map_view.syntax.max_captures` | `integer` | `30000` | Maximum Tree-sitter highlight captures read per rebuild; exceeding it makes the whole map use its base color; zero disables the limit |
| `map_view.syntax.max_time_ms` | `integer` | `100` | Soft limit for reading captures and building color ranges, excluding syntax-tree parsing and Braille rendering; timing out makes the whole map use its base color; zero disables the limit |
| `map_view.syntax.fallback` | `'mono'\|'scrollbar'` | `'mono'` | When `max_lines` or `max_bytes` is exceeded, keep a monochrome map or disable the map and show the classic scrollbar |
| `map_view.syntax.capture_map` | `table<string,string\|false>` | `{}` | Override full or root capture names; false uses the base map color |

Map content is cached by buffer and projection settings, so scrolling and dragging do not rescan
source code. Syntax colors follow the active Tree-sitter theme and include injected languages;
use `capture_map` to override colors or false to keep the base map color. Missing parsers or
highlight queries, excessive captures, and capture-processing timeouts also use the base color.

### Per-window control

Plugins and temporary windows can disable their own scrollbar:

```lua
vim.w[win].vv_scrollbar_disabled = true
```

Set it to `nil` or `false`, then run `:VVScrollbarRefresh` to restore it. `vv-git.nvim` disables the left baseline diff window and keeps the right worktree scrollbar.

To keep the scrollbar permanently visible as a marker track:

```lua
vim.w[win].vv_scrollbar_always_show = true
```

`vv-git.nvim` sets this for its right diff window so wrapping, folds, and diff filler do not make the track appear or disappear while scrolling.

## Marker configuration

| Option | Default | Source |
|---|---|---|
| `markers.diagnostics` | `true` | `vim.diagnostic.get()`; the highest severity wins on a projected row |
| `markers.git` | `true` | Staged and unstaged tracks from `diff_line_sets()`, including `vv-git` scratch buffers |
| `markers.search` | `true` | Matches for the current `/` register |
| `markers.marks` | `true` | Buffer-local and global letter marks |
| `markers.quickfix` | `true` | Quickfix and current-window loclist entries |
| `markers.cursor` | `true` | Active-window cursor row, spanning the whole scrollbar width |

When several markers project to one row, priority is cursor, diagnostics, Git, quickfix/loclist, marks, then search.

## Symbol configuration

| Option | Default | Description |
|---|---|---|
| `symbols.thumb` | `' '` | Repeated across the full scrollbar width |
| `symbols.cursor` | `'█'` | Repeated across the full scrollbar width |
| `symbols.search` | `'•'` | Search match |
| `symbols.mark` | `'◆'` | Vim mark |
| `symbols.quickfix` | `'■'` | Quickfix or loclist entry |
| `symbols.diagnostics` | Four severity mappings | Diagnostic marker characters |
| `symbols.git` | `{ A, C, D }` | Added, changed, and deleted markers |

Only the first character of each symbol is used. Markers other than thumb and cursor are not repeated horizontally.

## Highlight configuration

| Setting | Highlight group | Purpose |
|---|---|---|
| `highlights.track` | `VVScrollbarTrack` | Background track |
| `highlights.separator` | `VVScrollbarSeparator` | Separator between the file and scrollbar windows |
| `highlights.map_view` | `VVScrollbarMapView` | Monochrome code-map foreground |
| `highlights.map_cursor` | `VVScrollbarMapCursor` | Current-line Braille dots or slim line |
| `highlights.thumb` | `VVScrollbarThumb` | Visible range |
| `highlights.active` | `VVScrollbarActive` | Thumb while pressed or dragged |
| `highlights.cursor` | `VVScrollbarCursor` | Cursor position |
| `highlights.search` | `VVScrollbarSearch` | Search matches |
| `highlights.mark` | `VVScrollbarMark` | Vim marks |
| `highlights.quickfix` | `VVScrollbarQuickfix` | Quickfix and loclist |
| `highlights.diag_error` | `VVScrollbarDiagnosticError` | Error diagnostics |
| `highlights.diag_warn` | `VVScrollbarDiagnosticWarn` | Warning diagnostics |
| `highlights.diag_info` | `VVScrollbarDiagnosticInfo` | Info diagnostics |
| `highlights.diag_hint` | `VVScrollbarDiagnosticHint` | Hint diagnostics |

Git markers use `VVGitAdded`, `VVGitModified`, and `VVGitDeleted` from `vv-utils.git.register_hl()`. All highlights are registered again after `ColorScheme`.

Every `highlights` entry accepts a standard `vim.api.nvim_set_hl()` table. A plugin spec can
read the active theme palette and pass those colors directly:

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

A real split always reserves one `WinSeparator` cell. It cannot be zero-width. Using the editor
background for `separator` keeps that cell from looking like left padding inside the map. Removing
the cell entirely requires a floating window, which would cover the parent window's rightmost text

## Mouse interaction

| Action | Behavior |
|---|---|
| Click the track | Center the thumb on the click and jump immediately |
| Press the thumb | Keep the current position and immediately use the active color |
| Drag the thumb | Preserve the grab offset and update the viewport continuously |
| Hold near the map edge | Keep panning the frozen map viewport at the configured speed |
| Drag beyond the track | Snap to the beginning or end of the file |
| Release or press Esc | End dragging, resume source/map synchronization, and restore the thumb |

Jumping and dragging run through `vv-utils.scroll.with_auto_suppressed()`, so automatic jump animation cannot bounce from the target back to the old position before animating again.

## Commands

| Command | Description |
|---|---|
| `:VVScrollbarEnable` | Enable the scrollbar |
| `:VVScrollbarDisable` | Disable it and close every scrollbar window |
| `:VVScrollbarToggle` | Toggle the enabled state |
| `:VVScrollbarRefresh` | Reload Git markers for visible files and redraw immediately |

## Lua API

```lua
local scrollbar = require('vv-scrollbar')

scrollbar.setup({ width = 2 })
scrollbar.enable()
scrollbar.disable()
scrollbar.toggle()

local current_config = scrollbar.get_config()
```

`get_config()` returns a deep copy, so changing it does not mutate internal state.

## Module structure

```text
lua/vv-scrollbar/
├── core/        Geometry, runtime state, and refresh orchestration
├── features/    Git, markers, map renderer, and private cache
├── input/       Mouse press, drag, and release state machine
├── lifecycle/   Autocommand lifecycle
├── ui/          Split lifecycle, extmark rendering, and highlights
├── config.lua   Defaults and merging
└── init.lua     Public lifecycle API
```

## Testing

```bash
make test
```

Set `NVIM` to test with a specific Neovim executable, for example
`NVIM=nvim-nightly make test`.
