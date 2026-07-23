local api = vim.api
local renderer = require('vv-scrollbar.features.map_view.renderer')

local M = {}

local cache_by_buf = {}
local pending_by_buf = {}

---@param buf integer
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@return string
local function cache_key(buf, height, width, opts)
  local tab_width = opts.tab_width == 'buffer' and vim.bo[buf].tabstop or opts.tab_width
  return table.concat({
    height,
    width,
    opts.x_multiplier,
    opts.max_lines_per_dot,
    tab_width,
    opts.include_whitespace and 1 or 0,
  }, ':')
end

---@param buf integer
---@param key string
local function stop_pending(buf, key)
  local pending_by_key = pending_by_buf[buf]
  local entry = pending_by_key and pending_by_key[key]
  if not entry then return end

  entry.timer:stop()
  entry.timer:close()
  pending_by_key[key] = nil
  if not next(pending_by_key) then pending_by_buf[buf] = nil end
end

---@param buf integer
---@param key string
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@return { tick: integer, lines: string[] }
local function render_and_store(buf, key, height, width, opts)
  local entry = {
    tick = api.nvim_buf_get_changedtick(buf),
    lines = renderer.render(buf, height, width, opts),
  }
  cache_by_buf[buf] = cache_by_buf[buf] or {}
  cache_by_buf[buf][key] = entry
  return entry
end

---@param buf integer
---@param key string
---@param tick integer
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@param refresh fun()
local function schedule_rebuild(buf, key, tick, height, width, opts, refresh)
  pending_by_buf[buf] = pending_by_buf[buf] or {}
  local current = pending_by_buf[buf][key]
  if current and current.tick == tick then return end
  if current then stop_pending(buf, key) end

  local timer = vim.uv.new_timer()
  if not timer then return end

  pending_by_buf[buf] = pending_by_buf[buf] or {}
  pending_by_buf[buf][key] = { timer = timer, tick = tick }
  timer:start(opts.debounce_ms, 0, vim.schedule_wrap(function()
    stop_pending(buf, key)
    if not api.nvim_buf_is_valid(buf) then return end

    render_and_store(buf, key, height, width, opts)
    refresh()
  end))
end

---@param buf integer
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@param refresh fun()
---@return string[]
---@return string
function M.get(buf, height, width, opts, refresh)
  local key = cache_key(buf, height, width, opts)
  local tick = api.nvim_buf_get_changedtick(buf)
  local cached = cache_by_buf[buf] and cache_by_buf[buf][key]

  if not cached then
    cached = render_and_store(buf, key, height, width, opts)
  elseif cached.tick ~= tick then
    schedule_rebuild(buf, key, tick, height, width, opts, refresh)
  end

  return cached.lines, table.concat({ buf, key, cached.tick }, ':')
end

---@param buf integer
function M.clear(buf)
  local pending_by_key = pending_by_buf[buf]
  if pending_by_key then
    local keys = vim.tbl_keys(pending_by_key)
    for _, key in ipairs(keys) do stop_pending(buf, key) end
  end
  cache_by_buf[buf] = nil
end

function M.clear_all()
  local buffers = {}
  for buf in pairs(cache_by_buf) do buffers[buf] = true end
  for buf in pairs(pending_by_buf) do buffers[buf] = true end
  for buf in pairs(buffers) do M.clear(buf) end
end

return M
