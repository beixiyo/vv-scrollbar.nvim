local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local mouse_position = { screenrow = 5, screencol = 10 }
local hit_bar = true
local marker_hit = false
local refresh_count = 0
local scroll_calls = {}
local cursor_calls = {}
local wheel_calls = {}
local viewport_updates = 0
local right_click_action = 'toggle_view'
local cursor_on_drag = 'follow'
local toggle_view_calls = 0
local right_click_context
local cursor_anchor = { screen_row = 5, curswant = 0, scrolloff = 5 }
local cursor_follow_ends = 0
local bar = {
  win = 13,
  parent = 12,
  thumb_row = 4,
  thumb_height = 3,
  map_layout = {
    mode = 'viewport',
    top_row = 20,
  },
}
local state = {
  bars = { [bar.parent] = bar },
  dragging = nil,
}

package.loaded['vv-scrollbar.config'] = {
  current = function()
    return {
      interaction = {
        right_click = right_click_action,
        cursor_on_drag = cursor_on_drag,
      },
      map_view = {
        marker_click = 'center',
        interaction = {
          edge_interval = 50,
        },
      },
    }
  end,
}
package.loaded['vv-scrollbar.core.geometry'] = {
  screenrow_to_bar_row = function(_, screenrow) return screenrow end,
  screenrow_to_bar_row_raw = function(_, screenrow) return screenrow end,
  bar_row_to_line = function(_, row) return row + 100 end,
  begin_cursor_follow = function() return cursor_anchor end,
  end_cursor_follow = function(_, anchor)
    assert(anchor == nil or anchor == cursor_anchor, 'unexpected cursor anchor ended')
    if anchor then cursor_follow_ends = cursor_follow_ends + 1 end
  end,
  scroll_to_bar_row = function(_, row, anchor)
    scroll_calls[#scroll_calls + 1] = { kind = 'bar', row = row, anchor = anchor }
  end,
  scroll_to_line = function(_, line, align, anchor, preferred_cursor_line)
    scroll_calls[#scroll_calls + 1] = {
      kind = 'line',
      line = line,
      align = align,
      anchor = anchor,
      preferred_cursor_line = preferred_cursor_line,
    }
  end,
  set_cursor_line = function(win, line)
    cursor_calls[#cursor_calls + 1] = { win = win, line = line }
  end,
}
package.loaded['vv-scrollbar.core.state'] = state
package.loaded['vv-scrollbar.features.map_view'] = {
  row_to_line = function(_, row) return row + 1 end,
}
package.loaded['vv-utils.scroll'] = {
  mouse = function(direction, win)
    wheel_calls[#wheel_calls + 1] = { direction = direction, win = win }
    return true
  end,
}
package.loaded['vv-scrollbar.input.viewport_drag'] = {
  update = function(layout, mouse_row, offset)
    assert(
      state.dragging.map_top == layout.top_row,
      'viewport map was not frozen when actual dragging started'
    )
    viewport_updates = viewport_updates + 1
    return {
      top_row = layout.top_row + 1,
      source_line = mouse_row - offset + 1,
      repeat_edge = false,
    }
  end,
}
package.loaded['vv-scrollbar.core.view'] = {
  hit_test = function()
    if hit_bar then return bar end
  end,
  marker_at = function()
    if marker_hit then return { source_line = 80 } end
  end,
}

local original_getmousepos = vim.fn.getmousepos
local original_on_key = vim.on_key
local on_key

vim.fn.getmousepos = function() return mouse_position end
vim.on_key = function(callback)
  on_key = callback
end

local mouse = require('vv-scrollbar.input.mouse')
mouse.attach(
  function() refresh_count = refresh_count + 1 end,
  function() toggle_view_calls = toggle_view_calls + 1 end
)
vim.on_key = original_on_key

assert(on_key, 'mouse handler was not attached')

assert(on_key(vim.keycode('<RightMouse>')) == '', 'right click over the bar was not consumed')
assert(toggle_view_calls == 1, 'right click did not toggle the scrollbar view')
assert(on_key(vim.keycode('<RightRelease>')) == '', 'right release over the bar was not consumed')

assert(on_key(vim.keycode('<2-RightMouse>')) == '', 'right double-click escaped to Neovim')
assert(toggle_view_calls == 1, 'right double-click toggled the scrollbar view twice')
assert(on_key(vim.keycode('<2-RightRelease>')) == '', 'right double-release escaped to Neovim')

right_click_action = false
assert(on_key(vim.keycode('<RightMouse>')) == '', 'disabled right click escaped to Neovim')
assert(toggle_view_calls == 1, 'disabled right click still toggled the scrollbar view')
assert(on_key(vim.keycode('<RightRelease>')) == '', 'disabled right release escaped to Neovim')

right_click_action = function(context) right_click_context = context end
assert(on_key(vim.keycode('<RightMouse>')) == '', 'custom right click was not consumed')
assert(
  right_click_context
    and right_click_context.win == bar.parent
    and right_click_context.scrollbar_win == bar.win
    and right_click_context.row == mouse_position.screenrow
    and right_click_context.view == 'map_view',
  'custom right-click callback received incorrect context'
)
assert(on_key(vim.keycode('<RightRelease>')) == '', 'custom right release escaped to Neovim')
right_click_action = 'toggle_view'

assert(on_key(vim.keycode('<LeftMouse>')) == '', 'thumb press was not consumed')
assert(state.dragging, 'thumb press did not enter active state')
assert(state.dragging.map_top == nil, 'plain thumb press froze the map projection')
assert(state.dragging.cursor_anchor == cursor_anchor, 'thumb press lost its cursor anchor')
assert(#scroll_calls == 0, 'plain thumb press unexpectedly scrolled the source window')
assert(refresh_count == 1, 'thumb press did not redraw its active state')

assert(on_key(vim.keycode('<LeftRelease>')) == '', 'thumb release was not consumed')
assert(state.dragging == nil, 'thumb release did not clear active state')
assert(cursor_follow_ends == 1, 'thumb release did not restore cursor follow state')
assert(#cursor_calls == 0, 'plain thumb click unexpectedly moved the cursor')

cursor_on_drag = 'keep'
assert(on_key(vim.keycode('<LeftMouse>')) == '', 'keep-mode thumb press was not consumed')
assert(state.dragging.cursor_anchor == nil, 'keep cursor mode still captured an anchor')
assert(on_key(vim.keycode('<LeftRelease>')) == '', 'keep-mode thumb release was not consumed')
assert(cursor_follow_ends == 1, 'keep mode restored a cursor anchor it never captured')
cursor_on_drag = 'follow'

for clicks = 2, 4 do
  local press = vim.keycode(('<%d-LeftMouse>'):format(clicks))
  local release = vim.keycode(('<%d-LeftRelease>'):format(clicks))

  assert(on_key(press) == '', ('%d-click press escaped to Neovim'):format(clicks))
  assert(state.dragging, ('%d-click press did not behave like a normal press'):format(clicks))
  assert(on_key(release) == '', ('%d-click release escaped to Neovim'):format(clicks))
  assert(state.dragging == nil, ('%d-click release left an active drag'):format(clicks))
end

mouse_position.screenrow = 12
assert(on_key(vim.keycode('<LeftMouse>')) == '', 'track press was not consumed')
assert(#scroll_calls == 1, 'track press did not perform exactly one jump')
assert(state.dragging.map_top == nil, 'track press froze the map before dragging')
assert(state.dragging.click_line == 13, 'track press lost its exact source line')
assert(
  scroll_calls[#scroll_calls].anchor == cursor_anchor
    and scroll_calls[#scroll_calls].preferred_cursor_line == 13,
  'track press did not place the cursor before capturing its drag position'
)
assert(on_key(vim.keycode('<LeftRelease>')) == '', 'track click release was not consumed')
assert(
  #cursor_calls == 1
    and cursor_calls[1].win == bar.parent
    and cursor_calls[1].line == 13,
  'track click did not place the cursor on its exact source line'
)

assert(on_key(vim.keycode('<LeftMouse>')) == '', 'track drag press was not consumed')
mouse_position.screenrow = 14
assert(on_key(vim.keycode('<LeftDrag>')) == '', 'track drag was not consumed')
assert(viewport_updates == 1, 'track drag did not update the viewport')
assert(state.dragging.map_top == 21, 'track drag did not retain its updated frozen map top')
assert(
  scroll_calls[#scroll_calls].anchor == cursor_anchor,
  'viewport drag did not pass its cursor anchor to geometry'
)
assert(on_key(vim.keycode('<LeftRelease>')) == '', 'track release was not consumed')
assert(#cursor_calls == 1, 'track drag incorrectly used click cursor placement')

bar.map_layout = nil
mouse_position.screenrow = 15
local classic_scroll_count = #scroll_calls
assert(on_key(vim.keycode('<LeftMouse>')) == '', 'classic track press was not consumed')
assert(
  #scroll_calls == classic_scroll_count + 1
    and scroll_calls[#scroll_calls].kind == 'line'
    and scroll_calls[#scroll_calls].line == 115
    and scroll_calls[#scroll_calls].align == 'center',
  'classic track click did not use its projected source line'
)
assert(on_key(vim.keycode('<LeftRelease>')) == '', 'classic track release was not consumed')
assert(
  #cursor_calls == 2
    and cursor_calls[2].win == bar.parent
    and cursor_calls[2].line == 115,
  'classic track click did not place the cursor on its projected source line'
)
bar.map_layout = {
  mode = 'viewport',
  top_row = 21,
}

marker_hit = true
assert(on_key(vim.keycode('<2-LeftMouse>')) == '', 'marker double-click press escaped')
assert(state.dragging == nil, 'marker click unexpectedly started dragging')
assert(
  #cursor_calls == 3
    and cursor_calls[3].win == bar.parent
    and cursor_calls[3].line == 80,
  'marker click did not place the cursor on its exact source line'
)
assert(on_key(vim.keycode('<2-LeftRelease>')) == '', 'marker double-click release escaped')

marker_hit = false
mouse_position.screenrow = 5
local mapped_key = vim.keycode('<F24>')
assert(
  on_key(mapped_key, vim.keycode('<ScrollWheelDown>')) == '',
  'mapped wheel event over the bar was not consumed'
)
assert(
  #wheel_calls == 1
    and wheel_calls[1].direction == 'down'
    and wheel_calls[1].win == bar.parent,
  'wheel event was not redirected to the source window'
)

hit_bar = false
assert(on_key(vim.keycode('<2-LeftMouse>')) == nil, 'double-click outside the bar was swallowed')
assert(on_key(vim.keycode('<2-LeftRelease>')) == nil, 'release outside the bar was swallowed')
assert(on_key(vim.keycode('<RightMouse>')) == nil, 'right click outside the bar was swallowed')
assert(on_key(vim.keycode('<RightRelease>')) == nil, 'right release outside the bar was swallowed')
assert(
  on_key(mapped_key, vim.keycode('<ScrollWheelUp>')) == nil,
  'wheel event outside the bar was swallowed'
)
assert(#wheel_calls == 1, 'wheel event outside the bar reached the source redirect')

hit_bar = true
local mapped_wheel_calls = 0
vim.keymap.set('n', '<ScrollWheelDown>', function()
  mapped_wheel_calls = mapped_wheel_calls + 1
end)

assert(on_key(vim.keycode('<LeftMouse>')) == '', 'detach fixture did not start dragging')
local ends_before_detach = cursor_follow_ends
mouse.detach()
assert(state.dragging == nil, 'detach did not clear active dragging')
assert(
  cursor_follow_ends == ends_before_detach + 1,
  'detach did not restore cursor follow state'
)
mouse.attach(
  function() refresh_count = refresh_count + 1 end,
  function() toggle_view_calls = toggle_view_calls + 1 end
)
vim.api.nvim_feedkeys(vim.keycode('<ScrollWheelDown>'), 'mtx', false)

assert(mapped_wheel_calls == 0, 'wheel mapping ran before vv-scrollbar could redirect it')
assert(#wheel_calls == 2, 'real mapped wheel input did not reach the source redirect')

vim.fn.getmousepos = original_getmousepos
vim.keymap.del('n', '<ScrollWheelDown>')
mouse.detach()

print('PASS: clicks, right-click actions, wheel redirect, deferred map freeze, and multi-click isolation')
