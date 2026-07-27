---@class VVScrollbar.CursorAnchor
---@field screen_row integer
---@field curswant integer
---@field scrolloff integer

---@class VVScrollbar.DragState
---@field parent integer
---@field offset integer
---@field moved boolean
---@field click_line? integer
---@field map_top? integer
---@field mouse_row? integer
---@field edge_pending? boolean
---@field cursor_anchor? VVScrollbar.CursorAnchor
---@field last_source_line? integer
---@field last_bar_row? integer

---@class VVScrollbar.ViewportDragResult
---@field top_row integer
---@field source_line integer
---@field repeat_edge boolean
---@field snapped? 'top'|'bottom'

return {}
