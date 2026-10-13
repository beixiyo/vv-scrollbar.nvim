-- 冲突 marker 数据源：按 changedtick 缓存；轻量模式分片扫描并丢弃过期结果
local api = vim.api
local parse_hunks = require('vv-utils.git').parse_conflict_hunks

local M = {}
local cache = {}
local CHUNK_LINES = 256

local function stop(entry)
  if entry and entry.timer and not entry.timer:is_closing() then
    entry.timer:stop()
    entry.timer:close()
  end
  if entry then entry.timer = nil end
end

---轻量扫描只保留可能的分隔符，再交给共享 parser 判断完整冲突块
---源码行映射单独保存，不复制整份 buffer；生成行级投影也分片，避免大冲突块阻塞
local function scan_async(buf, entry)
  local row, candidates, source_rows = 0, {}, {}
  local hunks, hunk_index, marker_line
  local markers = {}
  local step
  step = function()
    entry.timer = nil
    if cache[buf] ~= entry then return end
    if not api.nvim_buf_is_loaded(buf) or api.nvim_buf_get_changedtick(buf) ~= entry.changedtick then
      cache[buf] = nil
      return
    end

    if not hunks then
      local last = math.min(row + CHUNK_LINES, api.nvim_buf_line_count(buf))
      for index, line in ipairs(api.nvim_buf_get_lines(buf, row, last, false)) do
        local prefix = line:sub(1, 7)
        if prefix == '<<<<<<<' or prefix == '|||||||'
            or prefix == '=======' or prefix == '>>>>>>>' then
          candidates[#candidates + 1] = line:sub(1, 8)
          source_rows[#source_rows + 1] = row + index
        end
      end
      row = last
      if row == api.nvim_buf_line_count(buf) then
        hunks = parse_hunks(candidates)
        hunk_index = 1
      end
    else
      local remaining = CHUNK_LINES
      while remaining > 0 and hunks[hunk_index] do
        local hunk = hunks[hunk_index]
        marker_line = marker_line or source_rows[hunk.start_line]
        local last = math.min(source_rows[hunk.end_line], marker_line + remaining - 1)
        for line = marker_line, last do markers[line] = 'U' end
        remaining = remaining - (last - marker_line + 1)
        marker_line = last + 1
        if last == source_rows[hunk.end_line] then
          hunk_index = hunk_index + 1
          marker_line = nil
        end
      end
    end

    if hunks and not hunks[hunk_index] then
      entry.lines = markers
      entry.pending = false
      if entry.on_update then entry.on_update() end
      return
    end
    entry.timer = vim.defer_fn(step, 1)
  end
  entry.timer = vim.defer_fn(step, 1)
end

---@param buf integer
---@param opts? { deferred?: boolean, on_update?: fun() }
---@return table<integer, 'U'>
function M.lines(buf, opts)
  if not api.nvim_buf_is_valid(buf) or not api.nvim_buf_is_loaded(buf) then return {} end
  -- 保持旧版 utils / 精简 Git adapter 的兼容边界
  if type(parse_hunks) ~= 'function' then return {} end

  local tick = api.nvim_buf_get_changedtick(buf)
  local entry = cache[buf]
  if entry and entry.changedtick == tick then
    if opts and opts.on_update then entry.on_update = opts.on_update end
    return entry.lines
  end

  stop(entry)
  entry = { changedtick = tick, lines = {}, on_update = opts and opts.on_update }
  cache[buf] = entry

  if opts and opts.deferred then
    entry.pending = true
    scan_async(buf, entry)
  else
    local hunks = parse_hunks(api.nvim_buf_get_lines(buf, 0, -1, false))
    for _, hunk in ipairs(hunks) do
      for line = hunk.start_line, hunk.end_line do entry.lines[line] = 'U' end
    end
  end
  return entry.lines
end

---取消没有可见消费者的后台扫描；已完成的 changedtick 缓存可以保留
---@param buffers table<integer, boolean>
function M.retain(buffers)
  for buf, entry in pairs(cache) do
    if entry.pending and not buffers[buf] then M.clear(buf) end
  end
end

---@param buf integer
function M.clear(buf)
  stop(cache[buf])
  cache[buf] = nil
end

function M.clear_all()
  for buf in pairs(cache) do M.clear(buf) end
end

return M
