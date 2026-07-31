---@class VVScrollbar.State
---@field enabled boolean
---@field did_setup boolean
---@field bars table<integer, VVScrollbar.Bar>
---@field git_marks table<integer, vv-utils.git.DiffLineSets>
---@field git_pending table<integer, boolean>
---@field dragging? VVScrollbar.DragState
---@field augroup? integer
---@field refresh_throttled? fun()
---@field refresh_cancel? fun()
---@field layout_suspend_depth integer

return {}
