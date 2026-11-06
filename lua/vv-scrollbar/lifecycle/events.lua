local api = vim.api

local state = require('vv-scrollbar.core.state')
local conflicts = require('vv-scrollbar.features.conflicts')
local git = require('vv-scrollbar.features.git')
local window = require('vv-scrollbar.ui.window')

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

  -- 只桥接本轮 BufLeave → WinLeave；真正换 buffer 或进入窗口就丢弃凭据。
  local released_separator
  api.nvim_create_autocmd({ 'BufLeave', 'WinLeave', 'WinClosed', 'BufEnter', 'WinEnter' }, {
    group = state.augroup,
    callback = function(args)
      local released = released_separator
      released_separator = nil
      if args.event == 'BufEnter' or args.event == 'WinEnter' then return end

      -- 关闭非当前窗时 current win 不是被关闭的窗口，必须使用事件中的窗口 id。
      local parent = args.event == 'WinClosed' and tonumber(args.match) or api.nvim_get_current_win()
      local bar = state.bars[parent]
      if not bar then return end

      if args.event ~= 'WinLeave' then
        -- 在原生保存 window-buffer 局部选项前归还；同 buf 多窗换内容未必触发 BufWinLeave。
        local restored = window.restore_separator_highlight(bar)
        if args.event == 'BufLeave' and restored then
          released_separator = { win = parent, buf = args.buf, bar = bar, separator = restored }
        end
      elseif released and released.win == parent and released.buf == api.nvim_win_get_buf(parent)
          and released.bar == bar
      then
        -- 焦点切换的旧窗仍可见，但仅重施刚归还且未被后来 owner 改动的分隔线。
        window.apply_separator_highlight(parent, bar, released.separator)
      end
    end,
  })

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
      conflicts.clear(args.buf)
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
