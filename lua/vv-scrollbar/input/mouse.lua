local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local state = require('vv-scrollbar.core.state')
local map_view = require('vv-scrollbar.features.map_view')
local viewport_drag = require('vv-scrollbar.input.viewport_drag')
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
---@param row integer
local function scroll_to_row(bar, row)
  local layout = bar.map_layout
  if layout and layout.mode == 'viewport' then
    geometry.scroll_to_line(bar.parent, map_view.row_to_line(layout, row), 'top')
    return
  end
  geometry.scroll_to_bar_row(bar.parent, row)
end

---@param bar VVScrollbarBar
---@param drag VVScrollbarDragState
---@return boolean
local function apply_viewport_drag(bar, drag)
  local layout = bar.map_layout
  if not layout or layout.mode ~= 'viewport' or drag.mouse_row == nil then return false end

  local result = viewport_drag.update(
    layout,
    drag.mouse_row,
    drag.offset,
    config.current().map_view.interaction
  )
  drag.map_top = result.top_row
  geometry.scroll_to_line(bar.parent, result.source_line, 'top')
  redraw()
  return result.repeat_edge
end

---@param drag VVScrollbarDragState
local function schedule_edge_scroll(drag)
  if drag.edge_pending then return end
  drag.edge_pending = true
  local delay = config.current().map_view.interaction.edge_interval

  vim.defer_fn(function()
    drag.edge_pending = false
    if state.dragging ~= drag then return end

    local bar = state.bars[drag.parent]
    if not bar then return end
    if apply_viewport_drag(bar, drag) then schedule_edge_scroll(drag) end
  end, delay)
end

---@param bar VVScrollbarBar
---@param mouse_row integer
local function start_drag(bar, mouse_row)
  local in_thumb = mouse_row >= bar.thumb_row and mouse_row < bar.thumb_row + bar.thumb_height
  local offset = in_thumb
    and mouse_row - bar.thumb_row
    or math.floor(bar.thumb_height / 2)

  state.dragging = {
    parent = bar.parent,
    offset = offset,
    moved = false,
    map_top = bar.map_layout
        and bar.map_layout.mode == 'viewport'
        and bar.map_layout.top_row
      or nil,
  }
  scroll_to_row(bar, mouse_row - offset)
  redraw()
end

---@param position table
local function continue_drag(position)
  local drag = state.dragging
  if not drag then return end

  local bar = state.bars[drag.parent]
  if not bar then return end

  drag.moved = true
  if bar.map_layout and bar.map_layout.mode == 'viewport' then
    drag.mouse_row = geometry.screenrow_to_bar_row_raw(drag.parent, position.screenrow)
    if drag.mouse_row == nil then return end
    if apply_viewport_drag(bar, drag) then schedule_edge_scroll(drag) end
    return
  end

  local row = geometry.screenrow_to_bar_row(drag.parent, position.screenrow)
  if row == nil then return end
  scroll_to_row(bar, row - drag.offset)
  redraw()
end

local function finish_drag()
  local drag = state.dragging
  if not drag then return end
  state.dragging = nil
  if drag.moved or drag.map_top then redraw() end
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

  if key == ESC then
    finish_drag()
    return ''
  end
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
