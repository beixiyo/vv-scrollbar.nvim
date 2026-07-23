local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local state = require('vv-scrollbar.core.state')
local view = require('vv-scrollbar.core.view')

local parent = api.nvim_get_current_win()
local buf = api.nvim_get_current_buf()
local lines = {}
for index = 1, 200 do
  lines[index] = ('local value_%d = "text"'):format(index)
end
api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.bo[buf].filetype = 'lua'
vim.wo[parent].wrap = false

api.nvim_set_hl(0, '@keyword.lua', { fg = 0x123456 })

local scrollbar = require('vv-scrollbar')
scrollbar.setup({
  throttle_ms = 0,
  map_view = {
    width = 12,
    syntax = {
      enabled = true,
      max_lines = 0,
      max_bytes = 0,
    },
  },
  markers = {
    diagnostics = false,
    git = false,
    search = false,
    marks = false,
    quickfix = false,
    cursor = false,
  },
})
view.refresh()

local namespace = api.nvim_get_namespaces()['vv-scrollbar']

---@param expected integer
---@return boolean
local function has_syntax_color(expected)
  local bar = state.bars[parent]
  local extmarks = api.nvim_buf_get_extmarks(
    bar.buf,
    namespace,
    0,
    -1,
    { details = true }
  )
  for _, extmark in ipairs(extmarks) do
    local group = extmark[4].hl_group
    if group then
      local opts = type(group) == 'number' and { id = group } or { name = group }
      local highlight = api.nvim_get_hl(0, opts)
      if highlight.fg == expected then return true end
    end
  end
  return false
end

assert(has_syntax_color(0x123456), 'syntax spans were not applied to the map buffer')

api.nvim_set_hl(0, '@keyword.lua', { fg = 0xabcdef })
api.nvim_exec_autocmds('ColorScheme', { pattern = 'map-syntax-test' })
assert(
  vim.wait(500, function() return has_syntax_color(0xabcdef) end, 10),
  'ColorScheme did not rebuild the Tree-sitter map palette'
)

scrollbar.disable()
print('PASS: syntax extmarks use theme colors and refresh after ColorScheme')
