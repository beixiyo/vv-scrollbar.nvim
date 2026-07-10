local M = {}

local SEV = vim.diagnostic.severity

---@class VVScrollbarHighlightConfig
---@field track vim.api.keyset.highlight 轨道背景 @default { bg = '#20242b' }
---@field thumb vim.api.keyset.highlight 当前视口 thumb @default { bg = '#3b4252' }
---@field hover vim.api.keyset.highlight 拖拽中的 thumb @default { bg = '#4b5568' }
---@field cursor vim.api.keyset.highlight 光标位置 @default { fg = '#7aa2f7' }
---@field search vim.api.keyset.highlight 搜索命中 @default { fg = '#ff9e64' }
---@field mark vim.api.keyset.highlight mark 位置 @default { fg = '#bb9af7' }
---@field quickfix vim.api.keyset.highlight quickfix / loclist 位置 @default { fg = '#e0af68' }
---@field diag_error vim.api.keyset.highlight Error 诊断 @default { fg = '#f7768e' }
---@field diag_warn vim.api.keyset.highlight Warn 诊断 @default { fg = '#e0af68' }
---@field diag_info vim.api.keyset.highlight Info 诊断 @default { fg = '#7dcfff' }
---@field diag_hint vim.api.keyset.highlight Hint 诊断 @default { fg = '#1abc9c' }

---@class VVScrollbarSymbolsConfig
---@field thumb string thumb 填充字符 @default ' '
---@field cursor string 光标标记 @default '█'
---@field search string 搜索标记 @default '•'
---@field mark string mark 标记 @default '◆'
---@field quickfix string quickfix / loclist 标记 @default '■'
---@field diagnostics table<integer,string> 诊断 severity -> 标记 @default { [ERROR] = '●', [WARN] = '●', [INFO] = '●', [HINT] = '●' }
---@field git table<'A'|'C'|'D', string> git 行级标记 @default { A = '▎', C = '▎', D = '󰆐' }

---@class VVScrollbarMarkerConfig
---@field diagnostics boolean 是否显示诊断标记 @default true
---@field git boolean 是否显示 git 行级标记 @default true
---@field search boolean 是否显示当前 / 搜索命中 @default true
---@field marks boolean 是否显示 Vim marks @default true
---@field quickfix boolean 是否显示 quickfix / loclist @default true
---@field cursor boolean 是否显示光标位置 @default true

---@class VVScrollbarConfig
---@field enabled boolean 是否启用 @default true
---@field current_only boolean 是否只显示当前窗口 @default false
---@field width integer 轨道宽度，单位为屏幕列 @default 2
---@field right_offset integer 距窗口右边缘的偏移列数 @default 0
---@field zindex integer 浮窗 zindex @default 45
---@field winblend integer 浮窗透明度 @default 0
---@field min_thumb integer thumb 最小高度 @default 2
---@field throttle_ms integer UI 刷新节流间隔 @default 30
---@field search_line_limit integer 搜索投影最大行数 @default 20000
---@field excluded_filetypes string[] 排除的 filetype @default { 'terminal', 'toggleterm', ... }
---@field excluded_buftypes string[] 排除的 buftype @default { 'nofile', 'terminal', 'prompt', 'quickfix' }
---@field window_filter? fun(win:integer, buf:integer):boolean 窗口过滤器，返回 false 时隐藏滚动条 @default nil
---@field markers VVScrollbarMarkerConfig 标记开关
---@field symbols VVScrollbarSymbolsConfig 标记字符
---@field highlights VVScrollbarHighlightConfig 高亮定义

local defaults = {
  enabled = true,
  current_only = false,
  width = 2,
  right_offset = 0,
  zindex = 45,
  winblend = 0,
  min_thumb = 2,
  throttle_ms = 30,
  search_line_limit = 20000,
  excluded_filetypes = {
    'terminal', 'toggleterm', 'blink-cmp-menu', 'cmp_docs', 'cmp_menu',
    'dropbar_menu', 'dropbar_menu_fzf', 'DressingInput', 'noice', 'prompt', 'TelescopePrompt',
    'dashboard', 'vv-explorer', 'vv-git', 'vv-task-panel',
  },
  excluded_buftypes = { 'nofile', 'terminal', 'prompt', 'quickfix' },
  window_filter = nil,
  markers = {
    diagnostics = true,
    git = true,
    search = true,
    marks = true,
    quickfix = true,
    cursor = true,
  },
  symbols = {
    thumb = ' ',
    cursor = '█',
    search = '•',
    mark = '◆',
    quickfix = '■',
    diagnostics = {
      [SEV.ERROR] = '●',
      [SEV.WARN] = '●',
      [SEV.INFO] = '●',
      [SEV.HINT] = '●',
    },
    git = {
      A = '▎',
      C = '▎',
      D = '󰆐',
    },
  },
  highlights = {
    track = { bg = '#20242b' },
    thumb = { bg = '#3b4252' },
    hover = { bg = '#4b5568' },
    cursor = { fg = '#7aa2f7' },
    search = { fg = '#ff9e64' },
    mark = { fg = '#bb9af7' },
    quickfix = { fg = '#e0af68' },
    diag_error = { fg = '#f7768e' },
    diag_warn = { fg = '#e0af68' },
    diag_info = { fg = '#7dcfff' },
    diag_hint = { fg = '#1abc9c' },
  },
}

---@type VVScrollbarConfig
local current = vim.deepcopy(defaults)

---@param value any
---@param fallback integer
---@return integer
local function positive_integer(value, fallback)
  local number = tonumber(value)
  if not number then return fallback end
  return math.max(math.floor(number), 1)
end

---@param opts? VVScrollbarConfig
---@return VVScrollbarConfig
function M.apply(opts)
  current = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  current.width = positive_integer(current.width, defaults.width)
  current.min_thumb = positive_integer(current.min_thumb, defaults.min_thumb)
  current.right_offset = math.max(
    math.floor(tonumber(current.right_offset) or defaults.right_offset),
    0
  )
  current.throttle_ms = math.max(
    math.floor(tonumber(current.throttle_ms) or defaults.throttle_ms),
    0
  )
  return current
end

---@return VVScrollbarConfig
function M.current()
  return current
end

---@return VVScrollbarConfig
function M.get()
  return vim.deepcopy(current)
end

return M
