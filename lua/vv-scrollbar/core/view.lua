local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local state = require('vv-scrollbar.core.state')
local map_view = require('vv-scrollbar.features.map_view')
local render_ui = require('vv-scrollbar.ui.render')
local window = require('vv-scrollbar.ui.window')

local M = {}

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

  if map_view.is_active(buf) and cfg.map_view.show_on_short_buffers then return true end
  if vim.w[win].vv_scrollbar_always_show then return true end

  local line_count = api.nvim_buf_line_count(buf)
  local topline = fn.line('w0', win)
  local botline = fn.line('w$', win)
  return line_count > 0 and botline - topline + 1 < line_count
end

---@param parent integer
function M.close(parent)
  local bar = state.bars[parent]
  if not bar then return end

  window.close(bar)
  state.bars[parent] = nil
end

---@param parent integer
local function render(parent)
  local viewport = geometry.viewport(parent)
  local bar = state.bars[parent]
  if not bar then
    bar = window.create(parent)
    state.bars[parent] = bar
  end
  local has_map_view = map_view.is_active(viewport.buf)

  bar.parent = parent
  bar.height = viewport.height
  bar.thumb_row = viewport.thumb_row
  bar.thumb_height = viewport.thumb_height

  -- 父窗有 winbar 时，bar 是无 winbar 的右分屏兄弟窗：bar 的 buffer 行 0 落在父窗
  -- winbar 所在屏行，而 viewport（thumb_row/marker）是以父窗「内容区」为 0 的坐标
  -- 若不偏移，thumb/marker 会整体上移 1 行（winbar 行被画上 track、最底内容行无标记）
  -- 故把所有 extmark 行整体下移 winbar 高度，顶部空出的行留作空白 track
  local winbar_offset = geometry.win_has_winbar(parent) and 1 or 0

  window.sync(parent, bar, has_map_view)
  local dragging = state.dragging
    and state.dragging.parent == parent
    and state.dragging.moved
  render_ui.render(
    parent,
    bar,
    viewport,
    has_map_view,
    winbar_offset,
    dragging or false,
    M.refresh
  )
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
      local width = bar.track_width
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

---@param bar VVScrollbarBar
---@param row integer
---@param screencol integer
---@return VVScrollbarMarkerHit?
function M.marker_at(bar, row, screencol)
  local hits = bar.marker_hits and bar.marker_hits[row]
  if not hits or not api.nvim_win_is_valid(bar.win) then return nil end

  local left = fn.win_screenpos(bar.win)[2]
  local col = screencol - left
  for _, hit in ipairs(hits) do
    if col >= hit.start_col and col < hit.end_col then return hit end
  end
  return nil
end

return M
