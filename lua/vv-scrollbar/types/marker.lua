---@diagnostic disable: duplicate-doc-field
---@class VVScrollbar.MarkerHit
---@diagnostic disable-next-line: duplicate-doc-field
---@field start_col integer
---@diagnostic disable-next-line: duplicate-doc-field
---@field end_col integer
---@diagnostic disable-next-line: duplicate-doc-field
---@field source_line integer

---@class VVScrollbar.RelativeMarkerHit
---@diagnostic disable-next-line: duplicate-doc-field
---@field start_col integer
---@diagnostic disable-next-line: duplicate-doc-field
---@field end_col integer
---@diagnostic disable-next-line: duplicate-doc-field
---@field source_line integer

---@class VVScrollbar.Marker
---@diagnostic disable-next-line: duplicate-doc-field
---@field text? string
---@diagnostic disable-next-line: duplicate-doc-field
---@field hl? string
---@diagnostic disable-next-line: duplicate-doc-field
---@field chunks? string[][]
---@diagnostic disable-next-line: duplicate-doc-field
---@field priority integer
---@diagnostic disable-next-line: duplicate-doc-field
---@field source_line? integer
---@diagnostic disable-next-line: duplicate-doc-field
---@field hits? VVScrollbar.RelativeMarkerHit[]

return {}
