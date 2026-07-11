local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local state = require('vv-scrollbar.core.state')

local M = {}

local SEV = vim.diagnostic.severity

local diag_hl = {
  [SEV.ERROR] = 'VVScrollbarDiagnosticError',
  [SEV.WARN] = 'VVScrollbarDiagnosticWarn',
  [SEV.INFO] = 'VVScrollbarDiagnosticInfo',
  [SEV.HINT] = 'VVScrollbarDiagnosticHint',
}

local git_hl = {
  A = 'VVGitAdded',
  C = 'VVGitModified',
  D = 'VVGitDeleted',
}

---@param text string?
---@return string
function M.cell(text)
  text = text or ' '
  if text == '' then return ' ' end
  return fn.strcharpart(text, 0, 1)
end

---@param markers table
---@param row integer?
---@param text string?
---@param hl string
---@param priority integer
---@param fill_width? boolean
local function add_marker(markers, row, text, hl, priority, fill_width)
  if row == nil or not text or text == '' then return end
  local current = markers[row]
  if current and current.priority > priority then return end
  markers[row] = {
    text = M.cell(text),
    hl = hl,
    priority = priority,
    fill_width = fill_width or false,
  }
end

---@param markers table
---@param viewport table
local function add_diagnostics(markers, viewport)
  local cfg = config.current()
  if not cfg.markers.diagnostics then return end

  local by_line = {}
  for _, diagnostic in ipairs(vim.diagnostic.get(viewport.buf)) do
    if diagnostic.lnum then
      local line = diagnostic.lnum + 1
      local severity = diagnostic.severity or SEV.INFO
      local current = by_line[line]
      if not current or severity < current then by_line[line] = severity end
    end
  end

  local diagnostics = require('vv-utils.diagnostics')
  for line, severity in pairs(by_line) do
    local symbol = diagnostics.symbol_for({ [severity] = 1 })
    add_marker(
      markers,
      geometry.line_to_row(line, viewport.line_count, viewport.height),
      cfg.symbols.diagnostics[severity],
      symbol and symbol.hl or diag_hl[severity],
      80 - severity
    )
  end
end

---@param markers table
---@param viewport table
local function add_git(markers, viewport)
  local cfg = config.current()
  if not cfg.markers.git then return end

  local sets = state.git_marks[viewport.buf] or {}
  local rows = {}
  for channel, line_markers in pairs(sets) do
    for line, kind in pairs(line_markers) do
      local row = geometry.line_to_row(line, viewport.line_count, viewport.height)
      rows[row] = rows[row] or {}
      local current = rows[row][channel]
      local priority = kind == 'D' and 70 or 65
      if not current or priority > current.priority then
        rows[row][channel] = { kind = kind, priority = priority }
      end
    end
  end

  for row, channels in pairs(rows) do
    local chunks = {}
    local priority = 65
    local channel_names = cfg.width >= 2 and { 'staged', 'unstaged' } or { 'merged' }
    for _, channel in ipairs(channel_names) do
      local marker = channel == 'merged'
        and (channels.unstaged or channels.staged)
        or channels[channel]
      if marker then
        chunks[#chunks + 1] = { M.cell(cfg.symbols.git[marker.kind]), git_hl[marker.kind] }
        priority = math.max(priority, marker.priority)
      else
        chunks[#chunks + 1] = { ' ', 'VVScrollbarTrack' }
      end
    end

    local current = markers[row]
    if not current or current.priority <= priority then
      markers[row] = { chunks = chunks, priority = priority }
    end
  end
end

---@param markers table
---@param viewport table
local function add_search(markers, viewport)
  local cfg = config.current()
  if not cfg.markers.search or viewport.line_count > cfg.search_line_limit then return end

  local pattern = fn.getreg('/')
  if not pattern or pattern == '' then return end

  local ok, matches = pcall(fn.matchbufline, viewport.buf, pattern, 1, '$')
  if not ok or type(matches) ~= 'table' then return end

  local seen = {}
  for _, match in ipairs(matches) do
    if match.lnum and not seen[match.lnum] then
      seen[match.lnum] = true
      add_marker(
        markers,
        geometry.line_to_row(match.lnum, viewport.line_count, viewport.height),
        cfg.symbols.search,
        'VVScrollbarSearch',
        45
      )
    end
  end
end

---@param markers table
---@param viewport table
local function add_marks(markers, viewport)
  local cfg = config.current()
  if not cfg.markers.marks then return end

  for _, list in ipairs({ fn.getmarklist(viewport.buf), fn.getmarklist() }) do
    for _, mark in ipairs(list) do
      if mark.pos and mark.pos[1] == viewport.buf and mark.mark and mark.mark:match("^'[a-zA-Z]$") then
        local line = mark.pos[2]
        if line and line > 0 then
          add_marker(
            markers,
            geometry.line_to_row(line, viewport.line_count, viewport.height),
            cfg.symbols.mark,
            'VVScrollbarMark',
            50
          )
        end
      end
    end
  end
end

---@param win integer
---@param markers table
---@param viewport table
local function add_quickfix(win, markers, viewport)
  local cfg = config.current()
  if not cfg.markers.quickfix then return end

  local function add_items(items)
    for _, item in ipairs(items or {}) do
      if item.bufnr == viewport.buf and item.lnum and item.lnum > 0 then
        add_marker(
          markers,
          geometry.line_to_row(item.lnum, viewport.line_count, viewport.height),
          cfg.symbols.quickfix,
          'VVScrollbarQuickfix',
          55
        )
      end
    end
  end

  add_items(fn.getqflist())
  add_items(fn.getloclist(win))
end

---@param win integer
---@param markers table
---@param viewport table
local function add_cursor(win, markers, viewport)
  local cfg = config.current()
  if not cfg.markers.cursor or win ~= api.nvim_get_current_win() then return end

  local cursor = api.nvim_win_get_cursor(win)
  add_marker(
    markers,
    geometry.line_to_row(cursor[1], viewport.line_count, viewport.height),
    cfg.symbols.cursor,
    'VVScrollbarCursor',
    90,
    true
  )
end

---@param win integer
---@param viewport table
---@return table
function M.collect(win, viewport)
  local markers = {}
  add_diagnostics(markers, viewport)
  add_git(markers, viewport)
  add_search(markers, viewport)
  add_marks(markers, viewport)
  add_quickfix(win, markers, viewport)
  add_cursor(win, markers, viewport)
  return markers
end

return M
