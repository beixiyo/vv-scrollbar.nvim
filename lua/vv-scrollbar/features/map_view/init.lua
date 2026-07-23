local api = vim.api

local config = require('vv-scrollbar.config')
local columns = require('vv-scrollbar.features.map_view.columns')
local layout = require('vv-scrollbar.features.map_view.layout')

local M = {}

---@param mode 'viewport'|'fit'
---@return VVScrollbarMapViewConfig
local function options_for(mode)
  local opts = config.current().map_view
  if opts.mode == mode then return opts end
  return vim.tbl_extend('force', opts, { mode = mode })
end

---@param win integer
---@return boolean
local function has_visible_closed_fold(win)
  if not vim.wo[win].foldenable then return false end
  return api.nvim_win_call(win, function()
    local line = vim.fn.line('w0')
    local last = vim.fn.line('w$')
    while line <= last do
      if vim.fn.foldclosed(line) ~= -1 then return true end
      line = line + 1
    end
    return false
  end)
end

---@param win integer
---@param buf integer
---@return 'viewport'|'fit'?
function M.resolve_mode(win, buf)
  local opts = config.current().map_view
  if not opts.enabled
      or not api.nvim_buf_is_valid(buf)
      or api.nvim_buf_line_count(buf) > opts.max_lines
  then
    return nil
  end
  if opts.mode == 'fit' then return 'fit' end

  local degradation = opts.degradation
  local fallback
  if vim.wo[win].diff and degradation.diff ~= 'viewport' then
    fallback = degradation.diff
  elseif has_visible_closed_fold(win) and degradation.folds ~= 'viewport' then
    fallback = degradation.folds
  elseif vim.wo[win].wrap and degradation.wrap ~= 'viewport' then
    fallback = degradation.wrap
  end
  if fallback == 'scrollbar' then return nil end
  return fallback or 'viewport'
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
---@param mode 'viewport'|'fit'
---@return string[]
---@return string
function M.lines(buf, height, width, refresh, mode)
  return require('vv-scrollbar.features.map_view.cache').get(
    buf,
    height,
    width,
    options_for(mode),
    refresh
  )
end

---@param viewport table
---@param top_override? integer
---@param mode 'viewport'|'fit'
---@return VVScrollbarMapLayout
function M.resolve_layout(viewport, top_override, mode)
  return layout.resolve(viewport, options_for(mode), top_override)
end

---@param track_width integer
---@return VVScrollbarMapColumns
function M.resolve_columns(track_width)
  return columns.resolve(track_width, config.current().map_view)
end

---@param map_columns VVScrollbarMapColumns
---@param marker_width integer
---@return integer
function M.marker_col(map_columns, marker_width)
  return columns.marker_col(
    map_columns,
    marker_width,
    config.current().map_view.marker_position
  )
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
