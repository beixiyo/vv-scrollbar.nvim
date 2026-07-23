local bit = require('bit')

local api = vim.api
local fn = vim.fn
local syntax = require('vv-scrollbar.features.map_view.syntax')

local M = {}

local dot_bits = {
  { 0, 3 },
  { 1, 4 },
  { 2, 5 },
  { 6, 7 },
}

---@param bitmap integer
---@return integer
local function bitmap_code(bitmap)
  if bitmap == 0 then return 0x20 end
  return 0x2800 + bitmap
end

---@param line string
---@return integer[]
local function codepoints(line)
  local ok, result = pcall(fn.str2list, line)
  if ok then return result end
  return fn.blob2list(line)
end

---@param code integer
---@return boolean
local function is_whitespace(code)
  return code == 0x09
    or code == 0x20
    or code == 0xA0
    or code == 0x1680
    or (code >= 0x2000 and code <= 0x200A)
    or code == 0x202F
    or code == 0x205F
    or code == 0x3000
end

---@param bitmap integer
---@param dot_row integer
---@param dot_col integer
---@return integer
local function add_dot(bitmap, dot_row, dot_col)
  return bit.bor(bitmap, bit.lshift(1, dot_bits[dot_row + 1][dot_col + 1]))
end

---@param colors table
---@param row integer
---@param col integer
---@param hl_group string
local function add_color(colors, row, col, hl_group)
  colors[row] = colors[row] or {}
  local cell = colors[row][col]
  if not cell then
    cell = { counts = {}, best = hl_group, best_count = 0 }
    colors[row][col] = cell
  end

  local count = (cell.counts[hl_group] or 0) + 1
  cell.counts[hl_group] = count
  if count > cell.best_count then
    cell.best = hl_group
    cell.best_count = count
  end
end

---@param code integer
---@return integer
local function display_cell_width(code)
  if code < 0x80 then return 1 end
  return fn.strdisplaywidth(fn.nr2char(code))
end

---@param start_row integer
---@param end_row integer
---@param sample_count integer
---@param sample integer
---@return integer
local function sample_row(start_row, end_row, sample_count, sample)
  if sample_count <= 1 then return start_row end
  local ratio = sample / (sample_count - 1)
  return math.floor(start_row + (end_row - start_row) * ratio + 0.5)
end

---@param map_y integer
---@param line_count integer
---@param vertical_points integer
---@param opts VVScrollbarMapViewConfig
---@return integer
---@return integer
local function source_range(map_y, line_count, vertical_points, opts)
  if opts.mode == 'viewport' then
    local start_row = map_y * opts.y_multiplier + 1
    return start_row, math.min(start_row + opts.y_multiplier - 1, line_count)
  end

  return math.ceil(map_y * line_count / vertical_points) + 1,
    math.ceil((map_y + 1) * line_count / vertical_points)
end

---@param buf integer
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@return string[]
---@return table<integer,VVScrollbarMapHighlight[]>
function M.render(buf, height, width, opts)
  if height <= 0 or width <= 0 or not api.nvim_buf_is_valid(buf) then return {}, {} end

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local resolve_syntax = syntax.resolver(buf, lines, opts.syntax)
  local line_count = #lines
  local vertical_points = height * 4
  local x_multiplier = opts.x_multiplier
  local max_source_col = width * 2 * x_multiplier
  local tab_width = opts.tab_width == 'buffer'
      and math.max(vim.bo[buf].tabstop, 1)
    or opts.tab_width

  local bitmap = {}
  local colors = {}
  for row = 1, height do
    bitmap[row] = {}
    for col = 1, width do bitmap[row][col] = 0 end
  end

  for map_y = 0, vertical_points - 1 do
    local start_row, end_row = source_range(map_y, line_count, vertical_points, opts)
    local group_size = end_row - start_row + 1
    if group_size <= 0 then goto continue_map_row end

    local sample_count = opts.max_lines_per_dot == 0
        and group_size
      or math.min(group_size, opts.max_lines_per_dot)
    local map_row = math.floor(map_y / 4) + 1

    for sample = 0, sample_count - 1 do
      local source_row = sample_row(start_row, end_row, sample_count, sample)
      local line = lines[source_row]
      local display_col = 0
      local byte_col = 0
      for _, code in ipairs(codepoints(line)) do
        local width
        if code == 0x09 then
          width = tab_width - (display_col % tab_width)
        else
          width = display_cell_width(code)
        end

        if display_col >= max_source_col then break end

        if width > 0 and (opts.include_whitespace or not is_whitespace(code)) then
          local hl_group = resolve_syntax(source_row - 1, byte_col)
          local last_col = math.min(display_col + width - 1, max_source_col - 1)
          for source_col = display_col, last_col do
            local map_x = math.floor(source_col / x_multiplier)
            local map_col = math.floor(map_x / 2) + 1
            local dot_row = map_y % 4
            local dot_col = map_x % 2
            bitmap[map_row][map_col] = add_dot(bitmap[map_row][map_col], dot_row, dot_col)
            if hl_group then add_color(colors, map_row, map_col, hl_group) end
          end
        end

        display_col = display_col + width
        byte_col = byte_col + #fn.nr2char(code)
      end
    end

    ::continue_map_row::
  end

  local result = {}
  local highlights = {}
  for row = 1, height do
    local chars = {}
    for col = 1, width do chars[col] = bitmap_code(bitmap[row][col]) end
    result[row] = fn.list2str(chars)

    local spans = {}
    local active
    local span_start = 1
    for col = 1, width + 1 do
      local cell = colors[row] and colors[row][col]
      local hl_group = cell and cell.best or nil
      if hl_group ~= active then
        if active then
          spans[#spans + 1] = {
            start_col = span_start - 1,
            end_col = col - 1,
            hl_group = active,
          }
        end
        active = hl_group
        span_start = col
      end
    end
    if #spans > 0 then highlights[row] = spans end
  end
  return result, highlights
end

return M
