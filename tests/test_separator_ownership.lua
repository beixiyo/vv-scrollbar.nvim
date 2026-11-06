local T, child = dofile('tests/helpers.lua').new_set()

local function prepare(map_enabled)
  child.lua([[
    local api = vim.api
    S = { plugin = require('vv-scrollbar'), state = require('vv-scrollbar.core.state') }
    S.win = api.nvim_get_current_win()
    vim.o.hidden = true
    vim.o.columns = 160
    local lines = {}
    for i = 1, 80 do lines[i] = 'const line' .. i .. ' = ' .. i end
    for _, name in ipairs({ 'A.tsx', 'B.tsx' }) do vim.fn.writefile(lines, vim.env.VV_TEST_TMP .. '/' .. name) end
    function S.edit(name) vim.cmd.edit(vim.fn.fnameescape(vim.env.VV_TEST_TMP .. '/' .. name)) end
    function S.hl(win) return api.nvim_get_option_value('winhighlight', { win = win or S.win, scope = 'local' }) end
    function S.set(value, win) api.nvim_set_option_value('winhighlight', value, { win = win or S.win, scope = 'local' }) end
    function S.check(value, message, win) assert(S.hl(win) == value, message .. ': ' .. S.hl(win)) end
    function S.bar(win, buf)
      assert(vim.wait(1000, function()
        local bar = S.state.bars[win]
        return bar and api.nvim_win_is_valid(bar.win) and bar.source_buf == buf
      end, 5), '生产事件刷新未创建目标 buffer 的滚动条')
      assert(S.hl(win):find('WinSeparator:VVScrollbarSeparator', 1, true), '可见滚动条缺少分隔线装饰')
    end
    function S.drain() vim.wait(60, function() return false end, 5) end
    S.edit('A.tsx')
    S.a = api.nvim_get_current_buf()
  ]])
  child.lua_func(function(enabled)
    S.opts = {
      enabled = false,
      throttle_ms = 0,
      map_view = { enabled = enabled, syntax = { enabled = false } },
      markers = { diagnostics = false, git = false, search = false, marks = false, quickfix = false, cursor = false },
    }
    S.plugin.setup(S.opts)
    vim.cmd.VVScrollbarDisable()
  end, map_enabled)
end

for _, map_enabled in ipairs({ false, true }) do
  T[(map_enabled and '地图' or '经典') .. '模式切换文件后禁用不留下隐藏分隔线'] = function()
    prepare(map_enabled)
    child.lua_func(function()
      S.check('', '启用前 A 应无映射')
      vim.cmd.VVScrollbarEnable()
      S.bar(S.win, S.a)
      assert((S.state.bars[S.win].map_layout ~= nil) == S.opts.map_view.enabled, '未进入指定视图')
      S.edit('B.tsx')
      S.bar(S.win, vim.api.nvim_get_current_buf())
      vim.cmd.VVScrollbarDisable()
      S.check('', '禁用后 B 应无映射')
      S.edit('A.tsx')
      S.check('', '隐藏的 A 不应保留本插件分隔线')
      S.drain()
      S.check('', '禁用后排队刷新不应复活装饰')
      assert(next(S.state.bars) == nil, '禁用后不应重建滚动条')
    end)
  end
end

T['切换不支持的 buffer 及时归还旧映射且不误写新窗口历史'] = function()
  prepare(false)
  child.lua_func(function()
    S.set('Normal:NormalFloat,WinSeparator:Error')
    S.plugin.enable()
    S.bar(S.win, S.a)
    local unsupported = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(S.win, unsupported)
    assert(vim.wait(1000, function() return S.state.bars[S.win] == nil end, 5), '不支持的 buffer 应关闭滚动条')
    S.check('', '不支持的 buffer 不应被写入 A 的原值')
    S.plugin.disable()
    S.edit('A.tsx')
    S.check('Normal:NormalFloat,WinSeparator:Error', 'A 原有分隔线应归还')
  end)
end

T['切走时同步归还原值并保留后来修改的其他字段'] = function()
  prepare(false)
  child.lua_func(function()
    S.set('Normal:NormalFloat,WinSeparator:Error')
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.set('Normal:Visual,WinSeparator:VVScrollbarSeparator,CursorLine:Search')
    local observed
    vim.api.nvim_create_autocmd('BufWinLeave', { buffer = S.a, once = true, callback = function() observed = S.hl() end })
    S.edit('B.tsx')
    assert(observed == 'Normal:Visual,WinSeparator:Error,CursorLine:Search', '原生保存窗口历史前必须归还自身字段: ' .. tostring(observed))
    S.bar(S.win, vim.api.nvim_get_current_buf())
    S.plugin.disable()
    S.edit('A.tsx')
    S.check('Normal:Visual,WinSeparator:Error,CursorLine:Search', '归还不得回滚其他 owner 的无关映射')
  end)
end

T['新旧 buffer 分别保留自身原有分隔线'] = function()
  prepare(false)
  child.lua_func(function()
    S.set('Normal:NormalFloat,WinSeparator:Error')
    S.edit('B.tsx')
    S.set('CursorLine:Search,WinSeparator:WarningMsg')
    S.edit('A.tsx')
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.edit('B.tsx')
    S.bar(S.win, vim.api.nvim_get_current_buf())
    S.plugin.disable()
    S.check('CursorLine:Search,WinSeparator:WarningMsg', 'B 必须恢复 B 的基线')
    S.edit('A.tsx')
    S.check('Normal:NormalFloat,WinSeparator:Error', 'A 必须恢复 A 的基线')
  end)
end

T['后来 owner 的分隔线在禁用和切走时不被撤回'] = function()
  prepare(false)
  child.lua_func(function()
    S.set('Normal:NormalFloat,WinSeparator:Error')
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.set('Normal:Visual,WinSeparator:WarningMsg')
    S.plugin.disable()
    S.check('Normal:Visual,WinSeparator:WarningMsg', '禁用不得覆盖 later owner')
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.set('Normal:Search,WinSeparator:Question')
    S.edit('B.tsx')
    S.bar(S.win, vim.api.nvim_get_current_buf())
    S.plugin.disable()
    S.edit('A.tsx')
    S.check('Normal:Search,WinSeparator:Question', '切走不得覆盖 later owner')
  end)
end

T['不同 buffer 焦点切换保持仍可见窗口的分隔线'] = function()
  prepare(false)
  child.lua_func(function()
    -- 启用前建立两窗，避免把 split 复制已装饰基线混入焦点生命周期回归。
    vim.cmd('vsplit')
    local other = vim.api.nvim_get_current_win()
    S.edit('B.tsx')
    local b = vim.api.nvim_get_current_buf()
    S.set('WinSeparator:Error', S.win)
    S.set('WinSeparator:WarningMsg', other)
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.bar(other, b)
    for _ = 1, 3 do
      vim.api.nvim_set_current_win(S.win)
      S.check('WinSeparator:VVScrollbarSeparator', '焦点离开时 B 仍显示滚动条', other)
      vim.api.nvim_set_current_win(other)
      S.check('WinSeparator:VVScrollbarSeparator', '焦点离开时 A 仍显示滚动条')
      S.drain()
      S.bar(S.win, S.a)
      S.bar(other, b)
    end
    S.plugin.disable()
    S.check('WinSeparator:Error', 'A 基线不应丢失')
    S.check('WinSeparator:WarningMsg', 'B 基线不应丢失', other)
  end)
end

T['多窗同 buffer 替换非当前窗仅归还该窗口历史'] = function()
  prepare(false)
  child.lua_func(function()
    vim.cmd('vsplit')
    local other = vim.api.nvim_get_current_win()
    S.set('WinSeparator:Error', S.win)
    S.set('WinSeparator:WarningMsg', other)
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.bar(other, S.a)
    vim.api.nvim_set_current_win(S.win)
    S.check('WinSeparator:VVScrollbarSeparator', '同 buffer 焦点切换不得去装饰', other)
    local b = vim.fn.bufadd(vim.env.VV_TEST_TMP .. '/B.tsx')
    vim.fn.bufload(b)
    vim.api.nvim_win_set_buf(other, b)
    S.check('WinSeparator:VVScrollbarSeparator', '替换另一窗不得归还仍显示 A 的窗口')
    S.bar(other, b)
    S.plugin.disable()
    S.check('WinSeparator:Error', '当前窗口应恢复自己的基线')
    vim.api.nvim_win_set_buf(other, S.a)
    S.check('WinSeparator:WarningMsg', '多窗同 buf 的隐藏窗口历史也应归还', other)
  end)
end

T['关闭非当前窗及重复 setup 开关不误写其他窗口'] = function()
  prepare(false)
  child.lua_func(function()
    vim.cmd('vsplit')
    local other = vim.api.nvim_get_current_win()
    S.edit('B.tsx')
    S.set('Normal:Visual,WinSeparator:WarningMsg', other)
    S.set('Normal:NormalFloat,WinSeparator:Error', S.win)
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.bar(other, vim.api.nvim_get_current_buf())
    vim.api.nvim_set_current_win(S.win)
    vim.api.nvim_win_close(other, true)
    S.check('Normal:NormalFloat,WinSeparator:VVScrollbarSeparator', '关闭非当前窗不得撤销当前窗装饰')
    S.drain()
    S.plugin.disable()
    S.check('Normal:NormalFloat,WinSeparator:Error', '关闭另一窗不得改写当前窗基线')
    for _ = 1, 3 do
      S.opts.enabled = true
      S.plugin.setup(S.opts)
      S.plugin.setup(S.opts)
      S.bar(S.win, S.a)
      S.edit('B.tsx')
      -- 不等待 BufWinEnter 的排队刷新，禁用必须仍然安全。
      S.opts.enabled = false
      S.plugin.setup(S.opts)
      S.plugin.disable()
      S.drain()
      S.check('Normal:Visual,WinSeparator:WarningMsg', '重复 setup 不得把 A 的基线写入 B')
      S.edit('A.tsx')
      S.check('Normal:NormalFloat,WinSeparator:Error', '重复 setup 不得留下 A 的历史装饰')
      assert(next(S.state.bars) == nil, '禁用后旧队列不得创建滚动条')
    end
  end)
end

T['关闭当前源窗也归还历史且保持接收焦点窗口装饰'] = function()
  prepare(false)
  child.lua_func(function()
    vim.cmd('vsplit')
    local other = vim.api.nvim_get_current_win()
    S.edit('B.tsx')
    S.set('WinSeparator:WarningMsg', other)
    S.set('WinSeparator:Error', S.win)
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.bar(other, vim.api.nvim_get_current_buf())
    vim.api.nvim_win_close(other, true)
    S.drain()
    S.bar(S.win, S.a)
    S.plugin.disable()
    S.check('WinSeparator:Error', '关闭当前源窗不得改写剩余源窗基线')
    S.edit('B.tsx')
    S.check('WinSeparator:WarningMsg', '关闭当前源窗后也不得遗留 buffer 历史装饰')
  end)
end

local function prepare_focus(same_buffer)
  prepare(false)
  child.lua_func(function(same)
    local api = vim.api
    vim.cmd('vsplit')
    S.other = api.nvim_get_current_win()
    if not same then S.edit('B.tsx') end
    local other_buf = api.nvim_get_current_buf()
    api.nvim_set_current_win(S.win)
    -- B 的基线故意与 A 相同，防止只比较值而漏掉过期 window-buffer 凭据。
    S.edit('B.tsx')
    S.set('WinSeparator:Error')
    S.edit('A.tsx')
    S.set('WinSeparator:Error')
    S.plugin.enable()
    S.bar(S.win, S.a)
    S.bar(S.other, other_buf)
    S.drain()
    function S.record_writes()
      S.writes = {}
      local set_option = api.nvim_set_option_value
      -- 仅记录并委托真实 API；不替换生产窗口、选项或事件行为。
      api.nvim_set_option_value = function(name, value, opts)
        if name == 'winhighlight' and opts.win == S.win then S.writes[#S.writes + 1] = value end
        return set_option(name, value, opts)
      end
    end
  end, same_buffer)
end

T['不同 buffer 切焦点同步阶段不得接管 later owner'] = function()
  prepare_focus(false)
  child.lua_func(function()
    S.set('WinSeparator:Question')
    S.record_writes()
    vim.api.nvim_set_current_win(S.other)
    -- 不让出事件循环：验证新增同步链，而不是已有排队 refresh 的接管策略。
    S.check('WinSeparator:Question', '焦点切换返回时不得覆盖 later owner')
    assert(#S.writes == 0, '没有实际归还时不得新增同步 separator 写入')
    S.plugin.disable()
    S.check('WinSeparator:Question', '禁用仍须尊重 later owner')
  end)
end

for _, target in ipairs({ 'VVScrollbarSeparator', 'Question' }) do
  T['同 buffer 焦点无释放时不重写 separator：' .. target] = function()
    prepare_focus(true)
    child.lua_func(function(expected)
      S.set('WinSeparator:' .. expected)
      S.record_writes()
      vim.api.nvim_set_current_win(S.other)
      S.check('WinSeparator:' .. expected, '同 buffer 焦点切换不得改动当前 owner')
      assert(#S.writes == 0, '同 buffer 没有 BufLeave，不应写入分隔线: ' .. vim.inspect(S.writes))
      S.plugin.disable()
    end, target)
  end
end

T['BufLeave 已归还后其他 autocmd 修改 separator 时 WinLeave 不覆盖'] = function()
  prepare_focus(false)
  child.lua_func(function()
    local changed = false
    vim.api.nvim_create_autocmd('BufLeave', {
      buffer = S.a,
      once = true,
      callback = function()
        S.check('WinSeparator:Error', '生产 BufLeave 应先归还基线')
        S.set('WinSeparator:Question')
        changed = true
      end,
    })
    S.record_writes()
    vim.api.nvim_set_current_win(S.other)
    assert(changed, '测试必须经过真实 BufLeave 交错')
    S.check('WinSeparator:Question', 'WinLeave 不得覆盖归还之后的 owner')
    assert(vim.deep_equal(S.writes, { 'WinSeparator:Error', 'WinSeparator:Question' }),
      '只应发生生产归还与后来 owner 两次写入，不得第三次接管')
    S.plugin.disable()
    S.check('WinSeparator:Question', '清理不得回滚交错 owner')
  end)
end

T['真实换 buffer 后的释放凭据不得用于后续同 buf 焦点或再次回到旧 buf'] = function()
  prepare_focus(false)
  child.lua_func(function()
    S.record_writes()
    S.edit('B.tsx')
    S.check('WinSeparator:Error', '新 B 尚未刷新时应保留自己的基线')
    vim.api.nvim_set_current_win(S.other)
    S.check('WinSeparator:Error', 'A 的释放凭据不得用于 B 的同 buf 焦点切换')
    assert(vim.deep_equal(S.writes, { 'WinSeparator:Error' }), '真实换 buf 后不应额外重施装饰')
    vim.api.nvim_set_current_win(S.win)
    S.edit('A.tsx')
    vim.api.nvim_set_current_win(S.other)
    S.check('WinSeparator:Error', '旧 A 再进入也不得复用上一轮释放凭据')
    assert(#S.writes == 1, '陈旧凭据不得跨 BufEnter 或 WinEnter 继续生效')
    S.plugin.disable()
  end)
end

return T
