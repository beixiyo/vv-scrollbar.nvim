local api = vim.api

local state = require('vv-scrollbar.core.state')
local git = require('vv-scrollbar.features.git')

local M = {}

---@param schedule_refresh fun()
---@param refresh_visible_git fun()
---@param refresh_layout fun()
---@param refresh_colors fun()
function M.attach(schedule_refresh, refresh_visible_git, refresh_layout, refresh_colors)
  state.augroup = api.nvim_create_augroup('VVScrollbar', { clear = true })

  local event_refresh_pending = false
  local function enqueue_refresh()
    if event_refresh_pending then return end
    event_refresh_pending = true

    vim.schedule(function()
      event_refresh_pending = false
      schedule_refresh()
    end)
  end

  api.nvim_create_autocmd({
    'WinScrolled',
    'CursorMoved',
    'CursorMovedI',
  }, {
    group = state.augroup,
    callback = function()
      if not state.dragging then enqueue_refresh() end
    end,
  })

  api.nvim_create_autocmd({
    'TextChanged',
    'TextChangedI',
    'DiagnosticChanged',
    'QuickFixCmdPost',
  }, {
    group = state.augroup,
    callback = enqueue_refresh,
  })

  local layout_refresh_pending = false
  local function schedule_layout_refresh()
    if layout_refresh_pending then return end
    layout_refresh_pending = true

    vim.schedule(function()
      layout_refresh_pending = false
      refresh_layout()
    end)
  end

  api.nvim_create_autocmd({
    'WinNew',
    'WinClosed',
    'WinEnter',
    'WinLeave',
    'WinResized',
    'BufWinEnter',
    'TabEnter',
    'VimResized',
  }, {
    group = state.augroup,
    callback = schedule_layout_refresh,
  })

  api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'BufWinEnter' }, {
    group = state.augroup,
    callback = function(args)
      git.refresh(args.buf, enqueue_refresh)
      enqueue_refresh()
    end,
  })

  api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
    group = state.augroup,
    callback = function()
      refresh_visible_git()
      enqueue_refresh()
    end,
  })

  api.nvim_create_autocmd('User', {
    group = state.augroup,
    pattern = 'VVGitStatusChanged',
    callback = function()
      refresh_visible_git()
      enqueue_refresh()
    end,
  })

  api.nvim_create_autocmd('ColorScheme', {
    group = state.augroup,
    callback = function() vim.schedule(refresh_colors) end,
  })

  api.nvim_create_autocmd('BufWipeout', {
    group = state.augroup,
    callback = function(args)
      git.clear(args.buf)
      require('vv-scrollbar.features.map_view').clear(args.buf)
    end,
  })
end

function M.detach()
  if not state.augroup then return end
  pcall(api.nvim_del_augroup_by_id, state.augroup)
  state.augroup = nil
end

return M
