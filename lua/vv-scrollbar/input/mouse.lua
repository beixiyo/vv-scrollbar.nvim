local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local state = require('vv-scrollbar.core.state')
local map_view = require('vv-scrollbar.features.map_view')
local right_click = require('vv-scrollbar.input.right_click')
local viewport_drag = require('vv-scrollbar.input.viewport_drag')
local view = require('vv-scrollbar.core.view')

local M = {}

local ns = vim.api.nvim_create_namespace('vv-scrollbar.mouse')
local LEFT_MOUSE = vim.keycode('<LeftMouse>')
local LEFT_DRAG = vim.keycode('<LeftDrag>')
local LEFT_RELEASE = vim.keycode('<LeftRelease>')
local SCROLL_WHEEL_UP = vim.keycode('<ScrollWheelUp>')
local SCROLL_WHEEL_DOWN = vim.keycode('<ScrollWheelDown>')
local ESC = vim.keycode('<Esc>')
local LEFT_PRESSES = {
  [LEFT_MOUSE] = true,
  [vim.keycode('<2-LeftMouse>')] = true,
  [vim.keycode('<3-LeftMouse>')] = true,
  [vim.keycode('<4-LeftMouse>')] = true,
}
local LEFT_DRAGS = {
  [LEFT_DRAG] = true,
  [vim.keycode('<2-LeftDrag>')] = true,
  [vim.keycode('<3-LeftDrag>')] = true,
  [vim.keycode('<4-LeftDrag>')] = true,
}
local LEFT_RELEASES = {
  [LEFT_RELEASE] = true,
  [vim.keycode('<2-LeftRelease>')] = true,
  [vim.keycode('<3-LeftRelease>')] = true,
  [vim.keycode('<4-LeftRelease>')] = true,
}
local WHEEL_DIRECTIONS = {
  [SCROLL_WHEEL_UP] = 'up',
  [SCROLL_WHEEL_DOWN] = 'down',
}

---@type fun()?
local refresh
---@type fun()?
local toggle_view

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
  local click_line
  if not in_thumb then
    click_line = bar.map_layout
        and map_view.row_to_line(bar.map_layout, mouse_row)
      or geometry.bar_row_to_line(bar.parent, mouse_row)
  end

  state.dragging = {
    parent = bar.parent,
    offset = offset,
    moved = false,
    click_line = click_line,
    map_top = nil,
  }

  -- 按住已有 thumb 只切换 active 样式，不重复做一次比例换算；后者受取整、fold
  -- 等因素影响，可能让源窗口和地图在按下 / 松开时各跳一次
  if click_line then
    geometry.scroll_to_line(bar.parent, click_line, 'center')
  end
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
    -- 只有真正开始拖拽才冻结地图窗口；普通点击始终沿用当前同步后的投影
    if drag.map_top == nil then drag.map_top = bar.map_layout.top_row end
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
  if not drag.moved and drag.click_line then
    geometry.set_cursor_line(drag.parent, drag.click_line)
  end
  redraw()
end

---@param keys table<string, any>
---@param key string
---@param typed string
---@return any
local function key_value(keys, key, typed)
  return keys[key] or keys[typed]
end

---@param key string
---@param typed string
---@return string?
local function on_key(key, typed)
  local wheel_direction = key_value(WHEEL_DIRECTIONS, key, typed)
  if wheel_direction then
    local position = fn.getmousepos()
    local bar = view.hit_test(position.screenrow, position.screencol)
    if not bar then return nil end

    -- bar 是真实 split；不重定向时，全局滚轮映射会把它自己的绘制 buffer 滚走
    require('vv-utils.scroll').mouse(wheel_direction, bar.parent)
    return ''
  end

  local right_result = right_click.handle(key, typed, toggle_view)
  if right_result ~= nil then return right_result end

  if key_value(LEFT_PRESSES, key, typed) then
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
      geometry.set_cursor_line(bar.parent, marker.source_line)
      redraw()
      return ''
    end

    start_drag(bar, row)
    return ''
  end

  if key_value(LEFT_DRAGS, key, typed) and state.dragging then
    continue_drag(fn.getmousepos())
    return ''
  end

  if key_value(LEFT_RELEASES, key, typed) then
    if state.dragging then
      finish_drag()
      return ''
    end

    -- marker 点击不会建立拖拽状态，但 release 仍需消费，避免它重新落回 nofile 窗口
    local position = fn.getmousepos()
    if view.hit_test(position.screenrow, position.screencol) then return '' end
    return nil
  end

  if (key == ESC or typed == ESC) and state.dragging then
    finish_drag()
    return ''
  end
  return nil
end

---@param refresh_callback fun()
---@param toggle_view_callback? fun()
function M.attach(refresh_callback, toggle_view_callback)
  refresh = refresh_callback
  toggle_view = toggle_view_callback
  vim.on_key(on_key, ns)
end

function M.detach()
  state.dragging = nil
  right_click.reset()
  refresh = nil
  toggle_view = nil
  vim.on_key(nil, ns)
end

return M
