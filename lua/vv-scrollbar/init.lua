-- vv-scrollbar.nvim - 自绘右侧滚动条

require('vv-scrollbar.types')

local api = vim.api

local config = require('vv-scrollbar.config')
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')
local git = require('vv-scrollbar.features.git')
local map_view = require('vv-scrollbar.features.map_view')
local mouse = require('vv-scrollbar.input.mouse')
local highlights = require('vv-scrollbar.ui.highlights')
local events = require('vv-scrollbar.lifecycle.events')

local M = {}
local unpack_results = table.unpack or unpack
local function pack_results(...)
  return { n = select('#', ...), ... }
end

local function refresh()
  view.refresh()
end

local function ensure_refresh_throttle()
  if state.refresh_throttled then return end
  state.refresh_throttled, state.refresh_cancel = require('vv-utils.timer').throttle(
    refresh,
    config.current().throttle_ms
  )
end

local function close_refresh_throttle()
  if state.refresh_cancel then state.refresh_cancel() end
  state.refresh_throttled = nil
  state.refresh_cancel = nil
end

local function schedule_refresh()
  if state.refresh_throttled then
    state.refresh_throttled()
  else
    refresh()
  end
end

local function refresh_visible_git()
  git.refresh_visible(schedule_refresh)
end

local function refresh_colors()
  map_view.clear_all()
  highlights.setup()
  refresh()
end

---暂时移除滚动条 split，执行布局操作后恢复渲染
---@generic T
---@param callback fun(): T
---@return T
function M.with_layout_suspended(callback)
  assert(type(callback) == 'function', 'callback must be a function')

  local outermost = state.layout_suspend_depth == 0
  local current_win = api.nvim_get_current_win()
  local widths = {}
  local results

  if outermost then
    for parent, bar in pairs(state.bars) do
      if api.nvim_win_is_valid(parent) and api.nvim_win_is_valid(bar.win) then
        widths[#widths + 1] = {
          win = parent,
          width = api.nvim_win_get_width(parent)
            + api.nvim_win_get_width(bar.win)
            + 1,
        }
      end
    end
  end

  state.layout_suspend_depth = state.layout_suspend_depth + 1
  local ok, err = xpcall(function()
    if outermost then
      view.close_all()
      for _, item in ipairs(widths) do
        if api.nvim_win_is_valid(item.win) then
          api.nvim_win_set_width(item.win, item.width)
        end
      end
      if api.nvim_win_is_valid(current_win) then api.nvim_set_current_win(current_win) end
    end

    results = pack_results(callback())
  end, debug.traceback)
  state.layout_suspend_depth = state.layout_suspend_depth - 1

  if outermost then
    local refresh_ok, refresh_err = xpcall(function()
      view.refresh({ strict = true })
    end, debug.traceback)
    if not refresh_ok then
      if ok then
        ok = false
        err = refresh_err
      else
        err = err .. '\nScrollbar recovery also failed:\n' .. refresh_err
      end
    end
  end

  if not ok then error(err, 0) end
  ---@diagnostic disable-next-line: redundant-return-value
  return unpack_results(results, 1, results.n)
end

---@return boolean map_view_enabled
function M.toggle_view()
  local map_config = config.current().map_view
  map_config.enabled = not map_config.enabled
  refresh()
  return map_config.enabled
end

function M.enable()
  if state.enabled then return end

  ensure_refresh_throttle()
  state.enabled = true
  highlights.setup()
  events.attach(schedule_refresh, refresh_visible_git, refresh, refresh_colors)
  mouse.attach(refresh, M.toggle_view)
  refresh_visible_git()
  schedule_refresh()
end

function M.disable()
  if not state.enabled then return end

  state.enabled = false
  mouse.detach()
  events.detach()
  git.clear_all()
  view.close_all()
  map_view.clear_all()
  close_refresh_throttle()
end

function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

---@param opts? VVScrollbarConfigOpts
function M.setup(opts)
  config.apply(opts)
  git.clear_all()
  map_view.clear_all()

  close_refresh_throttle()
  if config.current().enabled or state.enabled then ensure_refresh_throttle() end

  if not state.did_setup then
    state.did_setup = true
    api.nvim_create_user_command('VVScrollbarEnable', M.enable, {})
    api.nvim_create_user_command('VVScrollbarDisable', M.disable, {})
    api.nvim_create_user_command('VVScrollbarToggle', M.toggle, {})
    api.nvim_create_user_command('VVScrollbarToggleView', M.toggle_view, {})
    api.nvim_create_user_command('VVScrollbarRefresh', function()
      refresh_visible_git()
      refresh()
    end, {})
  end

  if config.current().enabled then
    if state.enabled then
      highlights.setup()
      refresh_visible_git()
      refresh()
    else
      M.enable()
    end
  else
    M.disable()
  end
end

---@return VVScrollbarConfig
function M.get_config()
  return config.get()
end

return M
