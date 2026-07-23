local api = vim.api
local renderer = require('vv-scrollbar.features.map_view.renderer')

local M = {}

local cache_by_buf = {}
local pending_by_buf = {}
local generation_by_buf = {}

---@param capture_map table<string,string|false>?
---@return string
local function capture_map_key(capture_map)
  local entries = {}
  for capture, group in pairs(capture_map or {}) do
    entries[#entries + 1] = capture .. '=' .. tostring(group)
  end
  table.sort(entries)
  return table.concat(entries, ',')
end

---@param buf integer
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@return string
local function cache_key(buf, height, width, opts)
  local tab_width = opts.tab_width == 'buffer' and vim.bo[buf].tabstop or opts.tab_width
  return table.concat({
    opts.mode,
    height,
    width,
    opts.x_multiplier,
    opts.y_multiplier,
    opts.max_lines_per_dot,
    tab_width,
    opts.include_whitespace and 1 or 0,
    vim.bo[buf].filetype,
    opts.syntax and opts.syntax.enabled and 1 or 0,
    opts.syntax and opts.syntax.max_lines or 0,
    opts.syntax and opts.syntax.max_bytes or 0,
    opts.syntax and opts.syntax.max_captures or 0,
    opts.syntax and opts.syntax.max_time_ms or 0,
    opts.syntax and opts.syntax.fallback or 'mono',
    capture_map_key(opts.syntax and opts.syntax.capture_map),
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
---@return { tick: integer, lines: string[], highlights: table<integer,VVScrollbarMapHighlight[]> }
local function render_and_store(buf, key, height, width, opts)
  local lines, highlights = renderer.render(buf, height, width, opts)
  local entry = {
    tick = api.nvim_buf_get_changedtick(buf),
    lines = lines,
    highlights = highlights,
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

  generation_by_buf[buf] = generation_by_buf[buf] or {}
  local generation = (generation_by_buf[buf][key] or 0) + 1
  generation_by_buf[buf][key] = generation
  pending_by_buf[buf] = pending_by_buf[buf] or {}
  pending_by_buf[buf][key] = {
    timer = timer,
    tick = tick,
    generation = generation,
  }
  timer:start(opts.debounce_ms, 0, vim.schedule_wrap(function()
    local pending = pending_by_buf[buf] and pending_by_buf[buf][key]
    if not pending or pending.generation ~= generation then return end
    stop_pending(buf, key)
    if not api.nvim_buf_is_valid(buf)
        or not generation_by_buf[buf]
        or generation_by_buf[buf][key] ~= generation
        or api.nvim_buf_get_changedtick(buf) ~= tick
    then
      return
    end

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
---@return table<integer,VVScrollbarMapHighlight[]>
function M.get(buf, height, width, opts, refresh)
  local key = cache_key(buf, height, width, opts)
  local tick = api.nvim_buf_get_changedtick(buf)
  local cached = cache_by_buf[buf] and cache_by_buf[buf][key]

  if not cached then
    cached = render_and_store(buf, key, height, width, opts)
  elseif cached.tick ~= tick then
    schedule_rebuild(buf, key, tick, height, width, opts, refresh)
  end

  return cached.lines,
    table.concat({ buf, key, cached.tick }, ':'),
    cached.highlights
end

---@param buf integer
function M.clear(buf)
  local pending_by_key = pending_by_buf[buf]
  if pending_by_key then
    local keys = vim.tbl_keys(pending_by_key)
    for _, key in ipairs(keys) do stop_pending(buf, key) end
  end
  cache_by_buf[buf] = nil
  generation_by_buf[buf] = nil
end

function M.clear_all()
  local buffers = {}
  for buf in pairs(cache_by_buf) do buffers[buf] = true end
  for buf in pairs(pending_by_buf) do buffers[buf] = true end
  for buf in pairs(buffers) do M.clear(buf) end
end

return M
