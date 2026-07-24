local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local projection = require('vv-scrollbar.core.projection')

local M = {}

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

---@param win integer
---@param display_row integer
---@return integer
local function display_row_to_line(win, display_row)
  local line_count = api.nvim_buf_line_count(api.nvim_win_get_buf(win))
  local height = api.nvim_win_text_height(win, {
    max_height = math.max(math.floor(display_row), 0) + 1,
  })
  return projection.clamp(height.end_row + 1, 1, line_count)
end

---@param win integer
---@return table
function M.viewport(win)
  local buf = api.nvim_win_get_buf(win)
  local line_count = api.nvim_buf_line_count(buf)
  local view = api.nvim_win_call(win, fn.winsaveview)
  local topline = view.topline
  local botline = fn.line('w$', win)
  local visible = math.max(botline - topline + 1, 1)
  local height = M.win_height(win)
  local display_height = math.max(api.nvim_win_text_height(win, {}).all, 1)
  local page_height = math.min(height, display_height)
  local top_height = api.nvim_win_text_height(win, {
    end_row = topline - 1,
    end_vcol = view.skipcol,
  }).all
  local display_top = math.max(top_height - view.topfill, 0)
  local thumb_height =
    math.floor(height * page_height / display_height + 0.5)
  thumb_height = projection.clamp(
    thumb_height,
    math.min(config.current().min_thumb, height),
    height
  )

  local max_row = math.max(height - thumb_height, 0)
  local max_top = math.max(display_height - page_height, 1)
  local row = 0
  if max_row > 0 then
    row = math.floor((display_top / max_top) * max_row + 0.5)
  end

  return {
    buf = buf,
    line_count = line_count,
    display_height = display_height,
    display_top = display_top,
    topline = topline,
    botline = botline,
    visible = visible,
    height = height,
    thumb_row = projection.clamp(row, 0, max_row),
    thumb_height = thumb_height,
    max_row = max_row,
    max_top = max_top,
  }
end

---@param win integer
---@param row integer
---@return integer
function M.bar_row_to_line(win, row)
  local viewport = M.viewport(win)
  local display_row =
    projection.row_to_line(row, viewport.display_height, viewport.height) - 1
  return display_row_to_line(win, display_row)
end

---@param win integer
---@param target integer
---@param cursor_anchor? VVScrollbarCursorAnchor
---@param preferred_cursor_line? integer
local function set_topline(win, target, cursor_anchor, preferred_cursor_line)
  if not api.nvim_win_is_valid(win) then return end

  api.nvim_win_call(win, function()
    local cursor = api.nvim_win_get_cursor(win)
    local initial_line = cursor[1]
    local line_count = api.nvim_buf_line_count(0)
    target = projection.clamp(target, 1, line_count)

    if cursor_anchor then
      if preferred_cursor_line then
        local cursor_line = projection.clamp(preferred_cursor_line, 1, line_count)
        vim.cmd('keepjumps normal! ' .. cursor_line .. 'Gzz')
      else
        vim.cmd('keepjumps normal! ' .. target .. 'Gzt')
        if fn.line('w$') == fn.line('$') then
          vim.cmd('keepjumps normal! Gzb')
        end

        local screen_row = projection.clamp(
          cursor_anchor.screen_row,
          1,
          math.max(M.win_height(win), 1)
        )
        vim.cmd('keepjumps normal! ' .. screen_row .. 'H')
      end

      cursor_anchor.screen_row = fn.winline()
      fn.winrestview({ curswant = cursor_anchor.curswant })
      return
    end

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
---@return VVScrollbarCursorAnchor?
function M.begin_cursor_follow(win)
  if not api.nvim_win_is_valid(win) then return nil end

  local anchor
  api.nvim_win_call(win, function()
    local view = fn.winsaveview()

    anchor = {
      screen_row = fn.winline(),
      curswant = view.curswant,
      scrolloff = vim.wo[win].scrolloff,
    }
    vim.wo[win].scrolloff = 0
  end)
  return anchor
end

---@param win integer
---@param cursor_anchor? VVScrollbarCursorAnchor
function M.end_cursor_follow(win, cursor_anchor)
  if not cursor_anchor or not api.nvim_win_is_valid(win) then return end
  vim.wo[win].scrolloff = cursor_anchor.scrolloff
end

---@param win integer
---@param row integer
---@param cursor_anchor? VVScrollbarCursorAnchor
function M.scroll_to_bar_row(win, row, cursor_anchor)
  if not api.nvim_win_is_valid(win) then return end

  local viewport = M.viewport(win)
  local target = 1
  if viewport.max_row > 0 then
    local ratio = projection.clamp(row, 0, viewport.max_row) / viewport.max_row
    local display_row = math.floor(ratio * viewport.max_top + 0.5)
    target = display_row_to_line(win, display_row)
  end

  require('vv-utils.scroll').with_auto_suppressed(win, function()
    set_topline(win, target, cursor_anchor)
  end)
end

---@param win integer
---@param line integer
---@param align 'center'|'top'
---@param cursor_anchor? VVScrollbarCursorAnchor
---@param preferred_cursor_line? integer
function M.scroll_to_line(win, line, align, cursor_anchor, preferred_cursor_line)
  if not api.nvim_win_is_valid(win) then return end

  local viewport = M.viewport(win)
  local target = line
  if align == 'center' then target = line - math.floor(viewport.visible / 2) end

  require('vv-utils.scroll').with_auto_suppressed(win, function()
    set_topline(win, target, cursor_anchor, preferred_cursor_line)
  end)
end

---@param win integer
---@param line integer
function M.set_cursor_line(win, line)
  if not api.nvim_win_is_valid(win) then return end

  local line_count = api.nvim_buf_line_count(api.nvim_win_get_buf(win))
  local target = projection.clamp(line, 1, line_count)

  require('vv-utils.scroll').with_auto_suppressed(win, function()
    pcall(api.nvim_win_set_cursor, win, { target, 0 })
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
function M.screenrow_to_bar_row_raw(win, screenrow)
  if not api.nvim_win_is_valid(win) then return nil end
  return screenrow - parent_screen_top(win)
end

---@param win integer
---@param screenrow integer
---@return integer?
function M.screenrow_to_bar_row(win, screenrow)
  local row = M.screenrow_to_bar_row_raw(win, screenrow)
  if row == nil then return nil end
  return projection.clamp(row, 0, math.max(M.win_height(win) - 1, 0))
end

return M
