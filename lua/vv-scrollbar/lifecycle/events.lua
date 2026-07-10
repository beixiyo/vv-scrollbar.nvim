local api = vim.api

local state = require('vv-scrollbar.core.state')
local git = require('vv-scrollbar.features.git')

local M = {}

---@param schedule_refresh fun()
---@param refresh_visible_git fun()
function M.attach(schedule_refresh, refresh_visible_git)
  state.augroup = api.nvim_create_augroup('VVScrollbar', { clear = true })

  api.nvim_create_autocmd({
    'WinScrolled',
    'WinEnter',
    'WinLeave',
    'BufWinEnter',
    'TabEnter',
    'VimResized',
    'TextChanged',
    'TextChangedI',
    'DiagnosticChanged',
    'CursorMoved',
    'CursorMovedI',
    'QuickFixCmdPost',
  }, {
    group = state.augroup,
    callback = schedule_refresh,
  })

  api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
    group = state.augroup,
    callback = function(args)
      git.refresh(args.buf, schedule_refresh)
      schedule_refresh()
    end,
  })

  api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
    group = state.augroup,
    callback = function()
      refresh_visible_git()
      schedule_refresh()
    end,
  })

  api.nvim_create_autocmd('User', {
    group = state.augroup,
    pattern = 'VVGitStatusChanged',
    callback = function()
      refresh_visible_git()
      schedule_refresh()
    end,
  })

  api.nvim_create_autocmd('BufWipeout', {
    group = state.augroup,
    callback = function(args)
      git.clear(args.buf)
    end,
  })
end

function M.detach()
  if not state.augroup then return end
  pcall(api.nvim_del_augroup_by_id, state.augroup)
  state.augroup = nil
end

return M
