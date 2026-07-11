---@class VVScrollbarBar
---@field win integer
---@field buf integer
---@field parent integer
---@field thumb_row integer
---@field thumb_height integer
---@field height integer
---@field width integer
---@field track_width integer

---@class VVScrollbarDragState
---@field parent integer
---@field offset integer
---@field moved boolean

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
