local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
local utils_root = vim.fn.fnamemodify(root, ':h') .. '/vv-utils.nvim'

vim.opt.runtimepath:prepend(utils_root)
vim.opt.runtimepath:prepend(root)

local api = vim.api

local source_lines = {}
for index = 1, 400 do
  source_lines[index] = ('local value_%d = function(argument) return argument + %d end'):format(
    index,
    index
  )
end
local parent = api.nvim_get_current_win()
local original_buf = api.nvim_get_current_buf()
local source_buf = api.nvim_create_buf(false, false)
api.nvim_buf_set_lines(source_buf, 0, -1, false, source_lines)
api.nvim_win_set_buf(parent, source_buf)
vim.wo[parent].wrap = false
api.nvim_set_option_value(
  'winhighlight',
  'Normal:Normal,CursorLine:CursorLine',
  { win = parent, scope = 'local' }
)
local original_winhighlight = api.nvim_get_option_value('winhighlight', { win = parent })

local markers = {
  diagnostics = false,
  git = false,
  search = false,
  marks = false,
  quickfix = false,
  cursor = false,
}
local scrollbar = require('vv-scrollbar')
scrollbar.setup({
  throttle_ms = 0,
  markers = markers,
  highlights = {
    map_cursor = { fg = '#abcdef' },
    separator = { fg = '#123456', bg = '#123456' },
  },
})

local view = require('vv-scrollbar.core.view')
local state = require('vv-scrollbar.core.state')
view.refresh()

local bar = state.bars[parent]
assert(bar and api.nvim_win_is_valid(bar.win), 'default map view did not create a scrollbar')
local visual_guards = api.nvim_get_autocmds({ event = 'ModeChanged', buffer = bar.buf })
assert(
  vim.iter(visual_guards):any(function(autocmd)
    return autocmd.desc == 'vv-utils: 面板禁止鼠标拖拽 / 多击进入 visual'
  end),
  'scrollbar buffer did not install the nofile visual-mode guard'
)
assert(scrollbar.get_config().map_view.enabled, 'map view is not enabled by default')
assert(scrollbar.get_config().map_view.mode == 'viewport', 'viewport mode is not the default')
assert(bar.track_width >= 8 and bar.track_width <= 16, 'auto map width escaped configured bounds')
assert(
  bar.map_layout and bar.map_layout.content_height > bar.height,
  'long buffer map height is still coupled to the window height'
)
assert(
  api.nvim_get_option_value('winhighlight', { win = parent })
    == original_winhighlight .. ',WinSeparator:VVScrollbarSeparator',
  'map split separator did not use the configurable scrollbar highlight'
)
assert(
  api.nvim_get_hl(0, { name = 'VVScrollbarMapCursor' }).fg == 0xabcdef,
  'custom map cursor color was shadowed by its default semantic link'
)
local separator_hl = api.nvim_get_hl(0, { name = 'VVScrollbarSeparator' })
assert(
  separator_hl.fg == 0x123456 and separator_hl.bg == 0x123456,
  'custom separator color was not registered'
)
assert(
  api.nvim_get_hl(0, { name = 'VVScrollbarMapView', link = true }).link == 'Comment',
  'default map view highlight does not follow Comment'
)
assert(
  api.nvim_get_hl(0, { name = 'VVScrollbarThumb', link = true }).link == 'CursorLine',
  'default thumb highlight does not follow CursorLine'
)
assert(
  api.nvim_get_hl(0, { name = 'VVScrollbarActive', link = true }).link == 'Visual',
  'default active highlight does not follow Visual'
)

local map_lines = api.nvim_buf_get_lines(bar.buf, 0, -1, false)
assert(
  table.concat(map_lines):find('[^ ]'),
  'map view buffer did not contain a visible code preview'
)

api.nvim_win_call(parent, function() vim.cmd('normal! 201Gzt') end)
view.refresh()
bar = state.bars[parent]
assert(bar.map_layout.top_row > 0, 'source scrolling did not move the map viewport')
assert(
  bar.thumb_row > 0 and bar.thumb_row + bar.thumb_height < bar.height,
  'middle source viewport did not keep the map thumb visible'
)

api.nvim_win_call(parent, function() vim.cmd('normal! Gzt') end)
view.refresh()
bar = state.bars[parent]
assert(
  bar.map_layout.top_row == bar.map_layout.content_height - bar.height,
  'file end did not anchor the map viewport end'
)
assert(
  bar.thumb_row + bar.thumb_height == bar.height,
  'file end did not anchor the map thumb'
)

api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
view.refresh()

local blank_buf = api.nvim_create_buf(false, false)
local blank_lines = {}
for index = 1, 400 do blank_lines[index] = '' end
api.nvim_buf_set_lines(blank_buf, 0, -1, false, blank_lines)
assert(
  api.nvim_buf_get_changedtick(blank_buf) == api.nvim_buf_get_changedtick(source_buf),
  'buffer switch regression fixture does not share the same changedtick'
)

api.nvim_win_set_buf(parent, blank_buf)
view.refresh()
local blank_map = table.concat(api.nvim_buf_get_lines(bar.buf, 0, -1, false))
assert(not blank_map:find('[^ ]'), 'blank source buffer produced code-map points')

api.nvim_win_set_buf(parent, source_buf)
view.refresh()
local restored_map = table.concat(api.nvim_buf_get_lines(bar.buf, 0, -1, false))
assert(
  restored_map:find('[^ ]'),
  'same-changedtick buffer switch reused another buffer map'
)
api.nvim_buf_delete(blank_buf, { force = true })

local runtime_config = scrollbar.get_config()
runtime_config.markers.git = true
runtime_config.markers.cursor = true
runtime_config.map_view.marker_layout = 'right'
runtime_config.cursor.style = 'line'
runtime_config.cursor.symbol = '▕'
scrollbar.setup(runtime_config)
local geometry = require('vv-scrollbar.core.geometry')
local projection = require('vv-scrollbar.core.projection')
local map_view = require('vv-scrollbar.features.map_view')

state.git_marks[source_buf] = {
  staged = { [1] = 'A' },
  unstaged = {},
}
view.refresh()
bar = state.bars[parent]
local layer_namespace = api.nvim_get_namespaces()['vv-scrollbar']
local function empty_git_lane_uses(expected_hl)
  local extmarks = api.nvim_buf_get_extmarks(
    bar.buf,
    layer_namespace,
    0,
    -1,
    { details = true }
  )
  for _, extmark in ipairs(extmarks) do
    local virt_text = extmark[4].virt_text
    if virt_text
        and virt_text[1] and virt_text[1][2] == 'VVGitAdded'
        and virt_text[2] and virt_text[2][1] == ' '
    then
      return virt_text[2][2] == expected_hl
    end
  end
  return false
end

assert(
  empty_git_lane_uses('VVScrollbarThumb'),
  'empty Git lane cut a hole in the thumb background'
)
assert(
  bar.row_markers[0].chunks[2][2] == 'VVScrollbarTrack',
  'thumb composition mutated cached Git marker chunks'
)
state.dragging = {
  parent = parent,
  offset = 0,
  moved = false,
  map_top = bar.map_layout.top_row,
}
view.refresh()
bar = state.bars[parent]
assert(
  empty_git_lane_uses('VVScrollbarActive'),
  'empty Git lane cut a hole in the active background before dragging'
)
state.dragging = nil
view.refresh()

api.nvim_win_call(parent, function() vim.cmd('normal! 201Gzt') end)
state.git_marks[source_buf] = {
  staged = { [201] = 'A' },
  unstaged = { [400] = 'D' },
}
view.refresh()
bar = state.bars[parent]
local visible_git_row = map_view.line_to_row(bar.map_layout, 201)
assert(
  visible_git_row ~= projection.line_to_row(201, #source_lines, bar.height),
  'long-file marker projection fixture does not distinguish map and classic coordinates'
)
assert(
  bar.row_markers[visible_git_row]
    and bar.row_markers[visible_git_row].hits[1].source_line == 201,
  'long-file Git marker did not align with its visible map row'
)
for _, marker in pairs(bar.row_markers) do
  for _, hit in ipairs(marker.hits or {}) do
    assert(hit.source_line ~= 400, 'off-slice Git marker remained visible in map view')
  end
end

api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
view.refresh()
bar = state.bars[parent]

local staged_line
local unstaged_line
for line = 6, #source_lines do
  local previous_row = map_view.line_to_row(bar.map_layout, line - 1)
  local current_row = map_view.line_to_row(bar.map_layout, line)
  if previous_row == current_row then
    staged_line = line - 1
    unstaged_line = line
    break
  end
end
assert(staged_line and unstaged_line, 'Git lane fixture did not find a shared projected row')

state.git_marks[source_buf] = {
  staged = { [1] = 'A', [staged_line] = 'A' },
  unstaged = { [1] = 'C', [unstaged_line] = 'D' },
}
api.nvim_win_set_cursor(parent, { 1, 0 })
view.refresh()
bar = state.bars[parent]

local git_row = map_view.line_to_row(bar.map_layout, unstaged_line)
local git_marker = bar.row_markers[git_row]
assert(git_marker and #git_marker.hits == 2, 'Git marker lost its independent hit targets')

local git_hits = bar.marker_hits[git_row]
assert(git_hits and #git_hits == 2, 'Git tracks lost their independent hit targets')
assert(git_hits[1].start_col == bar.track_width - 2, 'Git tracks are not right aligned')
local bar_left = vim.fn.win_screenpos(bar.win)[2]
assert(
  view.marker_at(bar, git_row, bar_left + git_hits[1].start_col).source_line == staged_line,
  'staged Git marker did not retain its exact source line'
)
assert(
  view.marker_at(bar, git_row, bar_left + git_hits[2].start_col).source_line == unstaged_line,
  'unstaged Git marker did not retain its exact source line'
)
assert(
  view.marker_at(bar, git_row, bar_left) == nil,
  'Git marker hit area still covers the left-side code map'
)

local cursor_row = map_view.line_to_row(bar.map_layout, 1)
assert(
  bar.row_markers[cursor_row] and bar.row_markers[cursor_row].hits,
  'map cursor still displaced a Git marker on the same projected row'
)

api.nvim_win_call(parent, function() vim.cmd('normal! ggzt') end)
geometry.scroll_to_line(parent, unstaged_line, 'center')
local centered_top = vim.fn.line('w0', parent)
local centered_bottom = vim.fn.line('w$', parent)
assert(
  centered_top <= unstaged_line and centered_bottom >= unstaged_line,
  'exact marker navigation did not reveal its source line'
)
geometry.set_cursor_line(parent, unstaged_line)
assert(
  api.nvim_win_get_cursor(parent)[1] == unstaged_line,
  'exact marker navigation did not place the source cursor'
)

local namespace = api.nvim_get_namespaces()['vv-scrollbar']
local extmarks = api.nvim_buf_get_extmarks(bar.buf, namespace, 0, -1, { details = true })
local map_hl = api.nvim_get_hl_id_by_name('VVScrollbarMapView')
local thumb_hl = api.nvim_get_hl_id_by_name('VVScrollbarThumb')
local found_map = false
local found_thumb = false
local found_right_git = false
local found_cursor_line = false
local found_cursor_span = false
for _, extmark in ipairs(extmarks) do
  found_map = found_map
    or extmark[4].hl_group == map_hl
    or extmark[4].hl_group == 'VVScrollbarMapView'
  found_thumb = found_thumb
    or extmark[4].hl_group == thumb_hl
    or extmark[4].hl_group == 'VVScrollbarThumb'
  found_cursor_span = found_cursor_span
    or extmark[4].hl_group == api.nvim_get_hl_id_by_name('VVScrollbarMapCursor')
    or extmark[4].hl_group == 'VVScrollbarMapCursor'
  local virt_text = extmark[4].virt_text
  if virt_text then
    for _, chunk in ipairs(virt_text) do
      found_cursor_line = found_cursor_line or chunk[2] == 'VVScrollbarMapCursor'
      if chunk[2] == 'VVGitDeleted' then
        found_right_git = extmark[4].virt_text_win_col == bar.track_width - 2
      end
    end
  end
end
assert(found_map, 'map view foreground highlight was not applied')
assert(found_thumb, 'thumb background was not layered over the map')
assert(found_right_git, 'Git marker was not floated on the right edge')
assert(found_cursor_line, 'map cursor did not render its configured slim line')
assert(not found_cursor_span, 'slim cursor line still recolored the map dots')

api.nvim_set_hl(0, 'VVScrollbarTestSeparator', { fg = '#654321' })
local latest_winhighlight = 'Normal:Normal,WinSeparator:VVScrollbarTestSeparator'
api.nvim_set_option_value(
  'winhighlight',
  latest_winhighlight,
  { win = parent, scope = 'local' }
)
view.refresh()
local active_winhighlight = api.nvim_get_option_value('winhighlight', { win = parent })
assert(
  active_winhighlight:find('Normal:Normal', 1, true)
    and active_winhighlight:find('WinSeparator:VVScrollbarSeparator', 1, true),
  'scrollbar lifetime replaced unrelated parent window highlights: ' .. active_winhighlight
)
scrollbar.disable()
local restored_winhighlight = api.nvim_get_option_value('winhighlight', { win = parent })
assert(
  restored_winhighlight == latest_winhighlight,
  ('disabling the scrollbar did not restore the parent window highlight: %q ~= %q')
    :format(restored_winhighlight, latest_winhighlight)
)
api.nvim_win_set_buf(parent, original_buf)
api.nvim_buf_delete(source_buf, { force = true })
print('PASS: map window, highlights, layers, exact Git hits, separator lifecycle')
