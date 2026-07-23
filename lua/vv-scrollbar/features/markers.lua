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

local PRIORITY = {
  search = 45,
  mark = 50,
  quickfix = 55,
  git = 65,
  git_delete = 70,
  diagnostic = 80,
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
---@param opts? { fill_width?: boolean, source_line?: integer, kind?: string }
local function add_marker(markers, row, text, hl, priority, opts)
  if row == nil or not text or text == '' then return end
  local current = markers[row]
  if current and current.priority > priority then return end
  opts = opts or {}
  markers[row] = {
    text = M.cell(text),
    hl = hl,
    priority = priority,
    fill_width = opts.fill_width or false,
    source_line = opts.source_line,
    kind = opts.kind,
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
      PRIORITY.diagnostic - severity,
      { source_line = line, kind = 'diagnostic' }
    )
  end
end

---@param markers table
---@param viewport table
---@param track_width integer
local function add_git(markers, viewport, track_width)
  local cfg = config.current()
  if not cfg.markers.git then return end

  local sets = state.git_marks[viewport.buf] or {}
  local rows = {}
  for channel, line_markers in pairs(sets) do
    for line, kind in pairs(line_markers) do
      local row = geometry.line_to_row(line, viewport.line_count, viewport.height)
      rows[row] = rows[row] or {}
      local current = rows[row][channel]
      local priority = kind == 'D' and PRIORITY.git_delete or PRIORITY.git
      if not current or priority > current.priority then
        rows[row][channel] = { kind = kind, priority = priority, source_line = line }
      end
    end
  end

  for row, channels in pairs(rows) do
    local chunks = {}
    local hits = {}
    local chunk_width = 0
    local priority = PRIORITY.git
    local channel_names = track_width >= 2 and { 'staged', 'unstaged' } or { 'merged' }
    for _, channel in ipairs(channel_names) do
      local marker = channel == 'merged'
        and (channels.unstaged or channels.staged)
        or channels[channel]
      if marker then
        local text = M.cell(cfg.symbols.git[marker.kind])
        local width = fn.strdisplaywidth(text)
        chunks[#chunks + 1] = { text, git_hl[marker.kind] }
        hits[#hits + 1] = {
          start_col = chunk_width,
          end_col = chunk_width + width,
          source_line = marker.source_line,
        }
        chunk_width = chunk_width + width
        priority = math.max(priority, marker.priority)
      else
        chunks[#chunks + 1] = { ' ', 'VVScrollbarTrack' }
        chunk_width = chunk_width + 1
      end
    end

    local current = markers[row]
    if not current or current.priority <= priority then
      markers[row] = {
        chunks = chunks,
        priority = priority,
        kind = 'git',
        hits = hits,
      }
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
        PRIORITY.search,
        { source_line = match.lnum, kind = 'search' }
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
            PRIORITY.mark,
            { source_line = line, kind = 'mark' }
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
          PRIORITY.quickfix,
          { source_line = item.lnum, kind = 'quickfix' }
        )
      end
    end
  end

  add_items(fn.getqflist())
  add_items(fn.getloclist(win))
end

---@param win integer
---@param viewport table
---@param opts? { track_width?: integer }
---@return table
function M.collect(win, viewport, opts)
  opts = opts or {}
  local markers = {}
  add_diagnostics(markers, viewport)
  add_git(markers, viewport, opts.track_width or config.current().width)
  add_search(markers, viewport)
  add_marks(markers, viewport)
  add_quickfix(win, markers, viewport)
  return markers
end

return M
