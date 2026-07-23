-- Tree-sitter capture 到仅保留前景色的 map 专用高亮映射

local api = vim.api

local M = {}

local groups = {}

---@param source string
---@return string?
function M.resolve(source)
  if groups[source] ~= nil then return groups[source] or nil end

  local ok, highlight = pcall(api.nvim_get_hl, 0, {
    name = source,
    link = false,
  })
  if not ok or not highlight.fg then
    groups[source] = false
    return nil
  end

  local name = 'VVScrollbarMapSyntax' .. vim.fn.sha256(source):sub(1, 12)
  api.nvim_set_hl(0, name, { fg = highlight.fg })
  groups[source] = name
  return name
end

function M.clear()
  for _, name in pairs(groups) do
    if name then api.nvim_set_hl(0, name, {}) end
  end
  groups = {}
end

return M
