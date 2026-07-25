local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local state = require('vv-scrollbar.core.state')

local M = {}

---@param buf integer
---@param schedule_refresh fun()
function M.refresh(buf, schedule_refresh)
  if not config.current().markers.git then return end
  if not api.nvim_buf_is_loaded(buf) or state.git_pending[buf] then return end

  local source = vim.b[buf].vv_git_diff_source
      or vim.b[buf].vv_scrollbar_git_source
  local path
  local opts
  if type(source) == 'table' and type(source.path) == 'string' and source.path ~= '' then
    path = source.path
    opts = {
      root = source.root,
      mode = source.mode,
      from_rev = source.from_rev,
      to_rev = source.to_rev,
      side = source.side,
    }
  else
    path = api.nvim_buf_get_name(buf)
    if path == '' or fn.filereadable(path) == 0 then
      state.git_marks[buf] = nil
      return
    end
  end

  state.git_pending[buf] = true
  local function done(markers)
    state.git_pending[buf] = nil
    if not api.nvim_buf_is_loaded(buf) then
      state.git_marks[buf] = nil
      return
    end

    state.git_marks[buf] = markers
    schedule_refresh()
  end

  if opts then
    require('vv-utils.git').diff_lines(path, function(markers)
      local sets = { staged = {}, unstaged = {} }
      local channel = opts.mode == 'staged' and 'staged' or 'unstaged'
      sets[channel] = markers or {}
      done(sets)
    end, opts)
  else
    require('vv-utils.git').diff_line_sets(path, done)
  end
end

---@param schedule_refresh fun()
function M.refresh_visible(schedule_refresh)
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_is_valid(win) then
      local buf = api.nvim_win_get_buf(win)
      if api.nvim_buf_is_loaded(buf) then
        M.refresh(buf, schedule_refresh)
      end
    end
  end
end

---@param buf integer
function M.clear(buf)
  state.git_marks[buf] = nil
  state.git_pending[buf] = nil
end

---@class VVScrollbarGitSource: vv-utils.git.DiffSource

return M
