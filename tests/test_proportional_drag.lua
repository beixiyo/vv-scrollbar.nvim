-- 用真实窗口、地图渲染和鼠标处理器验证全文比例拖拽；仅替换鼠标输入边界
local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['长文件按全文比例拖拽且松手不重新定位地图'] = function()
  child.lua_func(function()
    local api = vim.api
    local parent = api.nvim_get_current_win()
    local lines = {}
    for index = 1, 8000 do lines[index] = ('line %05d'):format(index) end
    api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.wo[parent].wrap = false
    vim.wo[parent].foldenable = false
    vim.wo[parent].scrolloff = 5

    local input, position
    local original_on_key, original_getmousepos = vim.on_key, vim.fn.getmousepos
    vim.on_key = function(callback, namespace)
      input = callback
      return original_on_key(callback, namespace)
    end
    vim.fn.getmousepos = function() return position end

    local scrollbar = require('vv-scrollbar')
    scrollbar.setup({
      throttle_ms = 0,
      map_view = { syntax = { enabled = false } },
      markers = {
        diagnostics = false, git = false, search = false,
        marks = false, quickfix = false, cursor = false,
      },
    })
    vim.on_key = original_on_key
    local view = require('vv-scrollbar.core.view')
    local state = require('vv-scrollbar.core.state')
    view.refresh()

    local function mouse(key, row)
      local bar = state.bars[parent]
      local screen = vim.fn.win_screenpos(bar.win)
      position = { screenrow = screen[1] + row, screencol = screen[2] + 1 }
      assert(input(vim.keycode(key)) == '', '地图内的鼠标输入必须被消费')
    end

    local bar = state.bars[parent]
    local offset = math.floor(bar.thumb_height / 2)
    mouse('<LeftMouse>', bar.thumb_row + offset)
    assert(vim.fn.line('w0', parent) == 1, '按住现有 thumb 不应跳转')
    local middle = math.floor((bar.height - bar.thumb_height) / 2) + offset
    mouse('<LeftDrag>', middle)
    local held_top = vim.fn.line('w0', parent)
    assert(held_top > 3500 and held_top < 4500, '拖到轨道中间只移动了局部地图，没有定位到全文中间')
    local held_map_top = state.bars[parent].map_layout.top_row
    vim.wait(150)
    assert(vim.fn.line('w0', parent) == held_top, '比例拖拽停住后仍被边缘 timer 推动')
    mouse('<LeftRelease>', middle)
    assert(vim.fn.line('w0', parent) == held_top, '松手后源窗口重新定位')
    assert(math.abs(state.bars[parent].map_layout.top_row - held_map_top) <= 1, '松手后地图从拖拽位置跳回居中切片')
    assert(vim.wo[parent].scrolloff == 5, '松手后未恢复 scrolloff')

    bar = state.bars[parent]
    offset = math.floor(bar.thumb_height / 2)
    mouse('<LeftMouse>', bar.thumb_row + offset)
    local bottom = bar.height - bar.thumb_height + offset
    mouse('<LeftDrag>', bottom)
    assert(state.dragging, '到达底部前意外结束拖拽')
    assert(vim.fn.line('w$', parent) == 8000, '按住拖到底部未立即展示文件末尾')
    local bottom_top = vim.fn.line('w0', parent)
    vim.wait(150)
    assert(vim.fn.line('w0', parent) == bottom_top, '到文件底部后仍有自动滚动')
    mouse('<LeftDrag>', offset)
    assert(vim.fn.line('w0', parent) == 1, '同一次拖拽向上未返回文件开头')
    mouse('<LeftRelease>', offset)
    assert(not state.dragging, '松手后未清理拖拽状态')

    -- disable 必须结束按住状态，不留下旧的边缘回调或 scrolloff 覆盖
    bar = state.bars[parent]
    mouse('<LeftMouse>', bar.thumb_row + offset)
    mouse('<LeftDrag>', bottom)
    scrollbar.disable()
    local stopped_top = vim.fn.line('w0', parent)
    vim.wait(150)
    assert(not state.dragging and next(state.bars) == nil, '禁用后拖拽或地图仍然存在')
    assert(vim.fn.line('w0', parent) == stopped_top and vim.wo[parent].scrolloff == 5, '禁用后旧拖拽仍修改窗口')
    vim.fn.getmousepos = original_getmousepos
  end)
end

return T
