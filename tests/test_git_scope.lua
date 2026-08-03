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
  diff_lines = function(path, callback)
    local item = { path = path, callback = callback, cancels = 0 }
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
  'same-signature dirty events started duplicate producers')

callbacks[1].callback({ [1] = 'A' })
assert(#callbacks == 2, 'dirty producer completion did not queue exactly one latest refresh')
assert(state.git_marks[buf] == nil and state.git_pending[buf].request ~= nil,
  'stale dirty result published or cleared the replacement pending owner')
callbacks[2].callback({ [2] = 'C' })
assert(state.git_marks[buf].staged[2] == 'C' and refreshes == 1,
  'coalesced latest refresh did not publish')

vim.b[buf].vv_git_diff_source = { path = 'b.lua', root = '/repo-b', mode = 'staged' }
Git.refresh(buf, refresh)
vim.b[buf].vv_git_diff_source = { path = 'c.lua', root = '/repo-c', mode = 'staged' }
Git.refresh(buf, refresh)
local pending_c = state.git_pending[buf].request
assert(callbacks[3].cancels == 1, 'source replacement did not physically cancel old producer')
callbacks[3].callback({ [3] = 'A' })
assert(state.git_pending[buf].request == pending_c and state.git_marks[buf].staged[2] == 'C',
  'cancelled source callback affected newer pending or markers')
callbacks[4].callback({ [4] = 'A' })
assert(state.git_marks[buf].staged[4] == 'A', 'new source request did not publish')

vim.b[buf].vv_git_diff_source = { path = 'd.lua', root = '/repo-d', mode = 'staged' }
Git.refresh(buf, refresh)
Git.refresh(buf, refresh)
local count_before_clear = #callbacks
Git.clear_all()
callbacks[5].callback({ [5] = 'A' })
assert(#callbacks == count_before_clear and state.git_pending[buf] == nil,
  'clear allowed a dirty request to replenish work')

vim.b[buf].vv_git_diff_source = { path = 'e.lua', root = '/repo-e', mode = 'staged' }
Git.refresh(buf, refresh)
callbacks[6].callback({ [6] = 'A' })
assert(state.git_marks[buf].staged[6] == 'A', 'new lifecycle request did not publish')

Git.clear_all()
vim.api.nvim_buf_delete(buf, { force = true })
print('PASS: scrollbar git coalesces dirty refreshes and preserves request ownership')
