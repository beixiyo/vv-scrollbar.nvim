local config = require('vv-scrollbar.config')

local M = {}

function M.setup()
  local highlights = config.current().highlights

  require('vv-utils.git').register_hl()
  require('vv-utils.hl').register('vv-scrollbar.hl', {
    VVScrollbarTrack = highlights.track,
    VVScrollbarSeparator = highlights.separator,
    VVScrollbarMapView = highlights.map_view,
    VVScrollbarMapCursor = highlights.map_cursor,
    VVScrollbarThumb = highlights.thumb,
    VVScrollbarHover = highlights.hover,
    VVScrollbarCursor = highlights.cursor,
    VVScrollbarSearch = highlights.search,
    VVScrollbarMark = highlights.mark,
    VVScrollbarQuickfix = highlights.quickfix,
    VVScrollbarDiagnosticError = highlights.diag_error,
    VVScrollbarDiagnosticWarn = highlights.diag_warn,
    VVScrollbarDiagnosticInfo = highlights.diag_info,
    VVScrollbarDiagnosticHint = highlights.diag_hint,
  }, { default = false })
end

return M
