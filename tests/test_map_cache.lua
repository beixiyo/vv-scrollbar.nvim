local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api
local cache = require('vv-scrollbar.features.map_view.cache')
local config = require('vv-scrollbar.config')

local buf = api.nvim_create_buf(false, true)
api.nvim_buf_set_lines(buf, 0, -1, false, { 'x' })

local refresh_count = 0
local initial = cache.get(buf, 1, 1, config.current().map_view, function()
  refresh_count = refresh_count + 1
end)
api.nvim_buf_set_lines(buf, 0, -1, false, { ' ' })
local stale = cache.get(buf, 1, 1, config.current().map_view, function()
  refresh_count = refresh_count + 1
end)
assert(stale[1] == initial[1], 'changed buffer did not keep its cached map during debounce')
assert(vim.wait(500, function() return refresh_count == 1 end, 10), 'debounced map did not rebuild')

local rebuilt = cache.get(buf, 1, 1, config.current().map_view, function() end)
assert(rebuilt[1] == ' ', 'debounced map cache kept stale source text')
cache.clear(buf)
api.nvim_buf_delete(buf, { force = true })

print('PASS: private map cache, stale reuse, debounce rebuild, cleanup')
