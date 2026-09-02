local this = debug.getinfo(1, 'S').source:sub(2)
local plugin_root = vim.fn.fnamemodify(this, ':p:h:h')
local vendors = vim.fn.fnamemodify(plugin_root, ':h')
package.path = table.concat({
  plugin_root .. '/lua/?.lua',
  plugin_root .. '/lua/?/init.lua',
  vendors .. '/vv-utils.nvim/lua/?.lua',
  vendors .. '/vv-utils.nvim/lua/?/init.lua',
  package.path,
}, ';')

local callbacks = {}
local state = { git_marks = {}, git_pending = {} }
package.loaded['vv-scrollbar.config'] = {
  current = function() return { markers = { git = true } } end,
}
package.loaded['vv-scrollbar.core.state'] = state
package.loaded['vv-utils.git'] = {
  diff_lines = function(path, callback, opts)
    local item = { path = path, callback = callback, opts = opts, cancels = 0 }
    callbacks[#callbacks + 1] = item
    return function() item.cancels = item.cancels + 1 end
  end,
}
package.loaded['vv-scrollbar.features.git'] = nil

local Git = require('vv-scrollbar.features.git')
local buf = vim.api.nvim_create_buf(false, true)
vim.b[buf].vv_git_diff_source = { path = 'a.lua', root = '/repo-a', mode = 'staged' }

local refreshes = 0
local function refresh() refreshes = refreshes + 1 end
Git.refresh(buf, refresh)
Git.refresh(buf, refresh)
Git.refresh(buf, refresh)
assert(#callbacks == 1 and state.git_pending[buf].dirty,
  '同签名脏事件启动了重复生产者')

callbacks[1].callback({ [1] = 'A' })
assert(#callbacks == 2, '脏数据生产者完成时未只排队一次最新刷新')
assert(state.git_marks[buf].staged[1] == 'A' and refreshes == 1,
  '脏数据生产者在尾随刷新前未发布有效结果')
assert(state.git_pending[buf].request ~= nil,
  '脏数据生产者未保留替换中的待处理拥有者')
callbacks[2].callback({ [2] = 'C' })
assert(state.git_marks[buf].staged[2] == 'C' and refreshes == 2,
  '合并后的最新刷新未发布')

vim.b[buf].vv_git_diff_source = { path = 'b.lua', root = '/repo-b', mode = 'staged' }
Git.refresh(buf, refresh)
vim.b[buf].vv_git_diff_source = { path = 'c.lua', root = '/repo-c', mode = 'staged' }
Git.refresh(buf, refresh)
local pending_c = state.git_pending[buf].request
assert(callbacks[3].cancels == 1, '源替换未实际取消旧生产者')
callbacks[3].callback({ [3] = 'A' })
assert(state.git_pending[buf].request == pending_c and state.git_marks[buf].staged[2] == 'C',
  '被取消的源回调影响了更新中的待处理或标记')
callbacks[4].callback({ [4] = 'A' })
assert(state.git_marks[buf].staged[4] == 'A', '新源请求未发布')

vim.b[buf].vv_git_diff_source = { path = 'd.lua', root = '/repo-d', mode = 'staged' }
Git.refresh(buf, refresh)
Git.refresh(buf, refresh)
local count_before_clear = #callbacks
Git.clear_all()
callbacks[5].callback({ [5] = 'A' })
assert(#callbacks == count_before_clear and state.git_pending[buf] == nil,
  '清理后脏请求仍继续产生工作')

vim.b[buf].vv_git_diff_source = { path = 'e.lua', root = '/repo-e', mode = 'staged' }
Git.refresh(buf, refresh)
callbacks[6].callback({ [6] = 'A' })
assert(state.git_marks[buf].staged[6] == 'A', '新生命周期请求未发布')

Git.clear_all()

vim.b[buf].vv_git_diff_source = {
  path = 'conflict.lua',
  root = '/repo-conflict',
  from_index_stage = 2,
  to_index_stage = 3,
  side = 'new',
  marker_kind = 'U',
}
Git.refresh(buf, refresh)
local conflict = callbacks[7]
assert(conflict.opts.from_index_stage == 2 and conflict.opts.to_index_stage == 3,
  '冲突 source 未透传 index stage 范围')
conflict.callback({ [7] = 'C', [8] = 'A' })
assert(state.git_marks[buf].staged[7] == nil
    and state.git_marks[buf].unstaged[7] == 'U'
    and state.git_marks[buf].unstaged[8] == 'U',
  '冲突 source 未归一化到单一右侧 U 轨道')

Git.clear_all()
vim.api.nvim_buf_delete(buf, { force = true })
print('PASS: 滚动条 Git 合并脏刷新并保留请求所有权')
