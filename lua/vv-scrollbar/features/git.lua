local api = vim.api
local fn = vim.fn

local config = require('vv-scrollbar.config')
local state = require('vv-scrollbar.core.state')
local Async = require('vv-utils.async')

local M = {}
local scopes = {}

---@param buf integer
---@return string? path
---@return vv-utils.git.DiffSource? opts
---@return string? signature
---@return 'U'? marker_kind
local function resolve_source(buf)
  local source = vim.b[buf].vv_git_diff_source
    or vim.b[buf].vv_scrollbar_git_source

  if type(source) == 'table' and type(source.path) == 'string' and source.path ~= '' then
    local opts = {
      root = source.root,
      mode = source.mode,
      from_rev = source.from_rev,
      to_rev = source.to_rev,
      from_index_stage = source.from_index_stage,
      to_index_stage = source.to_index_stage,
      side = source.side,
    }

    local marker_kind = source.marker_kind == 'U' and 'U' or nil
    local signature = table.concat({
      source.path,
      source.root or '',
      source.mode or '',
      source.from_rev or '',
      source.to_rev or '',
      source.from_index_stage or '',
      source.to_index_stage or '',
      source.side or '',
      marker_kind or '',
    }, '\0')

    return source.path, opts, signature, marker_kind
  end

  local path = api.nvim_buf_get_name(buf)
  if path == '' or fn.filereadable(path) == 0 then return nil end
  return path, nil, path
end

---@param buf integer
---@param schedule_refresh fun()
function M.refresh(buf, schedule_refresh)
  if not config.current().markers.git then
    M.clear(buf)
    return
  end
  if not api.nvim_buf_is_loaded(buf) then return end

  local path, opts, signature, marker_kind = resolve_source(buf)
  if not path or not signature then
    M.clear(buf)
    return
  end

  local pending = state.git_pending[buf]
  if pending and pending.signature == signature then
    pending.dirty = true
    pending.schedule_refresh = schedule_refresh
    return
  end
  if pending then pending.request:cancel() end

  local scope = scopes[buf]
  if not scope or scope:is_disposed() then
    scope = Async.scope({ cancel_previous = true })
    scopes[buf] = scope
  end
  local request = scope:begin()
  local record = {
    request = request,
    signature = signature,
    schedule_refresh = schedule_refresh,
    dirty = false,
  }
  state.git_pending[buf] = record

  local function done(markers)
    local current = request:finish()
    if state.git_pending[buf] ~= record then return end
    state.git_pending[buf] = nil

    if not current then return end
    if not api.nvim_buf_is_loaded(buf) then
      state.git_marks[buf] = nil
      return
    end

    local _, _, current_signature = resolve_source(buf)
    if current_signature ~= signature then return end
    state.git_marks[buf] = markers
    schedule_refresh()

    if record.dirty and scopes[buf] == scope and not scope:is_disposed() then
      M.refresh(buf, record.schedule_refresh)
    end
  end

  local cancel
  if opts then
    cancel = require('vv-utils.git').diff_lines(path, function(markers)
      local sets = { staged = {}, unstaged = {} }
      local channel = opts.mode == 'staged' and 'staged' or 'unstaged'

      if marker_kind then
        for line in pairs(markers or {}) do sets[channel][line] = marker_kind end
      else
        sets[channel] = markers or {}
      end

      done(sets)
    end, opts)
  else
    cancel = require('vv-utils.git').diff_line_sets(path, done)
  end
  request:set_cancel(cancel)
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
  if scopes[buf] then scopes[buf]:dispose() end
  scopes[buf] = nil
  state.git_marks[buf] = nil
  state.git_pending[buf] = nil
end

function M.clear_all()
  for buf in pairs(scopes) do
    M.clear(buf)
  end

  for buf in pairs(state.git_marks) do
    state.git_marks[buf] = nil
  end

  for buf in pairs(state.git_pending) do
    state.git_pending[buf] = nil
  end
end

---@class VVScrollbarGitSource: vv-utils.git.DiffSource
---@field marker_kind? 'U' 将 source 的 diff marker 归一化为未解决冲突

return M
