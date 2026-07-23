---@class VVScrollbarMarkerHit
---@field start_col integer
---@field end_col integer
---@field source_line integer

---@class VVScrollbarRelativeMarkerHit
---@field start_col integer
---@field end_col integer
---@field source_line integer

---@class VVScrollbarMarker
---@field text? string
---@field hl? string
---@field chunks? string[][]
---@field priority integer
---@field fill_width? boolean
---@field source_line? integer
---@field kind? string
---@field hits? VVScrollbarRelativeMarkerHit[]

---@class VVScrollbarBar
---@field win integer
---@field buf integer
---@field parent integer
---@field thumb_row integer
---@field thumb_height integer
---@field height integer
---@field width integer
---@field track_width integer
---@field content_id? string
---@field row_markers? table<integer, VVScrollbarMarker>
---@field marker_hits? table<integer, VVScrollbarMarkerHit[]>
---@field parent_separator_hl? { present: boolean, target?: string }

---@class VVScrollbarDragState
---@field parent integer
---@field offset integer
---@field moved boolean

local M = {
  enabled = false,
  did_setup = false,
  bars = {},
  git_marks = {}, --- @type table<integer, vv-utils.git.DiffLineSets>
  git_pending = {},
  dragging = nil,
  augroup = nil,
  refresh_throttled = nil,
  refresh_cancel = nil,
}

return M
