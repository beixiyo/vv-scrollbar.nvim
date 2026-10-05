local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['地图缓存、防抖与旧代次取消'] = function()
  child.lua_func(function()
    local api = vim.api
    local cache = require('vv-scrollbar.features.map_view.cache')
    local config = require('vv-scrollbar.config')

    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'x' })

    local refresh_count = 0
    local initial = cache.get(buf, 1, 1, config.current().map_view, function()
      refresh_count = refresh_count + 1
    end)
    api.nvim_buf_set_lines(buf, 0, -1, false, { ' ' })
    local stale = cache.get(buf, 1, 1, config.current().map_view, function()
      refresh_count = refresh_count + 1
    end)
    assert(stale[1] == initial[1], '缓冲区修改后防抖期间未保留缓存地图')
    assert(vim.wait(500, function() return refresh_count == 1 end, 10), '防抖后的地图未重建')

    local rebuilt = cache.get(buf, 1, 1, config.current().map_view, function() end)
    assert(rebuilt[1] == ' ', '防抖地图缓存仍保留旧文本')

    cache.clear(buf)
    api.nvim_buf_set_lines(buf, 0, -1, false, { 'xx' })
    cache.get(buf, 1, 1, config.current().map_view, function() end)
    cache.get(buf, 1, 2, config.current().map_view, function() end)
    api.nvim_buf_set_lines(buf, 0, -1, false, { '  ' })

    local multi_width_refreshes = 0
    cache.get(buf, 1, 1, config.current().map_view, function()
      multi_width_refreshes = multi_width_refreshes + 1
    end)
    cache.get(buf, 1, 2, config.current().map_view, function()
      multi_width_refreshes = multi_width_refreshes + 1
    end)
    assert(
      vim.wait(500, function() return multi_width_refreshes == 2 end, 10),
      '不同地图宽度的有效重建因代际令牌而被取消'
    )

    api.nvim_buf_set_lines(buf, 0, -1, false, { 'x' })
    cache.get(buf, 1, 1, config.current().map_view, function()
      error('已清理的缓存执行了过期重建回调')
    end)
    cache.clear(buf)
    vim.wait(200, function() return false end, 10)
    api.nvim_buf_delete(buf, { force = true })
  end)
end

return T
