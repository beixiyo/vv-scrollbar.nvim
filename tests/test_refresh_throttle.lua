local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['节流窗口内异步 Git 结果尾随渲染'] = function()
  child.lua_func(function()
    -- 回归：节流窗口内到达的异步 Git 结果必须最终渲染
    -- vv-git 用鼠标切换 staged 文件时，CursorMoved / WinScrolled 先触发一次节流刷新，
    -- 随后 diff 结果在同一节流窗口内返回；只保留前沿的节流会吞掉这次刷新，
    -- marker 要等下一次滚动或聚焦才出现



    local api = vim.api

    local requests = {}
    package.loaded['vv-utils.git'] = {
      register_hl = function() end,
      diff_lines = function(_, callback)
        requests[#requests + 1] = callback
        return function() end
      end,
    }

    local lines = {}
    for index = 1, 200 do lines[index] = ('line %03d'):format(index) end
    local buf = api.nvim_create_buf(true, false)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.b[buf].vv_scrollbar_git_source = { path = 'sample.txt', root = '/repo', mode = 'staged' }

    local state = require('vv-scrollbar.core.state')
    require('vv-scrollbar').setup({
      -- 放大节流窗口，让「结果落在窗口内」不依赖机器速度
      throttle_ms = 500,
      map_view = { enabled = false },
      markers = {
        diagnostics = false,
        git = true,
        search = false,
        marks = false,
        quickfix = false,
        cursor = false,
      },
    })

    local parent = api.nvim_get_current_win()
    api.nvim_win_set_buf(parent, buf)
    assert(vim.wait(1000, function() return #requests == 1 end), 'BufWinEnter 未发起 Git diff 请求')

    -- 排空 BufWinEnter 排队的布局刷新（它不经节流），再让一次普通事件刷新占用节流窗口；
    -- 两次等待合计远小于 throttle_ms，Git 结果返回时窗口仍未结束
    vim.wait(50)
    vim.cmd('doautocmd CursorMoved')
    vim.wait(50)
    assert(state.bars[parent] ~= nil, '普通事件未渲染滚动条')
    assert(next(state.bars[parent].row_markers or {}) == nil, 'Git 结果返回前不应已有 marker')

    -- 节流窗口仍在：Git 结果此时返回，发布的刷新不能被丢弃
    requests[1]({ [100] = 'C', [150] = 'A' })
    assert(state.git_marks[buf] and state.git_marks[buf].staged[100] == 'C', 'Git 结果未写入 marker 状态')

    local rendered = vim.wait(1500, function()
      local bar = state.bars[parent]
      return bar ~= nil and next(bar.row_markers or {}) ~= nil
    end, 10)
    assert(rendered, '节流窗口内到达的 Git 结果被丢弃：需要滚动或聚焦才显示 marker')
  end)
end

return T
