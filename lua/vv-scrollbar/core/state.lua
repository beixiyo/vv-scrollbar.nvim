---@type VVScrollbar.State
local M = {
  enabled = false,
  did_setup = false,
  bars = {},
  git_marks = {},
  git_pending = {},
  dragging = nil,
  augroup = nil,
  refresh_throttled = nil,
  refresh_cancel = nil,
}

return M
