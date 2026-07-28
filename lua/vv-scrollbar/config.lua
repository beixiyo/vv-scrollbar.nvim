local M = {}

local defaults = require('vv-scrollbar.config.defaults')

---@type VVScrollbarConfig
local current = vim.deepcopy(defaults)

---@param value any
---@param fallback integer
---@return integer
local function positive_integer(value, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(math.floor(number), 1)
end

---@param value any
---@param fallback number
---@return number
local function positive_number(value, fallback)
  local number = tonumber(value)
  if not number or number <= 0 then return fallback end
  return number
end

---@param value any
---@param fallback integer
---@return integer
local function non_negative_integer(value, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(math.floor(number), 0)
end

---@param opts? VVScrollbarConfigOpts
---@return VVScrollbarConfig
function M.apply(opts)
  current = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

  -- nvim_set_hl() 存在 link 时会忽略 fg/bg，用户传具体样式就移除继承的语义链接
  if type(opts) == 'table' and type(opts.highlights) == 'table' then
    for name, override in pairs(opts.highlights) do
      if type(override) == 'table'
          and override.link == nil
          and type(current.highlights[name]) == 'table'
      then
        current.highlights[name].link = nil
      end
    end
  end

  current.width = positive_integer(current.width, defaults.width)
  current.min_thumb = positive_integer(current.min_thumb, defaults.min_thumb)

  current.map_view.min_width = positive_integer(
    current.map_view.min_width,
    defaults.map_view.min_width
  )

  current.map_view.max_width = math.max(
    positive_integer(current.map_view.max_width, defaults.map_view.max_width),
    current.map_view.min_width
  )

  if current.map_view.width ~= 'auto' then
    current.map_view.width = positive_integer(current.map_view.width, defaults.map_view.max_width)
  end

  current.map_view.width_ratio = positive_number(
    current.map_view.width_ratio,
    defaults.map_view.width_ratio
  )

  current.map_view.x_multiplier = positive_integer(
    current.map_view.x_multiplier,
    defaults.map_view.x_multiplier
  )

  current.map_view.y_multiplier = positive_integer(
    current.map_view.y_multiplier,
    defaults.map_view.y_multiplier
  )

  current.map_view.min_thumb = positive_integer(
    current.map_view.min_thumb,
    defaults.map_view.min_thumb
  )

  current.map_view.max_lines_per_dot = math.max(
    math.floor(
      tonumber(current.map_view.max_lines_per_dot) or defaults.map_view.max_lines_per_dot
    ),
    0
  )

  if current.map_view.tab_width ~= 'buffer' then
    current.map_view.tab_width = positive_integer(
      current.map_view.tab_width,
      vim.o.tabstop
    )
  end

  current.map_view.debounce_ms = math.max(
    math.floor(tonumber(current.map_view.debounce_ms) or defaults.map_view.debounce_ms),
    0
  )

  current.map_view.max_lines = positive_integer(
    current.map_view.max_lines,
    defaults.map_view.max_lines
  )

  if not vim.tbl_contains({ 'viewport', 'fit' }, current.map_view.mode) then
    current.map_view.mode = defaults.map_view.mode
  end
  current.map_view.large_file_behavior = 'scrollbar'
  if not vim.tbl_contains({ 'overlay', 'left', 'right' }, current.map_view.marker_layout) then
    current.map_view.marker_layout = defaults.map_view.marker_layout
  end
  current.map_view.marker_lane_width = positive_integer(
    current.map_view.marker_lane_width,
    defaults.map_view.marker_lane_width
  )
  if current.map_view.marker_position ~= 'left' then
    current.map_view.marker_position = 'right'
  end
  if type(current.cursor) ~= 'table' then current.cursor = vim.deepcopy(defaults.cursor) end
  if not vim.tbl_contains({ 'dots', 'line', 'horizontal', 'full', 'hidden' }, current.cursor.style) then
    current.cursor.style = defaults.cursor.style
  end
  if current.cursor.side ~= 'left' then
    current.cursor.side = 'right'
  end
  current.cursor.width = positive_integer(
    current.cursor.width,
    defaults.cursor.width
  )
  if type(current.cursor.symbol) ~= 'string'
      or current.cursor.symbol == ''
  then
    current.cursor.symbol = defaults.cursor.symbol
  end
  if type(current.show_on_short_buffers) ~= 'boolean' then
    current.show_on_short_buffers = defaults.show_on_short_buffers
  end
  if type(current.interaction) ~= 'table' then
    current.interaction = vim.deepcopy(defaults.interaction)
  end
  local global_interaction = current.interaction
  local default_global_interaction = defaults.interaction
  if global_interaction.right_click ~= false
      and global_interaction.right_click ~= 'toggle_view'
      and type(global_interaction.right_click) ~= 'function'
  then
    global_interaction.right_click = default_global_interaction.right_click
  end
  if not vim.tbl_contains({ 'follow', 'keep' }, global_interaction.cursor_on_drag) then
    global_interaction.cursor_on_drag = default_global_interaction.cursor_on_drag
  end
  if not vim.tbl_contains({ 'center', 'top', 'scrollbar' }, global_interaction.marker_click) then
    global_interaction.marker_click = default_global_interaction.marker_click
  end
  local interaction = current.map_view.interaction
  local default_interaction = defaults.map_view.interaction
  if type(interaction.edge_scroll) ~= 'boolean' then
    interaction.edge_scroll = default_interaction.edge_scroll
  end
  interaction.edge_margin = non_negative_integer(
    interaction.edge_margin,
    default_interaction.edge_margin
  )
  interaction.edge_speed = positive_integer(
    interaction.edge_speed,
    default_interaction.edge_speed
  )
  interaction.edge_interval = positive_integer(
    interaction.edge_interval,
    default_interaction.edge_interval
  )
  if type(interaction.snap_to_edges) ~= 'boolean' then
    interaction.snap_to_edges = default_interaction.snap_to_edges
  end
  local degradation = current.map_view.degradation
  local default_degradation = defaults.map_view.degradation
  for _, key in ipairs({ 'folds', 'wrap', 'diff' }) do
    if not vim.tbl_contains({ 'viewport', 'fit', 'scrollbar' }, degradation[key]) then
      degradation[key] = default_degradation[key]
    end
  end
  current.map_view.syntax = require('vv-scrollbar.config.syntax').normalize(
    current.map_view.syntax,
    defaults.map_view.syntax
  )
  current.right_offset = math.max(
    math.floor(tonumber(current.right_offset) or defaults.right_offset),
    0
  )
  current.throttle_ms = math.max(
    math.floor(tonumber(current.throttle_ms) or defaults.throttle_ms),
    0
  )
  return current
end

---@return VVScrollbarConfig
function M.current()
  return current
end

---@return VVScrollbarConfig
function M.get()
  return vim.deepcopy(current)
end

return M
