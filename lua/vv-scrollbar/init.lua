-- vv-scrollbar.nvim - 自绘右侧滚动条

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

function M.enable()
  if state.enabled then return end

  ensure_refresh_throttle()
  state.enabled = true
  highlights.setup()
  events.attach(schedule_refresh, refresh_visible_git, refresh)
  mouse.attach(refresh)
  refresh_visible_git()
  schedule_refresh()
end

function M.disable()
  if not state.enabled then return end

  state.enabled = false
  state.dragging = nil
  mouse.detach()
  events.detach()
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

---@param opts? VVScrollbarConfig
function M.setup(opts)
  config.apply(opts)
  map_view.clear_all()

  close_refresh_throttle()
  if config.current().enabled or state.enabled then ensure_refresh_throttle() end

  if not state.did_setup then
    state.did_setup = true
    api.nvim_create_user_command('VVScrollbarEnable', M.enable, {})
    api.nvim_create_user_command('VVScrollbarDisable', M.disable, {})
    api.nvim_create_user_command('VVScrollbarToggle', M.toggle, {})
    api.nvim_create_user_command('VVScrollbarRefresh', function()
      refresh_visible_git()
      refresh()
    end, {})
  end

  if config.current().enabled then
    if state.enabled then
      highlights.setup()
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
