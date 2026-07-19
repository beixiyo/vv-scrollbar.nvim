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

- A full-height background track and a thumb sized from the visible-content ratio
- Click the track to jump, or drag the thumb while preserving the original grab offset
- A normal click does not show the drag color; hover styling starts only after movement
- Integration with `vv-utils.scroll` prevents automatic smooth scrolling from pulling interactions back to an old view
- A real split reserves width, so the scrollbar never covers text at the end of a parent-window line
- Configurable width with track and thumb filling the available cells; the default is two cells
- Neovim keeps one separator cell between the parent window and scrollbar split
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
    track = { bg = '#20242b' }, thumb = { bg = '#3b4252' },
    hover = { bg = '#4b5568' }, cursor = { fg = '#7aa2f7' },
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
| `highlights.thumb` | `VVScrollbarThumb` | Visible range |
| `highlights.hover` | `VVScrollbarHover` | Thumb during an actual drag |
| `highlights.cursor` | `VVScrollbarCursor` | Cursor position |
| `highlights.search` | `VVScrollbarSearch` | Search matches |
| `highlights.mark` | `VVScrollbarMark` | Vim marks |
| `highlights.quickfix` | `VVScrollbarQuickfix` | Quickfix and loclist |
| `highlights.diag_error` | `VVScrollbarDiagnosticError` | Error diagnostics |
| `highlights.diag_warn` | `VVScrollbarDiagnosticWarn` | Warning diagnostics |
| `highlights.diag_info` | `VVScrollbarDiagnosticInfo` | Info diagnostics |
| `highlights.diag_hint` | `VVScrollbarDiagnosticHint` | Hint diagnostics |

Git markers use `VVGitAdded`, `VVGitModified`, and `VVGitDeleted` from `vv-utils.git.register_hl()`. All highlights are registered again after `ColorScheme`.

## Mouse interaction

| Action | Behavior |
|---|---|
| Click the track | Center the thumb on the click and jump immediately |
| Press the thumb | Keep the current position without changing to the hover color |
| Drag the thumb | Preserve the grab offset and update the viewport continuously |
| Drag beyond the track | Snap to the beginning or end of the file |
| Release | End dragging and restore the normal thumb highlight |

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
├── core/        Geometry, runtime state, and floating-window rendering
├── features/    Git data and marker collection
├── input/       Mouse press, drag, and release state machine
├── lifecycle/   Autocommand lifecycle
├── ui/          Highlight registration
├── config.lua   Defaults and merging
└── init.lua     Public lifecycle API
```

## Testing

```bash
nvim --headless -u NONE -l tests/test_smoke.lua
```
