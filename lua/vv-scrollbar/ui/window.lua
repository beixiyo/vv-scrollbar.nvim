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
---@param bar VVScrollbar.Bar
---@param expected_separator? { present: boolean, target?: string }
function M.apply_separator_highlight(parent, bar, expected_separator)
  if not api.nvim_win_is_valid(parent) then return end

  local value = api.nvim_get_option_value('winhighlight', { win = parent })
  local present, target = winhighlight_target(value, 'WinSeparator')
  if expected_separator
      and (present ~= expected_separator.present or target ~= expected_separator.target)
  then
    return
  end
  if not present or target ~= 'VVScrollbarSeparator' then
    bar.parent_separator_hl = { present = present, target = target }
  end

  api.nvim_set_option_value(
    'winhighlight',
    replace_winhighlight(value, 'WinSeparator', 'VVScrollbarSeparator'),
    { win = parent, scope = 'local' }
  )
end

---@param bar VVScrollbar.Bar
---@return { present: boolean, target?: string }? restored_separator
function M.restore_separator_highlight(bar)
  local saved = bar.parent_separator_hl
  bar.parent_separator_hl = nil
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
    return saved
  end
end

---@param parent integer
---@return VVScrollbar.Bar
function M.create(parent)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'vv-scrollbar'
  vim.bo[buf].undolevels = -1

  require('vv-utils.mouse').block_visual_drag(buf)

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

---@param parent integer
---@param bar VVScrollbar.Bar
---@return boolean
function M.is_attached(parent, bar)
  if not api.nvim_win_is_valid(parent)
      or not bar.win
      or not api.nvim_win_is_valid(bar.win)
  then
    return false
  end

  local parent_position = vim.fn.win_screenpos(parent)
  local bar_position = vim.fn.win_screenpos(bar.win)
  local expected_col = parent_position[2] + api.nvim_win_get_width(parent) + 1

  return bar_position[1] == parent_position[1]
    and bar_position[2] == expected_col
    and api.nvim_win_get_height(bar.win) == api.nvim_win_get_height(parent)
end

-- sync 与 style = 'minimal' 写在滚动条窗口上的 window-local 选项
local OWNED_OPTIONS = {
  'winfixbuf', 'winfixwidth', 'wrap', 'statusline', 'winhighlight',
  'number', 'relativenumber', 'cursorline', 'cursorcolumn', 'foldcolumn',
  'spell', 'list', 'signcolumn', 'colorcolumn', 'statuscolumn',
}

---记录父窗口的窗口选项默认值，供 release_to_editor 使用
---必须在建滚动条窗口时取：需要还原时父窗口已经不存在，而滚动条窗口自己的默认值早被改写
---@param parent integer
---@return table<string, any>
local function capture_editor_options(parent)
  local options = {}
  for _, name in ipairs(OWNED_OPTIONS) do
    local ok, value = pcall(api.nvim_get_option_value, name, { scope = 'global', win = parent })
    if ok then options[name] = value end
  end
  return options
end

---把滚动条窗口还原成普通编辑窗口
---@param win integer
---@param options table<string, any>?
local function release_to_editor(win, options)
  -- 'minimal' 样式是窗口配置的一部分，每次换 buffer 都会被重新套用，必须先清掉
  pcall(api.nvim_win_set_config, win, { style = '' })
  -- 两个作用域都要写：局部值管当前 buffer，窗口自己的默认值管之后换进来的 buffer
  for name, value in pairs(options or {}) do
    pcall(api.nvim_set_option_value, name, value, { win = win, scope = 'local' })
    pcall(api.nvim_set_option_value, name, value, { win = win, scope = 'global' })
  end
end

---@param bar VVScrollbar.Bar
function M.close(bar)
  local win = bar.win
  if win and api.nvim_win_is_valid(win) then
    pcall(api.nvim_win_close, win, true)
  end
  M.restore_separator_highlight(bar)

  -- 关不掉说明它成了最后一个普通窗口：父窗口先被关闭（如 `:bdelete` 当前 buffer 时
  -- Neovim 会关掉显示它的窗口）。接下来删掉滚动条 buffer，Neovim 会把别的 buffer 换进这个窗口
  -- 所以先把它还原成普通编辑窗口，否则用户的文件会显示在没有行号、锁定 buffer 的窗口里
  if win and api.nvim_win_is_valid(win) then release_to_editor(win, bar.editor_options) end
  if bar.buf and api.nvim_buf_is_valid(bar.buf) then
    pcall(api.nvim_buf_delete, bar.buf, { force = true })
  end
end

---@param parent integer
---@param bar VVScrollbar.Bar
---@param has_map_view boolean
function M.sync(parent, bar, has_map_view)
  local cfg = config.current()
  local available_width = math.max(api.nvim_win_get_width(parent) - 1, 1)
  local desired_width = has_map_view and map_view.resolve_width(parent, bar) or cfg.width
  local track_width = math.min(desired_width, available_width)
  local width = math.min(track_width + cfg.right_offset, available_width)

  if not (bar.win and api.nvim_win_is_valid(bar.win)) then
    bar.editor_options = capture_editor_options(parent)
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

  M.apply_separator_highlight(parent, bar)
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
