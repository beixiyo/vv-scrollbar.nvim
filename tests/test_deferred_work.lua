-- 验证降级/关闭后不再运行过期后台任务，并保留其他窗口的有效消费者
local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['窗口释放地图需求只取消最后一个消费者的重建'] = function()
  child.lua_func(function()
    local api = vim.api
    local cache = require('vv-scrollbar.features.map_view.cache')
    local config = require('vv-scrollbar.config')
    local opts = config.apply({ map_view = { syntax = { enabled = false }, debounce_ms = 20 } }).map_view
    local buf = api.nvim_get_current_buf()
    local first = api.nvim_get_current_win()
    vim.cmd('vsplit')
    local second = api.nvim_get_current_win()
    local refreshes = 0
    local function refresh() refreshes = refreshes + 1 end
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'x' })
    cache.get(buf, 1, 1, opts, refresh, first)
    cache.get(buf, 1, 1, opts, refresh, second)
    api.nvim_buf_set_lines(buf, 0, -1, false, { ' ' })
    cache.get(buf, 1, 1, opts, refresh, first)
    cache.release(first)
    assert(vim.wait(500, function() return refreshes == 1 end, 10), '一个窗口降级错误地取消了另一个窗口的地图更新')
    local rebuilt = cache.get(buf, 1, 1, opts, refresh, second)
    assert(rebuilt[1] == ' ', '共享消费者未收到实际新地图')

    api.nvim_buf_set_lines(buf, 0, -1, false, { 'xx' })
    cache.get(buf, 1, 1, opts, refresh, second)
    cache.release(second)
    vim.wait(80)
    assert(refreshes == 1, '最后一个窗口降级后旧地图任务仍执行')
    cache.clear_all()
  end)
end

T['轻量冲突扫描跨分片并丢弃修改和关闭后的过期结果'] = function()
  child.lua_func(function()
    local api = vim.api
    local conflicts = require('vv-scrollbar.features.conflicts')
    local buf = api.nvim_get_current_buf()
    local lines = {}
    for i = 1, 1200 do lines[i] = 'normal ' .. i end
    lines[255], lines[600], lines[700], lines[1025] = '<<<<<<< ours', '||||||| base', '=======', '>>>>>>> theirs'
    -- 外观相似的横幅不得误判为冲突
    lines[1100], lines[1101], lines[1102] = '<<<<<<<<', '========', '>>>>>>>>'
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local updates = 0
    local opts = { deferred = true, on_update = function() updates = updates + 1 end }
    assert(next(conflicts.lines(buf, opts)) == nil, '轻量模式首次请求不应同步扫描全文')
    assert(vim.wait(1500, function() return updates == 1 end, 5), '分片扫描未完成')
    local result = conflicts.lines(buf, opts)
    assert(result[255] == 'U' and result[600] == 'U' and result[1025] == 'U', '跨分片的 diff3 冲突范围丢失')
    assert(not result[254] and not result[1026] and not result[1100], '冲突范围越界或误判横幅')

    api.nvim_buf_set_lines(buf, 0, 1, false, { 'new tick' })
    conflicts.lines(buf, opts)
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'resolved' })
    conflicts.lines(buf, opts)
    assert(vim.wait(1000, function() return updates == 2 end, 5), '新版本未完成扫描')
    assert(next(conflicts.lines(buf, opts)) == nil, '过期扫描覆盖已解决的冲突')

    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    conflicts.lines(buf, opts)
    conflicts.retain({})
    vim.wait(80)
    assert(updates == 2, '关闭后冲突任务继续刷新 UI')
    conflicts.clear_all()
  end)
end

return T
