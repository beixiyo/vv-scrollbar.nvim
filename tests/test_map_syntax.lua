local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local config = require('vv-scrollbar.config')
local map_view = require('vv-scrollbar.features.map_view')
local palette = require('vv-scrollbar.features.map_view.palette')
local renderer = require('vv-scrollbar.features.map_view.renderer')
local syntax = require('vv-scrollbar.features.map_view.syntax')

local function syntax_opts(overrides)
  return vim.tbl_deep_extend('force', {
    enabled = true,
    max_lines = 0,
    max_bytes = 0,
    max_captures = 100000,
    max_time_ms = 0,
    fallback = 'mono',
    capture_map = {},
  }, overrides or {})
end

local function render(buf, height, syntax_config)
  return renderer.render(buf, height, 20, {
    mode = 'viewport',
    x_multiplier = 1,
    y_multiplier = 1,
    max_lines_per_dot = 8,
    tab_width = 2,
    include_whitespace = false,
    syntax = syntax_config,
  })
end

local function highlight_colors(highlights)
  local colors = {}
  for _, spans in pairs(highlights) do
    for _, span in ipairs(spans) do
      local highlight = api.nvim_get_hl(0, { name = span.hl_group })
      if highlight.fg then colors[highlight.fg] = true end
    end
  end
  return colors
end

api.nvim_set_hl(0, '@keyword.lua', { fg = 0x112233 })
api.nvim_set_hl(0, '@string.lua', { fg = 0x445566 })

local lua_buf = api.nvim_create_buf(false, true)
vim.bo[lua_buf].filetype = 'lua'
api.nvim_buf_set_lines(lua_buf, 0, -1, false, {
  'local value = "text"',
  'return value',
})

local _, lua_highlights = render(lua_buf, 1, syntax_opts())
local lua_colors = highlight_colors(lua_highlights)
assert(lua_colors[0x112233], 'Lua keyword capture did not color a Braille cell')
assert(lua_colors[0x445566], 'Lua string capture did not color a Braille cell')

api.nvim_set_hl(0, 'MapKeywordOverride', { fg = 0x778899 })
palette.clear()
local _, overridden = render(lua_buf, 1, syntax_opts({
  capture_map = { keyword = 'MapKeywordOverride' },
}))
assert(
  highlight_colors(overridden)[0x778899],
  'capture_map did not override the Tree-sitter keyword color'
)

local _, mono = render(lua_buf, 1, syntax_opts({ enabled = false }))
assert(not next(mono), 'disabled syntax coloring still emitted highlight spans')

palette.clear()
local fence = string.rep(string.char(96), 3)
local markdown_buf = api.nvim_create_buf(false, true)
vim.bo[markdown_buf].filetype = 'markdown'
api.nvim_buf_set_lines(markdown_buf, 0, -1, false, {
  '# title',
  '',
  fence .. 'lua',
  '          local injected = "lua"',
  fence,
})
local _, injected = render(markdown_buf, 2, syntax_opts())
assert(
  highlight_colors(injected)[0x112233],
  'injected Lua capture did not override the Markdown map color'
)

local large_opts = syntax_opts({ max_lines = 1, fallback = 'mono' })
assert(syntax.behavior(lua_buf, large_opts) == 'mono', 'large syntax map ignored mono fallback')

local original_get_parser = vim.treesitter.get_parser
local parser_calls = 0
vim.treesitter.get_parser = function(...)
  parser_calls = parser_calls + 1
  return original_get_parser(...)
end
local _, large_mono = render(lua_buf, 1, large_opts)
vim.treesitter.get_parser = original_get_parser
assert(
  parser_calls == 0 and not next(large_mono),
  'large mono fallback still parsed Tree-sitter captures'
)

large_opts.fallback = 'scrollbar'
assert(
  syntax.behavior(lua_buf, large_opts) == 'scrollbar',
  'large syntax map ignored scrollbar fallback'
)

config.apply({
  map_view = {
    syntax = {
      max_lines = 1,
      fallback = 'scrollbar',
    },
  },
})
assert(
  map_view.resolve_mode(api.nvim_get_current_win(), lua_buf) == nil,
  'syntax scrollbar fallback kept map view active'
)

config.apply({ map_view = { syntax = false } })
assert(
  config.current().map_view.syntax.enabled
    and config.current().map_view.syntax.fallback == 'mono',
  'invalid syntax config did not fall back to defaults'
)

config.apply()
palette.clear()
api.nvim_buf_delete(lua_buf, { force = true })
api.nvim_buf_delete(markdown_buf, { force = true })

print('PASS: theme colors, capture overrides, injections and syntax budget fallbacks')
