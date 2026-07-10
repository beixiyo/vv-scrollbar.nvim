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

  local source = vim.b[buf].vv_scrollbar_git_source
  local path
  local opts
  if type(source) == 'table' and type(source.path) == 'string' and source.path ~= '' then
    path = source.path
    opts = {
      root = source.root,
      mode = source.mode,
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
  require('vv-utils.git').diff_lines(path, function(markers)
    state.git_pending[buf] = nil
    if not api.nvim_buf_is_loaded(buf) then
      state.git_marks[buf] = nil
      return
    end

    state.git_marks[buf] = markers
    schedule_refresh()
  end, opts)
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

---@class VVScrollbarGitSource
---@field root? string  Git 仓库根
---@field path string  相对仓库根或绝对文件路径
---@field mode? 'worktree'|'staged'  diff 数据源 @default 'worktree'
---@field side? 'new'|'old'  marker 投影侧 @default 'new'

return M
