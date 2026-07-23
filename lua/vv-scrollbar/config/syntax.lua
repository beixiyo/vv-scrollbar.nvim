-- map_view.syntax 配置归一化

local M = {}

---@param value any
---@param fallback integer
---@return integer
local function non_negative_integer(value, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(math.floor(number), 0)
end

---@param syntax any
---@param defaults VVScrollbarMapViewSyntaxConfig
---@return VVScrollbarMapViewSyntaxConfig
function M.normalize(syntax, defaults)
  if type(syntax) ~= 'table' then syntax = vim.deepcopy(defaults) end
  if type(syntax.enabled) ~= 'boolean' then syntax.enabled = defaults.enabled end
  syntax.max_lines = non_negative_integer(syntax.max_lines, defaults.max_lines)
  syntax.max_bytes = non_negative_integer(syntax.max_bytes, defaults.max_bytes)
  syntax.max_captures = non_negative_integer(
    syntax.max_captures,
    defaults.max_captures
  )
  syntax.max_time_ms = non_negative_integer(syntax.max_time_ms, defaults.max_time_ms)
  if not vim.tbl_contains({ 'mono', 'scrollbar' }, syntax.fallback) then
    syntax.fallback = defaults.fallback
  end
  if type(syntax.capture_map) ~= 'table' then syntax.capture_map = {} end
  for capture, group in pairs(syntax.capture_map) do
    if type(capture) ~= 'string'
        or (type(group) ~= 'string' and group ~= false)
    then
      syntax.capture_map[capture] = nil
    end
  end
  return syntax
end

return M
