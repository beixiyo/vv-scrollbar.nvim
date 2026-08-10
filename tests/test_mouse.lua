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
        marker_click = 'center',
      },
      map_view = {
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
    assert(anchor == nil or anchor == cursor_anchor, '未预期的光标锚点结束')
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
      '开始拖拽时视口映射未冻结'
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

assert(on_key, '鼠标处理器未被挂载')

local drag_target = vim.api.nvim_get_current_win()
vim.cmd('vsplit')
local panel_like_win = vim.api.nvim_get_current_win()
bar.parent = drag_target
state.bars = { [drag_target] = bar }
vim.api.nvim_set_current_win(panel_like_win)

assert(on_key(vim.keycode('<RightMouse>')) == '', '右击滚动条时事件未被消费')
assert(toggle_view_calls == 1, '右击未切换滚动条视图')
assert(on_key(vim.keycode('<RightRelease>')) == '', '右击释放未消费')

assert(on_key(vim.keycode('<2-RightMouse>')) == '', '右键双击未被消费，透传到 Neovim')
assert(toggle_view_calls == 1, '右键双击切换了滚动条视图两次')
assert(on_key(vim.keycode('<2-RightRelease>')) == '', '右键双释放未被消费，透传到 Neovim')

right_click_action = false
assert(on_key(vim.keycode('<RightMouse>')) == '', '禁用右击时仍透传到 Neovim')
assert(toggle_view_calls == 1, '禁用右击仍切换了滚动条视图')
assert(on_key(vim.keycode('<RightRelease>')) == '', '禁用右击释放时仍透传到 Neovim')

right_click_action = function(context) right_click_context = context end
assert(on_key(vim.keycode('<RightMouse>')) == '', '自定义右击未被消费')
assert(
    right_click_context
    and right_click_context.win == bar.parent
    and right_click_context.scrollbar_win == bar.win
    and right_click_context.row == mouse_position.screenrow
    and right_click_context.view == 'map_view',
  '自定义右击回调接收了错误的上下文'
)
assert(on_key(vim.keycode('<RightRelease>')) == '', '自定义右击释放未被消费，透传到 Neovim')
right_click_action = 'toggle_view'

assert(on_key(vim.keycode('<LeftMouse>')) == '', '左键按压拖拽柄未被消费')
assert(
  vim.api.nvim_get_current_win() == drag_target,
  '按压拖拽柄前未聚焦到受控窗口，导致后续拖拽映射失效'
)
assert(state.dragging, '按压拖拽柄未进入活动状态')
assert(state.dragging.map_top == nil, '普通按压拖拽柄未冻结地图投影')
assert(state.dragging.cursor_anchor == cursor_anchor, '按压拖拽柄丢失了光标锚点')
assert(#scroll_calls == 0, '普通按压拖拽柄意外滚动了源窗口')
assert(refresh_count == 1, '按压拖拽柄未重绘活动态')

assert(on_key(vim.keycode('<LeftRelease>')) == '', '拖拽柄释放未被消费')
assert(state.dragging == nil, '拖拽柄释放未清理活动状态')
assert(cursor_follow_ends == 1, '拖拽柄释放未恢复跟随光标状态')
assert(#cursor_calls == 0, '普通点击拖拽柄意外移动了光标')

cursor_on_drag = 'keep'
assert(on_key(vim.keycode('<LeftMouse>')) == '', '保持模式按压拖拽柄未被消费')
assert(state.dragging.cursor_anchor == nil, '保持模式仍保留了不该有的光标锚点')
assert(on_key(vim.keycode('<LeftRelease>')) == '', '保持模式释放拖拽柄未被消费')
assert(cursor_follow_ends == 1, '保持模式恢复了从未捕获过的光标锚点')
cursor_on_drag = 'follow'

for clicks = 2, 4 do
  local press = vim.keycode(('<%d-LeftMouse>'):format(clicks))
  local release = vim.keycode(('<%d-LeftRelease>'):format(clicks))

  assert(on_key(press) == '', ('%d 次点击按压透传到 Neovim'):format(clicks))
  assert(state.dragging, ('%d 次点击按压未表现为普通按压'):format(clicks))
  assert(on_key(release) == '', ('%d 次点击释放透传到 Neovim'):format(clicks))
  assert(state.dragging == nil, ('%d 次点击释放后仍保留活动拖拽'):format(clicks))
end

mouse_position.screenrow = 12
assert(on_key(vim.keycode('<LeftMouse>')) == '', '轨道按压未被消费')
assert(#scroll_calls == 1, '轨道按压未执行且仅执行一次跳转')
assert(state.dragging.map_top == nil, '轨道按压在拖拽前未冻结地图')
assert(state.dragging.click_line == 13, '轨道按压未保留精确源行')
assert(
  scroll_calls[#scroll_calls].anchor == cursor_anchor
    and scroll_calls[#scroll_calls].preferred_cursor_line == 13,
  '轨道按压未在抓取拖拽坐标前放置光标'
)
assert(on_key(vim.keycode('<LeftRelease>')) == '', '轨道释放未被消费')
assert(
  #cursor_calls == 1
    and cursor_calls[1].win == bar.parent
  and cursor_calls[1].line == 13,
  '轨道点击未将光标放在精确源行'
)

assert(on_key(vim.keycode('<LeftMouse>')) == '', '轨道拖拽按压未被消费')
mouse_position.screenrow = 14
assert(on_key(vim.keycode('<LeftDrag>')) == '', '轨道拖拽未被消费')
assert(viewport_updates == 1, '轨道拖拽未更新视口')
assert(state.dragging.map_top == 21, '轨道拖拽未保留已更新的冻结地图顶部')
assert(
  scroll_calls[#scroll_calls].anchor == cursor_anchor,
  '视口拖拽未向几何计算传递光标锚点'
)
assert(on_key(vim.keycode('<LeftRelease>')) == '', '轨道释放未被消费')
assert(#cursor_calls == 1, '轨道拖拽错误地使用了点击光标位置')

bar.map_layout = nil
mouse_position.screenrow = 15
local classic_scroll_count = #scroll_calls
assert(on_key(vim.keycode('<LeftMouse>')) == '', '经典轨道按压未被消费')
assert(
  #scroll_calls == classic_scroll_count + 1
    and scroll_calls[#scroll_calls].kind == 'line'
    and scroll_calls[#scroll_calls].line == 115
    and scroll_calls[#scroll_calls].align == 'center',
  '经典轨道点击未使用其预估源行'
)
assert(on_key(vim.keycode('<LeftRelease>')) == '', '经典轨道释放未被消费')
assert(
  #cursor_calls == 2
  and cursor_calls[2].win == bar.parent
  and cursor_calls[2].line == 115,
  '经典轨道点击未将光标放在预估源行'
)
bar.map_layout = {
  mode = 'viewport',
  top_row = 21,
}

marker_hit = true
assert(on_key(vim.keycode('<2-LeftMouse>')) == '', '标记双击按压未被消费')
assert(state.dragging == nil, '标记点击意外进入拖拽状态')
assert(
  #cursor_calls == 3
    and cursor_calls[3].win == bar.parent
    and cursor_calls[3].line == 80,
  '标记点击未将光标放在精确源行'
)
assert(on_key(vim.keycode('<2-LeftRelease>')) == '', '标记双击释放未被消费')

marker_hit = false
mouse_position.screenrow = 5
local mapped_key = vim.keycode('<F24>')
assert(
  on_key(mapped_key, vim.keycode('<ScrollWheelDown>')) == '',
  '映射的滚轮事件在滚动条上未被消费'
)
assert(
  #wheel_calls == 1
    and wheel_calls[1].direction == 'down'
    and wheel_calls[1].win == bar.parent,
  '滚轮事件未重定向到源窗口'
)

hit_bar = false
assert(on_key(vim.keycode('<2-LeftMouse>')) == nil, '滚动条外的双击事件被吞')
assert(on_key(vim.keycode('<2-LeftRelease>')) == nil, '滚动条外的释放事件被吞')
assert(on_key(vim.keycode('<RightMouse>')) == nil, '滚动条外的右击事件被吞')
assert(on_key(vim.keycode('<RightRelease>')) == nil, '滚动条外的右击释放事件被吞')
assert(
  on_key(mapped_key, vim.keycode('<ScrollWheelUp>')) == nil,
  '滚动条外的滚轮事件被吞'
)
assert(#wheel_calls == 1, '滚轮事件从滚动条外成功交给源重定向')

hit_bar = true
local mapped_wheel_calls = 0
vim.keymap.set('n', '<ScrollWheelDown>', function()
  mapped_wheel_calls = mapped_wheel_calls + 1
end)

assert(on_key(vim.keycode('<LeftMouse>')) == '', '执行卸载后未触发拖拽开始')
local ends_before_detach = cursor_follow_ends
mouse.detach()
assert(state.dragging == nil, '分离后未清理活动拖拽状态')
assert(
  cursor_follow_ends == ends_before_detach + 1,
  'detach 未恢复光标跟随状态'
)
mouse.attach(
  function() refresh_count = refresh_count + 1 end,
  function() toggle_view_calls = toggle_view_calls + 1 end
)
vim.api.nvim_feedkeys(vim.keycode('<ScrollWheelDown>'), 'mtx', false)

assert(mapped_wheel_calls == 0, '滚轮映射在插件重定向前已执行')
assert(#wheel_calls == 2, '真实映射滚轮输入未到达源重定向')

vim.fn.getmousepos = original_getmousepos
vim.keymap.del('n', '<ScrollWheelDown>')
mouse.detach()
pcall(vim.api.nvim_win_close, panel_like_win, true)

print('PASS: 点击、右键动作、滚轮重定向、延迟冻结地图与多击隔离')
