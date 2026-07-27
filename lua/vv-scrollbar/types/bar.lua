---@class VVScrollbar.Bar
---@field win integer
---@field buf integer
---@field parent integer
---@field thumb_row integer
---@field thumb_height integer
---@field height integer
---@field width integer
---@field track_width integer
---@field content_id? string
---@field content_tick? integer
---@field row_markers? table<integer, VVScrollbar.Marker>
---@field marker_hits? table<integer, VVScrollbar.MarkerHit[]>
---@field map_mode? 'viewport'|'fit'
---@field map_layout? VVScrollbar.MapLayout
---@field map_columns? VVScrollbar.MapColumns
---@field parent_separator_hl? { present: boolean, target?: string }

return {}
