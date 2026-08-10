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
assert(lua_colors[0x112233], 'Lua 关键字捕获未给 Braille 单元着色')
assert(lua_colors[0x445566], 'Lua 字符串捕获未给 Braille 单元着色')

api.nvim_set_hl(0, 'MapKeywordOverride', { fg = 0x778899 })
palette.clear()
local _, overridden = render(lua_buf, 1, syntax_opts({
  capture_map = { keyword = 'MapKeywordOverride' },
}))
assert(
  highlight_colors(overridden)[0x778899],
  'capture_map 未覆盖 Tree-sitter 关键字颜色'
)

local _, mono = render(lua_buf, 1, syntax_opts({ enabled = false }))
assert(not next(mono), '禁用语法高亮仍然产生了高亮 span')

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
  '注入的 Lua 捕获未覆盖 Markdown 地图颜色'
)

local large_opts = syntax_opts({ max_lines = 1, fallback = 'mono' })
assert(syntax.behavior(lua_buf, large_opts) == 'mono', '大文件语法地图未触发 mono 回退')

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
  'mono 回退时仍解析了 Tree-sitter 捕获'
)

large_opts.fallback = 'scrollbar'
assert(
  syntax.behavior(lua_buf, large_opts) == 'scrollbar',
  '大文件语法地图未触发 scrollbar 回退'
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
  '语法 scrollbar 回退后地图未停用'
)

config.apply({ map_view = { syntax = false } })
assert(
  config.current().map_view.syntax.enabled
    and config.current().map_view.syntax.fallback == 'mono',
  '无效的语法配置未回退到默认值'
)

config.apply()
palette.clear()
api.nvim_buf_delete(lua_buf, { force = true })
api.nvim_buf_delete(markdown_buf, { force = true })

print('PASS: 主题颜色、捕获覆盖、注入与语法预算回退')
