-- 滚动条分屏窗口生命周期与父窗口 separator 状态管理

local api = vim.api

local config = require('vv-scrollbar.config')
local map_view = require('vv-scrollbar.features.map_view')

local M = {}

---@param value string
---@param source string
---@return boolean
---@return string?
local function winhighlight_target(value, source)
  for entry in value:gmatch('[^,]+') do
    local from, to = entry:match('^([^:]+):(.+)$')
    if from == source then return true, to end
  end
  return false
end

---@param value string
---@param source string
---@param target? string
---@return string
local function replace_winhighlight(value, source, target)
  local entries = {}
  local replaced = false

  for entry in value:gmatch('[^,]+') do
    local from = entry:match('^([^:]+):')
    if from == source then
      if target and not replaced then
        entries[#entries + 1] = source .. ':' .. target
      end
      replaced = true
    else
      entries[#entries + 1] = entry
    end
  end

  if target and not replaced then entries[#entries + 1] = source .. ':' .. target end
  return table.concat(entries, ',')
end

---@param parent integer
---@param bar VVScrollbarBar
local function apply_separator_highlight(parent, bar)
  if not api.nvim_win_is_valid(parent) then return end

  local value = api.nvim_get_option_value('winhighlight', { win = parent })
  local present, target = winhighlight_target(value, 'WinSeparator')
  if not present or target ~= 'VVScrollbarSeparator' then
    bar.parent_separator_hl = { present = present, target = target }
  end

  api.nvim_set_option_value(
    'winhighlight',
    replace_winhighlight(value, 'WinSeparator', 'VVScrollbarSeparator'),
    { win = parent, scope = 'local' }
  )
end

---@param bar VVScrollbarBar
local function restore_separator_highlight(bar)
  local saved = bar.parent_separator_hl
  local parent = bar.parent
  if not saved or not api.nvim_win_is_valid(parent) then return end

  local value = api.nvim_get_option_value('winhighlight', { win = parent })
  local present, target = winhighlight_target(value, 'WinSeparator')
  if present and target == 'VVScrollbarSeparator' then
    api.nvim_set_option_value(
      'winhighlight',
      replace_winhighlight(value, 'WinSeparator', saved.present and saved.target or nil),
      { win = parent, scope = 'local' }
    )
  end

  bar.parent_separator_hl = nil
end

---@param parent integer
---@return VVScrollbarBar
function M.create(parent)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'vv-scrollbar'
  vim.bo[buf].undolevels = -1

  return {
    win = -1,
    buf = buf,
    parent = parent,
    thumb_row = 0,
    thumb_height = 1,
    height = 1,
    width = 0,
    track_width = 0,
  }
end

---@param bar VVScrollbarBar
function M.close(bar)
  if bar.win and api.nvim_win_is_valid(bar.win) then
    pcall(api.nvim_win_close, bar.win, true)
  end
  restore_separator_highlight(bar)
  if bar.buf and api.nvim_buf_is_valid(bar.buf) then
    pcall(api.nvim_buf_delete, bar.buf, { force = true })
  end
end

---@param parent integer
---@param bar VVScrollbarBar
---@param has_map_view boolean
function M.sync(parent, bar, has_map_view)
  local cfg = config.current()
  local available_width = math.max(api.nvim_win_get_width(parent) - 1, 1)
  local desired_width = has_map_view and map_view.resolve_width(parent, bar) or cfg.width
  local track_width = math.min(desired_width, available_width)
  local width = math.min(track_width + cfg.right_offset, available_width)

  if not (bar.win and api.nvim_win_is_valid(bar.win)) then
    bar.win = api.nvim_open_win(bar.buf, false, {
      win = parent,
      split = 'right',
      style = 'minimal',
      noautocmd = true,
      width = width,
    })
    require('vv-utils.ui_window').hide_chrome(bar.win)
  else
    api.nvim_win_set_width(bar.win, width)
  end

  apply_separator_highlight(parent, bar)
  vim.wo[bar.win].winfixbuf = true
  vim.wo[bar.win].winfixwidth = true
  vim.wo[bar.win].wrap = false
  vim.wo[bar.win].statusline = ' '
  bar.track_width = math.min(track_width, api.nvim_win_get_width(bar.win))

  api.nvim_set_option_value(
    'winhighlight',
    'Normal:VVScrollbarTrack,NormalFloat:VVScrollbarTrack,EndOfBuffer:VVScrollbarTrack',
    { win = bar.win, scope = 'local' }
  )
end

return M
