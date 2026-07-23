local fn = vim.fn

local config = require('vv-scrollbar.config')
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

---@param current? { priority: integer, source_line?: integer }
---@param priority integer
---@param source_line integer
---@return boolean
local function should_replace(current, priority, source_line)
  if not current then return true end
  if priority ~= current.priority then return priority > current.priority end
  return current.source_line == nil or source_line < current.source_line
end

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
---@param source_line integer
local function add_marker(markers, row, text, hl, priority, source_line)
  if row == nil or not text or text == '' then return end
  local current = markers[row]
  if not should_replace(current, priority, source_line) then return end
  markers[row] = {
    text = M.cell(text),
    hl = hl,
    priority = priority,
    source_line = source_line,
  }
end

---@param markers table
---@param viewport table
---@param line_to_row fun(line: integer): integer?
local function add_diagnostics(markers, viewport, line_to_row)
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

  for line, severity in pairs(by_line) do
    add_marker(
      markers,
      line_to_row(line),
      cfg.symbols.diagnostics[severity],
      diag_hl[severity],
      PRIORITY.diagnostic - severity,
      line
    )
  end
end

---@param markers table
---@param viewport table
---@param track_width integer
---@param line_to_row fun(line: integer): integer?
local function add_git(markers, viewport, track_width, line_to_row)
  local cfg = config.current()
  if not cfg.markers.git then return end

  local sets = state.git_marks[viewport.buf] or {}
  local rows = {}
  for channel, line_markers in pairs(sets) do
    for line, kind in pairs(line_markers) do
      local row = line_to_row(line)
      if row ~= nil then
        rows[row] = rows[row] or {}
        local current = rows[row][channel]
        local priority = kind == 'D' and PRIORITY.git_delete or PRIORITY.git
        if should_replace(current, priority, line) then
          rows[row][channel] = { kind = kind, priority = priority, source_line = line }
        end
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
        hits = hits,
      }
    end
  end
end

---@param markers table
---@param viewport table
---@param line_to_row fun(line: integer): integer?
local function add_search(markers, viewport, line_to_row)
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
        line_to_row(match.lnum),
        cfg.symbols.search,
        'VVScrollbarSearch',
        PRIORITY.search,
        match.lnum
      )
    end
  end
end

---@param markers table
---@param viewport table
---@param line_to_row fun(line: integer): integer?
local function add_marks(markers, viewport, line_to_row)
  local cfg = config.current()
  if not cfg.markers.marks then return end

  for _, list in ipairs({ fn.getmarklist(viewport.buf), fn.getmarklist() }) do
    for _, mark in ipairs(list) do
      if mark.pos and mark.pos[1] == viewport.buf and mark.mark and mark.mark:match("^'[a-zA-Z]$") then
        local line = mark.pos[2]
        if line and line > 0 then
          add_marker(
            markers,
            line_to_row(line),
            cfg.symbols.mark,
            'VVScrollbarMark',
            PRIORITY.mark,
            line
          )
        end
      end
    end
  end
end

---@param win integer
---@param markers table
---@param viewport table
---@param line_to_row fun(line: integer): integer?
local function add_quickfix(win, markers, viewport, line_to_row)
  local cfg = config.current()
  if not cfg.markers.quickfix then return end

  local function add_items(items)
    for _, item in ipairs(items or {}) do
      if item.bufnr == viewport.buf and item.lnum and item.lnum > 0 then
        add_marker(
          markers,
          line_to_row(item.lnum),
          cfg.symbols.quickfix,
          'VVScrollbarQuickfix',
          PRIORITY.quickfix,
          item.lnum
        )
      end
    end
  end

  add_items(fn.getqflist())
  add_items(fn.getloclist(win))
end

---@param win integer
---@param viewport table
---@param opts {
---  track_width?: integer,
---  line_to_row: fun(line: integer): integer?,
---}
---@return table
function M.collect(win, viewport, opts)
  assert(
    type(opts) == 'table' and type(opts.line_to_row) == 'function',
    'vv-scrollbar: marker projection is required'
  )
  local markers = {}
  local function visible_row(line)
    local row = opts.line_to_row(line)
    if row == nil or row < 0 or row >= viewport.height then return nil end
    return row
  end

  add_diagnostics(markers, viewport, visible_row)
  add_git(markers, viewport, opts.track_width or config.current().width, visible_row)
  add_search(markers, viewport, visible_row)
  add_marks(markers, viewport, visible_row)
  add_quickfix(win, markers, viewport, visible_row)
  return markers
end

return M
