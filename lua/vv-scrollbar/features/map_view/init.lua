local api = vim.api

local config = require('vv-scrollbar.config')
local layout = require('vv-scrollbar.features.map_view.layout')

local M = {}

---@param buf integer
---@return boolean
function M.is_active(buf)
  local opts = config.current().map_view
  return opts.enabled
    and api.nvim_buf_is_valid(buf)
    and api.nvim_buf_line_count(buf) <= opts.max_lines
end

---@param parent integer
---@param bar? VVScrollbarBar
---@return integer
function M.resolve_width(parent, bar)
  local opts = config.current().map_view
  if opts.width ~= 'auto' then return opts.width end

  local container_width = api.nvim_win_get_width(parent)
  if bar and bar.win and api.nvim_win_is_valid(bar.win) then
    container_width = container_width + api.nvim_win_get_width(bar.win) + 1
  end

  local width = math.floor(container_width * opts.width_ratio + 0.5)
  return math.max(opts.min_width, math.min(width, opts.max_width))
end

---@param buf integer
---@param height integer
---@param width integer
---@param refresh fun()
---@return string[]
---@return string
function M.lines(buf, height, width, refresh)
  return require('vv-scrollbar.features.map_view.cache').get(
    buf,
    height,
    width,
    config.current().map_view,
    refresh
  )
end

---@param viewport table
---@param top_override? integer
---@return VVScrollbarMapLayout
function M.resolve_layout(viewport, top_override)
  return layout.resolve(viewport, config.current().map_view, top_override)
end

---@param map_layout VVScrollbarMapLayout
---@param line integer
---@return integer
function M.line_to_row(map_layout, line)
  return layout.line_to_row(map_layout, line)
end

---@param map_layout VVScrollbarMapLayout
---@param row integer
---@return integer
function M.row_to_line(map_layout, row)
  return layout.row_to_line(map_layout, row)
end

---@param buf integer
function M.clear(buf)
  require('vv-scrollbar.features.map_view.cache').clear(buf)
end

function M.clear_all()
  require('vv-scrollbar.features.map_view.cache').clear_all()
end

return M
