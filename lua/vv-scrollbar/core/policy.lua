-- 刷新前的低成本准入：只读取 buffer 元数据，不扫描文本、折叠或语法树
local api = vim.api
local config = require('vv-scrollbar.config')
local bigfile = require('vv-utils.bigfile')

local M = {}

---判断当前窗口是否应使用源码行数投影的轻量滚动条
---@param win integer
---@return boolean
function M.is_lightweight(win)
  local buf = api.nvim_win_get_buf(win)
  local cfg = config.current()
  local line_count = api.nvim_buf_line_count(buf)

  if line_count > cfg.map_view.max_lines or bigfile.is_big(buf) then return true end
  if not cfg.lightweight then return false end

  local ok, result = pcall(cfg.lightweight, {
    win = win,
    buf = buf,
    filetype = vim.bo[buf].filetype,
    line_count = line_count,
    byte_count = math.max(api.nvim_buf_get_offset(buf, line_count), 0),
  })

  if not ok then
    vim.notify_once('vv-scrollbar: lightweight failed: ' .. tostring(result), vim.log.levels.ERROR)
    -- 策略异常也不能掉回可能阻塞的全文计算
    return true
  end

  return result == true
end

return M
