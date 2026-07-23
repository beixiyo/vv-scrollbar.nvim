-- 滚动条右键动作：命中检测、多击隔离与可配置回调

local fn = vim.fn

local config = require('vv-scrollbar.config')
local geometry = require('vv-scrollbar.core.geometry')
local view = require('vv-scrollbar.core.view')

local M = {}

local RIGHT_MOUSE = vim.keycode('<RightMouse>')
local RIGHT_DRAG = vim.keycode('<RightDrag>')
local RIGHT_RELEASE = vim.keycode('<RightRelease>')
local PRESSES = {
  [RIGHT_MOUSE] = 1,
  [vim.keycode('<2-RightMouse>')] = 2,
  [vim.keycode('<3-RightMouse>')] = 3,
  [vim.keycode('<4-RightMouse>')] = 4,
}
local DRAGS = {
  [RIGHT_DRAG] = true,
  [vim.keycode('<2-RightDrag>')] = true,
  [vim.keycode('<3-RightDrag>')] = true,
  [vim.keycode('<4-RightDrag>')] = true,
}
local RELEASES = {
  [RIGHT_RELEASE] = true,
  [vim.keycode('<2-RightRelease>')] = true,
  [vim.keycode('<3-RightRelease>')] = true,
  [vim.keycode('<4-RightRelease>')] = true,
}

local captured = false

---@param keys table<string, any>
---@param key string
---@param typed string
---@return any
local function key_value(keys, key, typed)
  return keys[key] or keys[typed]
end

---@param bar VVScrollbarBar
---@param row integer
---@param position table
---@param toggle_view? fun()
local function run_action(bar, row, position, toggle_view)
  local action = config.current().map_view.interaction.right_click
  if action == false then return end

  if action == 'toggle_view' then
    if toggle_view then toggle_view() end
    return
  end

  if type(action) ~= 'function' then return end

  local context = {
    win = bar.parent,
    scrollbar_win = bar.win,
    row = row,
    screenrow = position.screenrow,
    screencol = position.screencol,
    view = bar.map_layout and 'map_view' or 'scrollbar',
  }
  local ok, err = pcall(action, context)
  if ok then return end

  vim.schedule(function()
    vim.notify(('vv-scrollbar: right_click failed: %s'):format(err), vim.log.levels.ERROR)
  end)
end

---@param key string
---@param typed string
---@param toggle_view? fun()
---@return string?
function M.handle(key, typed, toggle_view)
  local clicks = key_value(PRESSES, key, typed)
  if clicks then
    local position = fn.getmousepos()
    local bar = view.hit_test(position.screenrow, position.screencol)
    if not bar then return nil end

    local row = geometry.screenrow_to_bar_row(bar.parent, position.screenrow)
    if row == nil then return '' end

    captured = true
    -- 快速多击只消费事件，不重复切换，避免两次右键后回到原形态
    if clicks == 1 then run_action(bar, row, position, toggle_view) end
    return ''
  end

  if key_value(DRAGS, key, typed) then
    if captured then return '' end

    local position = fn.getmousepos()
    if view.hit_test(position.screenrow, position.screencol) then
      captured = true
      return ''
    end
    return nil
  end

  if not key_value(RELEASES, key, typed) then return nil end
  if captured then
    captured = false
    return ''
  end

  local position = fn.getmousepos()
  if view.hit_test(position.screenrow, position.screencol) then return '' end
  return nil
end

function M.reset()
  captured = false
end

return M
