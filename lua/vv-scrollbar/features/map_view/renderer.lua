local bit = require('bit')

local api = vim.api
local fn = vim.fn

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

---@param buf integer
---@param height integer
---@param width integer
---@param opts VVScrollbarMapViewConfig
---@return string[]
function M.render(buf, height, width, opts)
  if height <= 0 or width <= 0 or not api.nvim_buf_is_valid(buf) then return {} end

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local line_count = #lines
  local vertical_points = height * 4
  local x_multiplier = opts.x_multiplier
  local max_source_col = width * 2 * x_multiplier
  local tab_width = opts.tab_width == 'buffer'
      and math.max(vim.bo[buf].tabstop, 1)
    or opts.tab_width

  local bitmap = {}
  for row = 1, height do
    bitmap[row] = {}
    for col = 1, width do bitmap[row][col] = 0 end
  end

  for map_y = 0, vertical_points - 1 do
    local start_row = math.ceil(map_y * line_count / vertical_points) + 1
    local end_row = math.ceil((map_y + 1) * line_count / vertical_points)
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
      for _, code in ipairs(codepoints(line)) do
        local width
        if code == 0x09 then
          width = tab_width - (display_col % tab_width)
        else
          width = display_cell_width(code)
        end

        if display_col >= max_source_col then break end

        if width > 0 and (opts.include_whitespace or not is_whitespace(code)) then
          local last_col = math.min(display_col + width - 1, max_source_col - 1)
          for source_col = display_col, last_col do
            local map_x = math.floor(source_col / x_multiplier)
            local map_col = math.floor(map_x / 2) + 1
            local dot_row = map_y % 4
            local dot_col = map_x % 2
            bitmap[map_row][map_col] = add_dot(bitmap[map_row][map_col], dot_row, dot_col)
          end
        end

        display_col = display_col + width
      end
    end

    ::continue_map_row::
  end

  local result = {}
  for row = 1, height do
    local chars = {}
    for col = 1, width do chars[col] = bitmap_code(bitmap[row][col]) end
    result[row] = fn.list2str(chars)
  end
  return result
end

return M
