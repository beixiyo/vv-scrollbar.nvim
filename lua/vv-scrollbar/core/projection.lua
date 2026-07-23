-- 源代码行与滚动条屏幕行之间的纯坐标换算

local M = {}

---@param value number
---@param min number
---@param max number
---@return number
function M.clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

---@param line integer
---@param line_count integer
---@param height integer
---@return integer
function M.line_to_row(line, line_count, height)
  if line_count <= 1 or height <= 1 then return 0 end
  local row = math.floor(((line - 1) / math.max(line_count - 1, 1)) * (height - 1) + 0.5)
  return M.clamp(row, 0, height - 1)
end

---@param row integer
---@param line_count integer
---@param height integer
---@return integer
function M.row_to_line(row, line_count, height)
  if line_count <= 1 or height <= 1 then return 1 end
  local ratio = M.clamp(row, 0, height - 1) / (height - 1)
  local line = math.floor(ratio * (line_count - 1) + 1.5)
  return M.clamp(line, 1, line_count)
end

return M
