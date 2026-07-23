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
---@field map_mode? 'viewport'|'fit'
---@field map_layout? VVScrollbarMapLayout
---@field map_columns? VVScrollbarMapColumns
---@field parent_separator_hl? { present: boolean, target?: string }

---@class VVScrollbarDragState
---@field parent integer
---@field offset integer
---@field moved boolean
---@field click_line? integer
---@field map_top? integer
---@field mouse_row? integer
---@field edge_pending? boolean
---@field cursor_anchor? VVScrollbarCursorAnchor
---@field last_source_line? integer
---@field last_bar_row? integer

---@class VVScrollbarCursorAnchor
---@field screen_row integer
---@field curswant integer
---@field scrolloff integer

---@class VVScrollbarViewportDragResult
---@field top_row integer
---@field source_line integer
---@field repeat_edge boolean
---@field snapped? 'top'|'bottom'

---@class VVScrollbarMapLayout
---@field mode 'viewport'|'fit'
---@field line_count integer
---@field window_height integer
---@field content_height integer
---@field top_row integer
---@field thumb_row integer
---@field thumb_height integer
---@field rows_per_cell number

---@class VVScrollbarMapColumns
---@field mode 'overlay'|'left'|'right'
---@field track_width integer
---@field map_start_col integer
---@field map_width integer
---@field marker_start_col integer
---@field marker_width integer

---@class VVScrollbarMapHighlight
---@field start_col integer
---@field end_col integer
---@field hl_group string

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
