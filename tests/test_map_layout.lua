local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')

vim.opt.runtimepath:prepend(root)

local layout = require('vv-scrollbar.features.map_view.layout')
local projection = require('vv-scrollbar.core.projection')

local opts = {
  mode = 'viewport',
  y_multiplier = 1,
  min_thumb = 2,
}

local top = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 1,
  botline = 20,
  thumb_row = 0,
  thumb_height = 1,
}, opts)
assert(top.content_height == 100, 'viewport 地图高度未使用固定的垂直比例')
assert(top.top_row == 0 and top.thumb_row == 0, '顶部视口未锚定地图起始')

local middle = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 201,
  botline = 220,
  thumb_row = 10,
  thumb_height = 1,
}, opts)
assert(middle.top_row == 43, '中部源码视口未在地图视口中居中')
assert(middle.thumb_row == 7 and middle.thumb_height == 5, '中部拇指坐标偏移')
assert(layout.line_to_row(middle, 201) == 7, '源码行未映射到可见切片')
assert(layout.row_to_line(middle, 7) == 201, '可见地图行未映射回源码')

local bottom = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 381,
  botline = 400,
  thumb_row = 19,
  thumb_height = 1,
}, opts)
assert(bottom.top_row == 80, '底部视口未锚定地图末端')
assert(bottom.thumb_row + bottom.thumb_height == 20, '底部拇指超出可见地图范围')

local short = layout.resolve({
  line_count = 10,
  height = 20,
  topline = 1,
  botline = 10,
  thumb_row = 0,
  thumb_height = 20,
}, opts)
assert(short.content_height == 3, '短文件地图被拉伸而非保持紧凑')
assert(short.top_row == 0 and short.thumb_height == 3, '短文件视口不稳定')

local resized = layout.resolve({
  line_count = 400,
  height = 10,
  topline = 201,
  botline = 220,
  thumb_row = 5,
  thumb_height = 1,
}, opts)
assert(resized.content_height == middle.content_height, '窗口重置更改了固定地图比例')
assert(resized.top_row == 48 and resized.thumb_row == 2, '重置大小后地图视口未重新居中')

local fit = layout.resolve({
  line_count = 400,
  height = 20,
  topline = 201,
  botline = 220,
  thumb_row = 10,
  thumb_height = 2,
}, { mode = 'fit' })
assert(fit.content_height == 20 and fit.top_row == 0, 'fit 兼容模式变成可滚动')
assert(fit.thumb_row == 10 and fit.thumb_height == 2, 'fit 模式下传统拇指几何发生变化')

assert(projection.row_to_line(0, 400, 20) == 1, '经典投影丢失首行')
assert(projection.row_to_line(19, 400, 20) == 400, '经典投影丢失末行')
assert(
  projection.line_to_row(projection.row_to_line(10, 400, 20), 400, 20) == 10,
  '经典行到行号映射未能回到点击行'
)

print('PASS: viewport 比例、源码同步、短文件、边界、重置窗口大小与 fit 回退')
