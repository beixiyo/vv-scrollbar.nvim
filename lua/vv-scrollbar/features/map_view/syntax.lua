-- Tree-sitter 高亮片段收集、过载回退与源码位置颜色查询

local api = vim.api

local palette = require('vv-scrollbar.features.map_view.palette')

local M = {}

---@class VVScrollbarSyntaxInterval
---@field start_col integer
---@field end_col integer
---@field hl_group string
---@field priority integer
---@field sequence integer

---@param buf integer
---@param opts VVScrollbarMapViewSyntaxConfig?
---@return 'syntax'|'mono'|'scrollbar'
function M.behavior(buf, opts)
  if not opts or not opts.enabled or not api.nvim_buf_is_valid(buf) then return 'mono' end

  local line_count = api.nvim_buf_line_count(buf)
  local exceeds_lines = opts.max_lines > 0 and line_count > opts.max_lines
  local byte_count = math.max(api.nvim_buf_get_offset(buf, line_count), 0)
  local exceeds_bytes = opts.max_bytes > 0 and byte_count > opts.max_bytes
  if exceeds_lines or exceeds_bytes then return opts.fallback end

  return 'syntax'
end

---@param capture string
---@param lang string
---@param capture_map table<string,string|false>
---@return string?
local function capture_group(capture, lang, capture_map)
  local override = capture_map[capture]
  if override == nil then override = capture_map[capture:match('^[^.]+') or capture] end
  if override == false then return nil end

  return palette.resolve(override or ('@' .. capture .. '.' .. lang))
end

---@param lines string[]
---@param intervals table<integer,VVScrollbarSyntaxInterval[]>
---@param start_row integer
---@param start_col integer
---@param end_row integer
---@param end_col integer
---@param hl_group string
---@param priority integer
---@param sequence integer
local function add_intervals(
  lines,
  intervals,
  start_row,
  start_col,
  end_row,
  end_col,
  hl_group,
  priority,
  sequence
)
  local last_row = end_col == 0 and end_row - 1 or end_row
  last_row = math.min(last_row, #lines - 1)

  for row = math.max(start_row, 0), last_row do
    local line = lines[row + 1]
    local from = row == start_row and start_col or 0
    local to = row == end_row and end_col or #line
    if to > from then
      intervals[row + 1] = intervals[row + 1] or {}
      intervals[row + 1][#intervals[row + 1] + 1] = {
        start_col = from,
        end_col = to,
        hl_group = hl_group,
        priority = priority,
        sequence = sequence,
      }
    end
  end
end

---@param buf integer
---@param lines string[]
---@param opts VVScrollbarMapViewSyntaxConfig?
---@return fun(row:integer, col:integer):string?
function M.resolver(buf, lines, opts)
  if M.behavior(buf, opts) ~= 'syntax' then return function() end end

  local ok, intervals = pcall(function()
    local parser = vim.treesitter.get_parser(buf)
    parser:parse(true)

    local by_line = {}
    -- 统计 highlight query 逐项返回的 capture，不是颜色数或 Braille 点数
    local capture_count = 0
    local sequence = 0
    local coloring_limit_exceeded = false
    -- 从 parse 后开始计时：只限制 capture 遍历、颜色解析和源码区间生成
    local started_at = vim.uv.hrtime()

    parser:for_each_tree(function(tree, language_tree)
      if coloring_limit_exceeded or not tree then return end

      local lang = language_tree:lang()
      local query = vim.treesitter.query.get(lang, 'highlights')
      if not query then return end

      local root = tree:root()
      for id, node, metadata in query:iter_captures(root, buf, 0, #lines) do
        metadata = metadata or {}
        capture_count = capture_count + 1
        local exceeded_captures =
          (opts.max_captures or 0) > 0 and capture_count > opts.max_captures
        local exceeded_time = (opts.max_time_ms or 0) > 0
          and (vim.uv.hrtime() - started_at) / 1e6 > opts.max_time_ms
        if exceeded_captures or exceeded_time then
          coloring_limit_exceeded = true
          break
        end

        local capture = query.captures[id]
        local hl_group = capture and capture_group(capture, lang, opts.capture_map)
        if hl_group then
          sequence = sequence + 1
          local capture_metadata = metadata[id] or {}
          local priority = tonumber(metadata.priority or capture_metadata.priority) or 100
          local start_row, start_col, end_row, end_col =
            vim.treesitter.get_range(node, buf, capture_metadata)
          if type(start_row) == 'table' then
            local range = start_row
            if #range >= 6 then
              start_row, start_col, end_row, end_col =
                range[1], range[2], range[4], range[5]
            else
              start_row, start_col, end_row, end_col = unpack(range)
            end
          end
          add_intervals(
            lines,
            by_line,
            start_row,
            start_col,
            end_row,
            end_col,
            hl_group,
            priority,
            sequence
          )
        end
      end
    end)

    -- 超限时不能保留不完整的局部颜色，否则颜色边界会随处理进度变化
    if coloring_limit_exceeded then return {} end
    return by_line
  end)

  if not ok then intervals = {} end

  return function(row, col)
    local row_intervals = intervals[row + 1]
    if not row_intervals then return nil end

    local selected
    for _, interval in ipairs(row_intervals) do
      if col >= interval.start_col and col < interval.end_col
          and (not selected
            or interval.priority > selected.priority
            or (interval.priority == selected.priority
              and interval.sequence > selected.sequence))
      then
        selected = interval
      end
    end
    return selected and selected.hl_group or nil
  end
end

function M.clear_palette()
  palette.clear()
end

return M
