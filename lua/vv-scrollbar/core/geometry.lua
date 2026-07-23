local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')

local M = {}

---@param value number
---@param min number
---@param max number
---@return number
function M.clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

---@param list any[]?
---@param value any
---@return boolean
function M.list_has(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then return true end
  end
  return false
end

---@param win integer
---@return boolean
function M.win_has_winbar(win)
  local info = fn.getwininfo(win)[1]
  return info and info.winbar and info.winbar ~= 0 or false
end

---@param win integer
---@return integer
function M.win_height(win)
  local height = api.nvim_win_get_height(win)
  if M.win_has_winbar(win) then height = height - 1 end
  return math.max(height, 0)
end

---@param win integer
---@return boolean
function M.is_ordinary_window(win)
  local ok, win_config = pcall(api.nvim_win_get_config, win)
  return ok and (win_config.relative or '') == ''
end

---@param line integer
---@param line_count integer
---@param height integer
---@return integer
function M.line_to_row(line, line_count, height)
  if line_count <= 1 or height <= 1 then return 0 end
  local row = math.floor(((line - 1) / math.max(line_count - 1, 1)) * (height - 1) + 0.5)
  return M.clamp(row, 0, height - 1)
end

---@param win integer
---@return table
function M.viewport(win)
  local buf = api.nvim_win_get_buf(win)
  local line_count = api.nvim_buf_line_count(buf)
  local topline = fn.line('w0', win)
  local botline = fn.line('w$', win)
  local visible = math.max(botline - topline + 1, 1)
  local height = M.win_height(win)
  local thumb_height = math.floor(height * visible / math.max(line_count, 1) + 0.5)
  thumb_height = M.clamp(thumb_height, math.min(config.current().min_thumb, height), height)

  local max_row = math.max(height - thumb_height, 0)
  local max_top = math.max(line_count - visible, 1)
  local row = 0
  if max_row > 0 then
    row = math.floor(((topline - 1) / max_top) * max_row + 0.5)
  end

  return {
    buf = buf,
    line_count = line_count,
    topline = topline,
    botline = botline,
    visible = visible,
    height = height,
    thumb_row = M.clamp(row, 0, max_row),
    thumb_height = thumb_height,
    max_row = max_row,
    max_top = max_top,
  }
end

---@param win integer
---@param target integer
local function set_topline(win, target)
  if not api.nvim_win_is_valid(win) then return end

  api.nvim_win_call(win, function()
    local cursor = api.nvim_win_get_cursor(win)
    local initial_line = cursor[1]
    target = M.clamp(target, 1, api.nvim_buf_line_count(0))

    vim.cmd('keepjumps normal! ' .. target .. 'Gzt')
    if fn.line('w$') == fn.line('$') then
      vim.cmd('keepjumps normal! Gzb')
    end

    vim.cmd('keepjumps normal! H')
    local effective_top = fn.line('.')
    if initial_line < effective_top then return end

    vim.cmd('keepjumps normal! L')
    local effective_bottom = fn.line('.')
    if initial_line > effective_bottom then return end

    pcall(api.nvim_win_set_cursor, win, cursor)
  end)
end

---@param win integer
---@param row integer
function M.scroll_to_bar_row(win, row)
  if not api.nvim_win_is_valid(win) then return end

  local viewport = M.viewport(win)
  local target = 1
  if viewport.max_row > 0 then
    local ratio = M.clamp(row, 0, viewport.max_row) / viewport.max_row
    target = math.floor(ratio * viewport.max_top + 1.5)
  end

  require('vv-utils.scroll').with_auto_suppressed(win, function()
    set_topline(win, target)
  end)
end

---@param win integer
---@param line integer
---@param align 'center'|'top'
function M.scroll_to_line(win, line, align)
  if not api.nvim_win_is_valid(win) then return end

  local viewport = M.viewport(win)
  local target = line
  if align == 'center' then target = line - math.floor(viewport.visible / 2) end

  require('vv-utils.scroll').with_auto_suppressed(win, function()
    set_topline(win, target)
  end)
end

---@param win integer
---@return integer
local function parent_screen_top(win)
  local position = fn.win_screenpos(win)
  local row = position[1]
  if M.win_has_winbar(win) then row = row + 1 end
  return row
end

---@param win integer
---@param screenrow integer
---@return integer?
function M.screenrow_to_bar_row(win, screenrow)
  if not api.nvim_win_is_valid(win) then return nil end
  local row = screenrow - parent_screen_top(win)
  return M.clamp(row, 0, math.max(M.win_height(win) - 1, 0))
end

return M
