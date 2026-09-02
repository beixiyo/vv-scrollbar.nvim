-- 冲突 marker 数据源：按 buffer changedtick 缓存完整冲突块的行级投影

local api = vim.api

local M = {}
local cache = {}

---@param buf integer
---@return table<integer, 'U'>
function M.lines(buf)
  if not api.nvim_buf_is_valid(buf) or not api.nvim_buf_is_loaded(buf) then return {} end

  local changedtick = api.nvim_buf_get_changedtick(buf)
  local cached = cache[buf]
  if cached and cached.changedtick == changedtick then return cached.lines end

  local markers = {}
  -- 旧版 vv-utils 没有该 API 时静默退化为无冲突标记，避免整条滚动条渲染失败
  local parse_conflict_hunks = require('vv-utils.git').parse_conflict_hunks
  if type(parse_conflict_hunks) ~= 'function' then
    cache[buf] = { changedtick = changedtick, lines = markers }
    return markers
  end

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = parse_conflict_hunks(lines)
  for _, hunk in ipairs(hunks) do
    for line = hunk.start_line, hunk.end_line do markers[line] = 'U' end
  end

  cache[buf] = { changedtick = changedtick, lines = markers }
  return markers
end

---@param buf integer
function M.clear(buf)
  cache[buf] = nil
end

function M.clear_all()
  cache = {}
end

return M
