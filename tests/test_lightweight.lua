-- 验证轻量模式绕过全文几何计算，并保留导航及窗口隔离
local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['轻量滚动条不扫描全文且拖拽首尾与标记跳转有效'] = function()
  child.lua_func(function()
    local api = vim.api
    local win = api.nvim_get_current_win()
    local buf = api.nvim_get_current_buf()
    local lines = {}
    for i = 1, 2000 do lines[i] = 'line ' .. i end
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = 'markdown'
    vim.wo[win].foldmethod = 'manual'
    vim.wo[win].foldenable = true
    vim.cmd('401,600fold')
    vim.cmd('normal! ggzt')

    local input, position
    local on_key = vim.on_key
    vim.on_key = function(callback, ns)
      input = callback
      return on_key(callback, ns)
    end
    vim.fn.getmousepos = function() return position end
    -- 重现已定位的昂贵 API 边界：普通渲染、点击和拖拽都不能调用它
    api.nvim_win_text_height = function() error('轻量模式重新计算了全文显示高度') end
    local scrollbar = require('vv-scrollbar')
    scrollbar.setup({
      throttle_ms = 0,
      lightweight = function(ctx) return ctx.filetype == 'markdown' and ctx.line_count >= 1000 end,
      markers = { git = false, search = false },
    })
    vim.on_key = on_key
    local state = require('vv-scrollbar.core.state')
    local view = require('vv-scrollbar.core.view')
    view.refresh({ strict = true })
    assert(state.bars[win].lightweight and not state.bars[win].map_layout, 'Markdown 未自动降级')
    assert(scrollbar.get_config().map_view.enabled, '降级不应改写全局地图偏好')

    local function mouse(key, row, col)
      local bar = state.bars[win]
      local screen = vim.fn.win_screenpos(bar.win)
      position = { screenrow = screen[1] + row, screencol = screen[2] + (col or 0) }
      assert(input(vim.keycode(key)) == '', '滚动条鼠标事件未被消费')
    end
    local bar = state.bars[win]
    mouse('<LeftMouse>', bar.thumb_row)
    mouse('<LeftDrag>', math.floor((bar.height - bar.thumb_height) / 2))
    assert(vim.fn.line('w0', win) > 700 and vim.fn.line('w0', win) < 1300, '拖拽未定位全文中部')
    bar = state.bars[win]
    mouse('<LeftDrag>', bar.height - bar.thumb_height)
    assert(vim.fn.line('w$', win) == 2000, '拖拽底部未显示 EOF')
    mouse('<LeftDrag>', 0)
    assert(vim.fn.line('w0', win) == 1, '拖拽顶部未返回开头')
    mouse('<LeftRelease>', 0)
    assert(not state.dragging, '松手后仍保留拖拽状态')

    local geometry = require('vv-scrollbar.core.geometry')
    local row = math.floor(state.bars[win].height / 4)
    local target = geometry.bar_row_to_line(win, row)
    local closed = vim.fn.foldclosed(target)
    assert(closed == -1 or target == closed, '轻量轨道命中隐藏折叠行')

    local ns = api.nvim_create_namespace('lightweight-diagnostic')
    vim.diagnostic.set(ns, buf, {{ lnum = 1599, col = 0, message = 'test' }})
    view.refresh({ strict = true })
    for marker_row, hits in pairs(state.bars[win].marker_hits) do
      if hits[1].source_line == 1600 then
        mouse('<LeftMouse>', marker_row, hits[1].start_col)
        assert(api.nvim_win_get_cursor(win)[1] == 1600, '诊断标记未精确定位源行')
        return
      end
    end
    error('轻量模式丢失诊断标记')
  end)
end

T['无名大文件与普通文件同时显示且切换后恢复地图'] = function()
  child.lua_func(function()
    local api = vim.api
    local large_win = api.nvim_get_current_win()
    local large_buf = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(large_buf, 0, -1, false, { string.rep('x', 1024 * 1024 + 1) })
    vim.bo[large_buf].buftype = 'nowrite'
    vim.cmd('vnew')
    local small_win = api.nvim_get_current_win()
    api.nvim_buf_set_lines(0, 0, -1, false, { 'local x = 1', 'return x' })
    local scrollbar = require('vv-scrollbar')
    scrollbar.setup({ map_view = { syntax = { enabled = false } }, markers = { git = false } })
    local state = require('vv-scrollbar.core.state')
    local view = require('vv-scrollbar.core.view')
    view.refresh({ strict = true })
    assert(state.bars[large_win].lightweight and not state.bars[large_win].map_layout, '无名 scratch 未按实际内容降级')
    assert(state.bars[small_win].map_layout, '大文件降级污染其他窗口')
    api.nvim_win_set_buf(large_win, api.nvim_win_get_buf(small_win))
    view.refresh({ strict = true })
    assert(not state.bars[large_win].lightweight and state.bars[large_win].map_layout, '换回小文件未恢复地图')
  end)
end

return T
