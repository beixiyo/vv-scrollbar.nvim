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
api.nvim_buf_set_lines(buf, 0, -1, false, { 'xx' })
cache.get(buf, 1, 1, config.current().map_view, function() end)
cache.get(buf, 1, 2, config.current().map_view, function() end)
api.nvim_buf_set_lines(buf, 0, -1, false, { '  ' })

local multi_width_refreshes = 0
cache.get(buf, 1, 1, config.current().map_view, function()
  multi_width_refreshes = multi_width_refreshes + 1
end)
cache.get(buf, 1, 2, config.current().map_view, function()
  multi_width_refreshes = multi_width_refreshes + 1
end)
assert(
  vim.wait(500, function() return multi_width_refreshes == 2 end, 10),
  'generation tokens canceled a valid rebuild for another map width'
)

api.nvim_buf_set_lines(buf, 0, -1, false, { 'x' })
cache.get(buf, 1, 1, config.current().map_view, function()
  error('cleared cache executed a stale rebuild callback')
end)
cache.clear(buf)
vim.wait(200, function() return false end, 10)
api.nvim_buf_delete(buf, { force = true })

print('PASS: stale reuse, per-key generations, cancellation and cache cleanup')
