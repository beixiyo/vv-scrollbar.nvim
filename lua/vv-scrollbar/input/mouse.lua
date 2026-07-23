local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')

local M = {}

local ns = vim.api.nvim_create_namespace('vv-scrollbar.mouse')
local LEFT_MOUSE = vim.keycode('<LeftMouse>')
local LEFT_DRAG = vim.keycode('<LeftDrag>')
local LEFT_RELEASE = vim.keycode('<LeftRelease>')
local ESC = vim.keycode('<Esc>')

---@type fun()?
local refresh

local function redraw()
  if refresh then refresh() end
  vim.cmd.redraw()
end

---@param bar VVScrollbarBar
---@param mouse_row integer
local function start_drag(bar, mouse_row)
  local in_thumb = mouse_row >= bar.thumb_row and mouse_row < bar.thumb_row + bar.thumb_height
  local offset = in_thumb
    and mouse_row - bar.thumb_row
    or math.floor(bar.thumb_height / 2)

  state.dragging = { parent = bar.parent, offset = offset, moved = false }
  geometry.scroll_to_bar_row(bar.parent, mouse_row - offset)
  redraw()
end

---@param position table
local function continue_drag(position)
  local drag = state.dragging
  if not drag then return end

  local row = geometry.screenrow_to_bar_row(drag.parent, position.screenrow)
  if row == nil then return end

  drag.moved = true
  geometry.scroll_to_bar_row(drag.parent, row - drag.offset)
  redraw()
end

local function finish_drag()
  local drag = state.dragging
  if not drag then return end
  state.dragging = nil
  if drag.moved then redraw() end
end

---@param key string
---@return string?
local function on_key(key)
  if key == LEFT_MOUSE then
    local position = fn.getmousepos()
    local bar = view.hit_test(position.screenrow, position.screencol)
    if not bar then return nil end

    -- 用与 continue_drag 相同的换算（screenrow_to_bar_row 会按父窗 winbar 高度校正），
    -- 保证首次点击落点与渲染后的 thumb 行对齐；直接减 bar 窗顶行在父窗有 winbar 时会偏 1 行
    local row = geometry.screenrow_to_bar_row(bar.parent, position.screenrow)
    if row == nil then return nil end

    local marker = view.marker_at(bar, row, position.screencol)
    local marker_click = config.current().map_view.marker_click
    if marker and marker_click ~= 'scrollbar' then
      geometry.scroll_to_line(bar.parent, marker.source_line, marker_click)
      redraw()
      return ''
    end

    start_drag(bar, row)
    return ''
  end

  if not state.dragging then return nil end

  if key == LEFT_DRAG then
    continue_drag(fn.getmousepos())
    return ''
  end

  if key == LEFT_RELEASE then
    finish_drag()
    return ''
  end

  if key == ESC then finish_drag() end
  return nil
end

---@param refresh_callback fun()
function M.attach(refresh_callback)
  refresh = refresh_callback
  vim.on_key(on_key, ns)
end

function M.detach()
  state.dragging = nil
  refresh = nil
  vim.on_key(nil, ns)
end

return M
