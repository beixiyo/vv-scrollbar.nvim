local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local state = require('vv-scrollbar.core.state')
local markers = require('vv-scrollbar.features.markers')

local M = {}

local ns = api.nvim_create_namespace('vv-scrollbar')
local retry_pending = false

local function retry_refresh()
  if retry_pending then return end
  retry_pending = true

  vim.defer_fn(function()
    retry_pending = false
    M.refresh()
  end, 20)
end

---@param win integer
---@return boolean
local function should_show(win)
  local cfg = config.current()
  if not api.nvim_win_is_valid(win) or not geometry.is_ordinary_window(win) then return false end
  if cfg.current_only and win ~= api.nvim_get_current_win() then return false end
  if vim.w[win].vv_scrollbar_disabled then return false end

  local buf = api.nvim_win_get_buf(win)
  if cfg.window_filter then
    local ok, visible = pcall(cfg.window_filter, win, buf)
    if not ok then
      vim.notify_once(
        'vv-scrollbar: window_filter failed: ' .. tostring(visible),
        vim.log.levels.ERROR
      )
      return false
    end
    if visible == false then return false end
  end
  if geometry.list_has(cfg.excluded_filetypes, vim.bo[buf].filetype) then return false end
  if geometry.list_has(cfg.excluded_buftypes, vim.bo[buf].buftype) then return false end
  if vim.wo[win].winfixbuf then return false end
  if geometry.win_height(win) <= 0 or api.nvim_win_get_width(win) <= 0 then return false end

  if vim.w[win].vv_scrollbar_always_show then return true end

  local line_count = api.nvim_buf_line_count(buf)
  local topline = fn.line('w0', win)
  local botline = fn.line('w$', win)
  return line_count > 0 and botline - topline + 1 < line_count
end

---@param parent integer
---@return VVScrollbarBar
local function create_bar(parent)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'vv-scrollbar'
  vim.bo[buf].undolevels = -1

  local bar = {
    win = -1,
    buf = buf,
    parent = parent,
    thumb_row = 0,
    thumb_height = 1,
    height = 1,
    width = 0,
  }

  state.bars[parent] = bar
  return bar
end

---@param parent integer
function M.close(parent)
  local bar = state.bars[parent]
  if not bar then return end

  if bar.win and api.nvim_win_is_valid(bar.win) then
    pcall(api.nvim_win_close, bar.win, true)
  end
  if bar.buf and api.nvim_buf_is_valid(bar.buf) then
    pcall(api.nvim_buf_delete, bar.buf, { force = true })
  end
  state.bars[parent] = nil
end

---@param parent integer
---@param bar VVScrollbarBar
---@param height integer
local function sync_window(parent, bar, height)
  local cfg = config.current()
  local available_width = math.max(api.nvim_win_get_width(parent) - cfg.right_offset, 1)
  local width = math.min(cfg.width, available_width)
  local col = math.max(api.nvim_win_get_width(parent) - width - cfg.right_offset, 0)
  local win_config = {
    win = parent,
    relative = 'win',
    style = 'minimal',
    border = 'none',
    focusable = false,
    mouse = true,
    zindex = cfg.zindex,
    width = width,
    height = height,
    row = 0,
    col = col,
  }

  if not (bar.win and api.nvim_win_is_valid(bar.win)) then
    local create_config = vim.tbl_extend('force', win_config, { noautocmd = true })
    bar.win = api.nvim_open_win(bar.buf, false, create_config)
    require('vv-utils.ui_window').hide_chrome(bar.win)
  else
    api.nvim_win_set_config(bar.win, win_config)
  end

  api.nvim_set_option_value('winblend', cfg.winblend, { win = bar.win, scope = 'local' })
  api.nvim_set_option_value(
    'winhighlight',
    'Normal:VVScrollbarTrack,NormalFloat:VVScrollbarTrack,EndOfBuffer:VVScrollbarTrack',
    { win = bar.win, scope = 'local' }
  )
end

---@param bar VVScrollbarBar
---@param height integer
---@param width integer
local function ensure_lines(bar, height, width)
  if api.nvim_buf_line_count(bar.buf) == height and bar.width == width then return end

  local lines = {}
  local fill = string.rep(' ', width)
  for index = 1, height do lines[index] = fill end

  vim.bo[bar.buf].modifiable = true
  api.nvim_buf_set_lines(bar.buf, 0, -1, false, lines)
  vim.bo[bar.buf].modifiable = false
  bar.width = width
end

---@param parent integer
local function render(parent)
  local viewport = geometry.viewport(parent)
  local bar = state.bars[parent] or create_bar(parent)
  local cfg = config.current()

  bar.parent = parent
  bar.height = viewport.height
  bar.thumb_row = viewport.thumb_row
  bar.thumb_height = viewport.thumb_height

  sync_window(parent, bar, viewport.height)
  local width = api.nvim_win_get_width(bar.win)
  ensure_lines(bar, viewport.height, width)
  api.nvim_buf_clear_namespace(bar.buf, ns, 0, -1)

  local row_markers = markers.collect(parent, viewport)
  local dragging = state.dragging
    and state.dragging.parent == parent
    and state.dragging.moved
  local thumb_hl = dragging and 'VVScrollbarHover' or 'VVScrollbarThumb'
  local thumb_text = string.rep(markers.cell(cfg.symbols.thumb), width)
  local track_text = string.rep(' ', width)

  for row = 0, viewport.height - 1 do
    local in_thumb = row >= viewport.thumb_row and row < viewport.thumb_row + viewport.thumb_height
    api.nvim_buf_set_extmark(bar.buf, ns, row, 0, {
      virt_text = {
        { in_thumb and thumb_text or track_text, in_thumb and thumb_hl or 'VVScrollbarTrack' },
      },
      virt_text_pos = 'overlay',
      priority = 1,
    })

    local marker = row_markers[row]
    if marker then
      local marker_text = marker.fill_width
        and string.rep(marker.text, width)
        or marker.text
      api.nvim_buf_set_extmark(bar.buf, ns, row, 0, {
        virt_text = { { marker_text, marker.hl } },
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
        priority = marker.priority,
      })
    end
  end
end

---@return integer[]
local function target_windows()
  if config.current().current_only then
    return { api.nvim_get_current_win() }
  end
  return api.nvim_tabpage_list_wins(api.nvim_get_current_tabpage())
end

function M.refresh()
  if not state.enabled then return end

  local keep = {}
  for _, win in ipairs(target_windows()) do
    if should_show(win) then
      keep[win] = true
      local ok, err = pcall(render, win)
      if not ok then
        if tostring(err):find('E565:', 1, true) then
          retry_refresh()
        else
          vim.schedule(function()
            vim.notify('vv-scrollbar: render failed: ' .. tostring(err), vim.log.levels.ERROR)
          end)
        end
      end
    end
  end

  for parent in pairs(vim.deepcopy(state.bars)) do
    if not keep[parent] then M.close(parent) end
  end
end

function M.close_all()
  for parent in pairs(vim.deepcopy(state.bars)) do
    M.close(parent)
  end
end

---@param screenrow integer
---@param screencol integer
---@return VVScrollbarBar?
function M.hit_test(screenrow, screencol)
  for _, bar in pairs(state.bars) do
    if api.nvim_win_is_valid(bar.win) then
      local position = fn.win_screenpos(bar.win)
      local top = position[1]
      local left = position[2]
      local width = api.nvim_win_get_width(bar.win)
      local height = api.nvim_win_get_height(bar.win)
      local inside_rows = screenrow >= top and screenrow < top + height
      local inside_columns = screencol >= left and screencol < left + width
      if inside_rows and inside_columns then
        return bar
      end
    end
  end
  return nil
end

return M
