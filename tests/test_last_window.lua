local H = dofile('tests/helpers.lua')
local T, child = H.new_set()

T['删除当前 buffer 后接替显示的文件保留行号，滚动条重建'] = function()
  child.lua_func(function()
    -- 滚动条是真实的 split：:bdelete 当前 buffer 时 Neovim 会关掉显示它的编辑窗口，
    -- 只剩滚动条窗口；滚动条随后删掉自己的 buffer，别的 buffer 就被换进这个窗口
    local api = vim.api
    vim.o.number = true
    vim.o.relativenumber = true

    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, 'p')
    for _, name in ipairs({ 'first.txt', 'second.txt' }) do
      vim.fn.writefile({ 'one', 'two', 'three' }, dir .. '/' .. name)
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/first.txt'))

    local scrollbar = require('vv-scrollbar')
    scrollbar.setup({
      throttle_ms = 0,
      show_on_short_buffers = true,
      markers = { diagnostics = false, git = false, search = false, marks = false, quickfix = false, cursor = false },
    })
    local view = require('vv-scrollbar.core.view')
    local state = require('vv-scrollbar.core.state')

    vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/second.txt'))
    view.refresh({ strict = true })
    assert(vim.tbl_count(state.bars) == 1, '应先有一个滚动条')

    vim.cmd('bdelete!')
    view.refresh({ strict = true })
    -- 被还原的窗口在本轮刷新里已被跳过，滚动条由随后的补刷重建
    vim.wait(500, function() return vim.tbl_count(state.bars) == 1 end, 10)

    local win = api.nvim_get_current_win()
    assert(api.nvim_buf_get_name(0):find('first.txt', 1, true), '接替显示的应是另一个文件')
    assert(vim.wo[win].number and vim.wo[win].relativenumber, '接替显示的文件必须保留行号')
    assert(not vim.wo[win].winfixbuf, '编辑窗口不应锁定 buffer')
    assert(vim.tbl_count(state.bars) == 1, '滚动条应为新的编辑窗口重建')

    -- 之后换进来的 buffer 同样正常（minimal 样式不得被重新套用）
    vim.cmd('edit ' .. vim.fn.fnameescape(dir .. '/second.txt'))
    assert(vim.wo.number and not vim.wo.winfixbuf)

    vim.fn.delete(dir, 'rf')
  end)
end

return T
