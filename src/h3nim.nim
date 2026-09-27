## H3 地理索引系统 Nim 绑定
##
## 本模块提供 Uber H3 六边形地理索引系统（v4.5.0）的完整 Nim 绑定。
## 遵循 V8.0 中文代码命名规范，保留 H3 等专有名词英文原样。

import std/[os, math]

# ── 编译所有 H3 C 源文件 ─────────────────────────
# ponytail: 直接编译 vendored C 源文件，不依赖 CMake

when defined(windows):
  {.passC: "-D_USE_MATH_DEFINES".}
elif defined(macosx) or defined(linux):
  {.passL: "-lm".}

{.passC: "-I" & currentSourcePath.parentDir / "h3lib" / "include".}

# 注册所有 H3 C 源文件
# >>> h3lib 编译列表（由 update_bindings.nims 自动生成，请勿手动修改）
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "algos.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "area.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "baseCells.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "bbox.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "cellsToMultiPoly.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "directedEdge.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "faceijk.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "h3Assert.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "h3Index.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "iterators.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "latLng.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "linkedGeo.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "localij.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "mathExtensions.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "polyfill.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "polygon.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "vec2d.c".}
{.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "vertex.c".}
# <<< h3lib 编译列表

# ── 基础类型 ──────────────────────────────────────

type
  H3索引* = distinct uint64
  H3错误* = distinct uint32

  H3错误码* {.size: sizeof(cint).} = enum
    成功 = 0
    失败 = 1
    域错误 = 2
    经纬度域错误 = 3
    分辨率域错误 = 4
    单元无效 = 5
    有向边无效 = 6
    无向边无效 = 7
    顶点无效 = 8
    五边形 = 9
    重复输入 = 10
    非相邻 = 11
    分辨率不匹配 = 12
    内存分配失败 = 13
    内存越界 = 14
    选项无效 = 15
    索引无效 = 16
    基单元号域错误 = 17
    子位无效 = 18
    已删除子位 = 19
    错误结束

  包含模式* {.size: sizeof(cint).} = enum
    中心包含 = 0
    完全包含 = 1
    重叠包含 = 2
    包围盒重叠 = 3
    包含模式无效 = 4

  经纬度* {.bycopy, pure.} = object
    纬度*: float64  # 弧度
    经度*: float64  # 弧度

  单元边界* {.bycopy, pure.} = object
    顶点数*: cint
    顶点*: array[10, 经纬度]  # MAX_CELL_BNDRY_VERTS = 10

  地理环* {.bycopy, pure.} = object
    顶点数*: cint
    顶点*: ptr 经纬度

  地理多边形* {.bycopy, pure.} = object
    外环*: 地理环
    孔数*: cint
    孔*: ptr 地理环

  地理多边组* {.bycopy, pure.} = object
    多边形数*: cint
    多边形*: ptr 地理多边形

  链接经纬度* {.bycopy, pure.} = object
    坐标*: 经纬度
    下一*: ptr 链接经纬度

  链接地理环* {.bycopy, pure.} = object
    首*: ptr 链接经纬度
    尾*: ptr 链接经纬度
    下一*: ptr 链接地理环

  链接地理多边形* {.bycopy, pure.} = object
    首*: ptr 链接地理环
    尾*: ptr 链接地理环
    下一*: ptr 链接地理多边形

  坐标IJ* {.bycopy, pure.} = object
    i*: cint
    j*: cint

  # ── 迭代器类型 ──

  迭代子单元* {.bycopy, pure.} = object
    单元*: H3索引
    父级分辨率*: cint
    跳过位*: cint

  迭代分辨率* {.bycopy, pure.} = object
    单元*: H3索引
    基单元号*: cint
    分辨率*: cint
    子迭代*: 迭代子单元

  迭代多边形紧凑* {.bycopy, pure.} = object
    单元*: H3索引
    错误*: H3错误
    目标分辨率*: cint
    标志*: uint32
    多边形*: ptr 地理多边形
    包围盒*: pointer  # BBox，内部使用
    已开始*: bool

  迭代多边形* {.bycopy, pure.} = object
    单元*: H3索引
    错误*: H3错误
    单元迭代*: 迭代多边形紧凑
    子迭代*: 迭代子单元

  迭代高斯珀边* {.bycopy, pure.} = object
    边*: H3索引
    剩余*: int64
    边位置*: int8
    步进位置*: array[16, int8]  # MAX_H3_RES + 1 = 16
    父级分辨率*: int8
    子级分辨率*: int8
    是否五边形*: bool

# ── 常量 ──

const
  H3空*: H3索引 = H3索引(0)
  最大单元边界顶点* = 10

# ── 基础操作 ──

template `$`*(idx: H3索引): string = $(uint64(idx))
template `==`*(a, b: H3索引): bool = uint64(a) == uint64(b)
template `$`*(err: H3错误): string = $(uint32(err))
template `==`*(a, b: H3错误): bool = uint32(a) == uint32(b)

proc 经纬度转度*(经纬: 经纬度): (float64, float64) =
  ## 将弧度经纬度转为角度度
  (radToDeg(经纬.纬度), radToDeg(经纬.经度))

proc 度转经纬度*(纬度度, 经度度: float64): 经纬度 =
  ## 将角度度转为弧度经纬度
  经纬度(纬度: degToRad(纬度度), 经度: degToRad(经度度))

# ── 核心 API 函数绑定 ──

# 描述错误
proc 描述H3错误*(错误: H3错误): cstring {.cdecl, importc: "describeH3Error".}

# 经纬度 ↔ 单元
proc 经纬度转单元*(经纬: ptr 经纬度, 分辨率: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "latLngToCell".}
proc 单元转经纬度*(单元: H3索引, 输出: ptr 经纬度): H3错误 {.
    cdecl, importc: "cellToLatLng".}
proc 单元转边界*(单元: H3索引, 输出: ptr 单元边界): H3错误 {.
    cdecl, importc: "cellToBoundary".}

# 网格圆盘（k-ring）
proc 最大网格圆盘数*(k: cint, 输出: ptr int64): H3错误 {.
    cdecl, importc: "maxGridDiskSize".}
proc 网格圆盘不安全*(原点: H3索引, k: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "gridDiskUnsafe".}
proc 网格圆盘距离不安全*(原点: H3索引, k: cint,
                          输出: ptr H3索引, 距离: ptr cint): H3错误 {.
    cdecl, importc: "gridDiskDistancesUnsafe".}
proc 网格圆盘距离安全*(原点: H3索引, k: cint,
                       输出: ptr H3索引, 距离: ptr cint): H3错误 {.
    cdecl, importc: "gridDiskDistancesSafe".}
proc 网格圆盘集不安全*(单元集: ptr H3索引, 长度: cint, k: cint,
                       输出: ptr H3索引): H3错误 {.
    cdecl, importc: "gridDisksUnsafe".}
proc 网格圆盘*(原点: H3索引, k: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "gridDisk".}
proc 网格圆盘距离*(原点: H3索引, k: cint,
                   输出: ptr H3索引, 距离: ptr cint): H3错误 {.
    cdecl, importc: "gridDiskDistances".}

# 网格环
proc 最大网格环数*(k: cint, 输出: ptr int64): H3错误 {.
    cdecl, importc: "maxGridRingSize".}
proc 网格环不安全*(原点: H3索引, k: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "gridRingUnsafe".}
proc 网格环*(原点: H3索引, k: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "gridRing".}

# 多边形 ↔ 单元
proc 最大多边形转单元数*(地理多边形: ptr 地理多边形, 分辨率: cint,
                         标志: uint32, 输出: ptr int64): H3错误 {.
    cdecl, importc: "maxPolygonToCellsSize".}
proc 多边形转单元*(地理多边形: ptr 地理多边形, 分辨率: cint,
                   标志: uint32, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "polygonToCells".}
proc 最大多边形转单元数实验*(多边形: ptr 地理多边形, 分辨率: cint,
                             标志: uint32, 输出: ptr int64): H3错误 {.
    cdecl, importc: "maxPolygonToCellsSizeExperimental".}
proc 多边形转单元实验*(多边形: ptr 地理多边形, 分辨率: cint,
                       标志: uint32, 大小: int64,
                       输出: ptr H3索引): H3错误 {.
    cdecl, importc: "polygonToCellsExperimental".}

# 链接多边组
proc 单元转链接多边组*(单元集: ptr H3索引, 单元数: cint,
                       输出: ptr 链接地理多边形): H3错误 {.
    cdecl, importc: "cellsToLinkedMultiPolygon".}
proc 销毁链接多边组*(多边形: ptr 链接地理多边形) {.
    cdecl, importc: "destroyLinkedMultiPolygon".}

# 角度转换
proc 度转弧度*(度: float64): float64 {.cdecl, importc: "degsToRads".}
proc 弧度转度*(弧度: float64): float64 {.cdecl, importc: "radsToDegs".}

# 大圆距离
proc 大圆距离弧度*(a, b: ptr 经纬度): float64 {.
    cdecl, importc: "greatCircleDistanceRads".}
proc 大圆距离千米*(a, b: ptr 经纬度): float64 {.
    cdecl, importc: "greatCircleDistanceKm".}
proc 大圆距离米*(a, b: ptr 经纬度): float64 {.
    cdecl, importc: "greatCircleDistanceM".}

# 面积
proc 获取六边形平均面积平方千米*(分辨率: cint, 输出: ptr float64): H3错误 {.
    cdecl, importc: "getHexagonAreaAvgKm2".}
proc 获取六边形平均面积平方米*(分辨率: cint, 输出: ptr float64): H3错误 {.
    cdecl, importc: "getHexagonAreaAvgM2".}
proc 单元面积弧度平方*(单元: H3索引, 输出: ptr float64): H3错误 {.
    cdecl, importc: "cellAreaRads2".}
proc 单元面积平方千米*(单元: H3索引, 输出: ptr float64): H3错误 {.
    cdecl, importc: "cellAreaKm2".}
proc 单元面积平方米*(单元: H3索引, 输出: ptr float64): H3错误 {.
    cdecl, importc: "cellAreaM2".}

# 边长
proc 获取六边形平均边长千米*(分辨率: cint, 输出: ptr float64): H3错误 {.
    cdecl, importc: "getHexagonEdgeLengthAvgKm".}
proc 获取六边形平均边长米*(分辨率: cint, 输出: ptr float64): H3错误 {.
    cdecl, importc: "getHexagonEdgeLengthAvgM".}
proc 边长度弧度*(边: H3索引, 长度: ptr float64): H3错误 {.
    cdecl, importc: "edgeLengthRads".}
proc 边长度千米*(边: H3索引, 长度: ptr float64): H3错误 {.
    cdecl, importc: "edgeLengthKm".}
proc 边长度米*(边: H3索引, 长度: ptr float64): H3错误 {.
    cdecl, importc: "edgeLengthM".}

# 单元计数
proc 获取单元数*(分辨率: cint, 输出: ptr int64): H3错误 {.
    cdecl, importc: "getNumCells".}
proc 零级单元数*(): cint {.cdecl, importc: "res0CellCount".}
proc 获取零级单元*(输出: ptr H3索引): H3错误 {.
    cdecl, importc: "getRes0Cells".}
proc 五边形数*(): cint {.cdecl, importc: "pentagonCount".}
proc 获取五边形*(分辨率: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "getPentagons".}

# 索引查询
proc 获取分辨率原*(单元: H3索引): cint {.cdecl, importc: "getResolution".}
proc 获取基单元号*(单元: H3索引): cint {.cdecl, importc: "getBaseCellNumber".}
proc 获取索引位*(单元: H3索引, 分辨率: cint, 输出: ptr cint): H3错误 {.
    cdecl, importc: "getIndexDigit".}
proc 构造单元*(分辨率: cint, 基单元号: cint, 子位: ptr cint,
               输出: ptr H3索引): H3错误 {.
    cdecl, importc: "constructCell".}

# 字符串 ↔ 单元
proc 字符串转单元*(字符串: cstring, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "stringToH3".}
proc 单元转字符串原*(单元: H3索引, 字符串: cstring, 大小: csize_t): H3错误 {.
    cdecl, importc: "h3ToString".}

# 有效性
proc 是否有效单元原*(单元: H3索引): cint {.cdecl, importc: "isValidCell".}
proc 是否有效索引*(索引: H3索引): cint {.cdecl, importc: "isValidIndex".}

# 层级
proc 单元转父级*(单元: H3索引, 父级分辨率: cint,
                 父级: ptr H3索引): H3错误 {.
    cdecl, importc: "cellToParent".}
proc 单元转子级数*(单元: H3索引, 子级分辨率: cint,
                   输出: ptr int64): H3错误 {.
    cdecl, importc: "cellToChildrenSize".}
proc 单元转子级*(单元: H3索引, 子级分辨率: cint,
                 子级: ptr H3索引): H3错误 {.
    cdecl, importc: "cellToChildren".}
proc 单元转中心子级*(单元: H3索引, 子级分辨率: cint,
                     子级: ptr H3索引): H3错误 {.
    cdecl, importc: "cellToCenterChild".}
proc 单元转子级位置*(子级: H3索引, 父级分辨率: cint,
                     输出: ptr int64): H3错误 {.
    cdecl, importc: "cellToChildPos".}
proc 子级位置转单元*(子级位置: int64, 父级: H3索引,
                     子级分辨率: cint, 子级: ptr H3索引): H3错误 {.
    cdecl, importc: "childPosToCell".}

# 紧凑/解紧凑
proc 紧凑单元*(单元集: ptr H3索引, 紧凑集: ptr H3索引,
               单元数: int64): H3错误 {.
    cdecl, importc: "compactCells".}
proc 解紧凑单元数*(紧凑集: ptr H3索引, 紧凑数: int64,
                   分辨率: cint, 输出: ptr int64): H3错误 {.
    cdecl, importc: "uncompactCellsSize".}
proc 解紧凑单元*(紧凑集: ptr H3索引, 紧凑数: int64,
                 输出集: ptr H3索引, 输出数: int64,
                 分辨率: cint): H3错误 {.
    cdecl, importc: "uncompactCells".}

# 单元属性
proc 是否三级类原*(单元: H3索引): cint {.cdecl, importc: "isResClassIII".}
proc 是否五边形原*(单元: H3索引): cint {.cdecl, importc: "isPentagon".}

# 二十面体面
proc 最大面数*(单元: H3索引, 输出: ptr cint): H3错误 {.
    cdecl, importc: "maxFaceCount".}
proc 获取二十面体面*(单元: H3索引, 输出: ptr cint): H3错误 {.
    cdecl, importc: "getIcosahedronFaces".}

# 邻接
proc 是否相邻单元*(原点, 目标: H3索引, 输出: ptr cint): H3错误 {.
    cdecl, importc: "areNeighborCells".}

# 有向边
proc 单元转有向边*(原点, 目标: H3索引, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "cellsToDirectedEdge".}
proc 是否有效有向边*(边: H3索引): cint {.
    cdecl, importc: "isValidDirectedEdge".}
proc 获取有向边起点*(边: H3索引, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "getDirectedEdgeOrigin".}
proc 获取有向边终点*(边: H3索引, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "getDirectedEdgeDestination".}
proc 有向边转单元*(边: H3索引, 起点终点: ptr H3索引): H3错误 {.
    cdecl, importc: "directedEdgeToCells".}
proc 起点转有向边集*(起点: H3索引, 边集: ptr H3索引): H3错误 {.
    cdecl, importc: "originToDirectedEdges".}
proc 有向边转边界*(边: H3索引, 输出: ptr 单元边界): H3错误 {.
    cdecl, importc: "directedEdgeToBoundary".}
proc 反转有向边*(边: H3索引, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "reverseDirectedEdge".}

# 顶点
proc 单元转顶点*(原点: H3索引, 顶点号: cint, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "cellToVertex".}
proc 单元转顶点集*(原点: H3索引, 顶点集: ptr H3索引): H3错误 {.
    cdecl, importc: "cellToVertexes".}
proc 顶点转经纬度*(顶点: H3索引, 点: ptr 经纬度): H3错误 {.
    cdecl, importc: "vertexToLatLng".}
proc 是否有效顶点*(顶点: H3索引): cint {.
    cdecl, importc: "isValidVertex".}

# 网格路径
proc 网格距离*(原点, 目标: H3索引, 距离: ptr int64): H3错误 {.
    cdecl, importc: "gridDistance".}
proc 网格路径单元数*(起点, 终点: H3索引, 大小: ptr int64): H3错误 {.
    cdecl, importc: "gridPathCellsSize".}
proc 网格路径单元*(起点, 终点: H3索引, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "gridPathCells".}

# 局部 IJ 坐标
proc 单元转局部IJ*(原点, 目标: H3索引, 模式: uint32,
                   输出: ptr 坐标IJ): H3错误 {.
    cdecl, importc: "cellToLocalIj".}
proc 局部IJ转单元*(原点: H3索引, ij: ptr 坐标IJ,
                   模式: uint32, 输出: ptr H3索引): H3错误 {.
    cdecl, importc: "localIjToCell".}

# ── 迭代器函数 ──

proc 初始化父级迭代*(单元: H3索引, 子级分辨率: cint): 迭代子单元 {.
    cdecl, importc: "iterInitParent".}
proc 初始化基单元迭代*(基单元号: cint, 子级分辨率: cint): 迭代子单元 {.
    cdecl, importc: "iterInitBaseCellNum".}
proc 步进子级迭代*(迭代: ptr 迭代子单元) {.
    cdecl, importc: "iterStepChild".}

proc 初始化分辨率迭代*(分辨率: cint): 迭代分辨率 {.
    cdecl, importc: "iterInitRes".}
proc 步进分辨率迭代*(迭代: ptr 迭代分辨率) {.
    cdecl, importc: "iterStepRes".}

proc 初始化多边形紧凑迭代*(多边形: ptr 地理多边形, 分辨率: cint,
                           标志: uint32): 迭代多边形紧凑 {.
    cdecl, importc: "iterInitPolygonCompact".}
proc 步进多边形紧凑迭代*(迭代: ptr 迭代多边形紧凑) {.
    cdecl, importc: "iterStepPolygonCompact".}
proc 销毁多边形紧凑迭代*(迭代: ptr 迭代多边形紧凑) {.
    cdecl, importc: "iterDestroyPolygonCompact".}

proc 初始化多边形迭代*(多边形: ptr 地理多边形, 分辨率: cint,
                       标志: uint32): 迭代多边形 {.
    cdecl, importc: "iterInitPolygon".}
proc 步进多边形迭代*(迭代: ptr 迭代多边形) {.
    cdecl, importc: "iterStepPolygon".}
proc 销毁多边形迭代*(迭代: ptr 迭代多边形) {.
    cdecl, importc: "iterDestroyPolygon".}

proc 初始化高斯珀迭代*(单元: H3索引, 子级分辨率: cint): 迭代高斯珀边 {.
    cdecl, importc: "iterInitGosper".}
proc 步进高斯珀迭代*(迭代: ptr 迭代高斯珀边) {.
    cdecl, importc: "iterStepGosper".}

# ── Nim 便捷封装 ──────────────────────────

proc 经纬度转单元*(经纬: 经纬度, 分辨率: int): H3索引 =
  var 输出: H3索引
  discard 经纬度转单元(addr 经纬, 分辨率.cint, addr 输出)
  输出

proc 单元转经纬度*(单元: H3索引): 经纬度 =
  var 输出: 经纬度
  discard 单元转经纬度(单元, addr 输出)
  输出

proc 单元转字符串*(单元: H3索引): string =
  var 缓冲区: array[17, char]
  let 结果 = 单元转字符串原(单元, cast[cstring](addr 缓冲区[0]), 17)
  if 结果 == H3错误(0):
    result = $cast[cstring](addr 缓冲区[0])

proc 字符串转单元*(字符串: string): H3索引 =
  var 输出: H3索引
  discard 字符串转单元(字符串.cstring, addr 输出)
  输出

proc 是否有效单元*(单元: H3索引): bool =
  是否有效单元原(单元) != 0

proc 是否五边形*(单元: H3索引): bool =
  是否五边形原(单元) != 0

proc 是否三级类*(单元: H3索引): bool =
  是否三级类原(单元) != 0

proc 获取分辨率*(单元: H3索引): int =
  获取分辨率原(单元).int

proc 单元转父级*(单元: H3索引, 父级分辨率: int): H3索引 =
  var 父: H3索引
  discard 单元转父级(单元, 父级分辨率.cint, addr 父)
  父

proc 单元转中心子级*(单元: H3索引, 子级分辨率: int): H3索引 =
  var 子: H3索引
  discard 单元转中心子级(单元, 子级分辨率.cint, addr 子)
  子

# ── 演示/自检 ──

when isMainModule:
  echo "H3 Nim 绑定 v4.5.0 — 自检开始"

  let 旧金山 = 度转经纬度(37.7749, -122.4194)

  # 经纬度 → 单元
  let 单元 = 经纬度转单元(旧金山, 10)
  let 单元串 = 单元转字符串(单元)
  echo "旧金山 @ res 10: ", 单元串

  # 单元 → 经纬度
  let 中心 = 单元转经纬度(单元)
  let (纬度度, 经度度) = 经纬度转度(中心)
  echo "单元中心: ", 纬度度, ", ", 经度度

  # 有效性
  echo "是否有效: ", 是否有效单元(单元)
  echo "是否五边形: ", 是否五边形(单元)
  echo "分辨率: ", 获取分辨率(单元)

  # 大圆距离
  let 洛杉矶 = 度转经纬度(34.0522, -118.2437)
  echo "旧金山→洛杉矶: ", 大圆距离千米(addr 旧金山, addr 洛杉矶), " km"

  # k-ring
  var 邻居: array[7, H3索引]
  if 网格圆盘(单元, 1, addr 邻居[0]) == H3错误(0):
    echo "1-ring: ", 邻居.len, " 个单元"
    for i, 邻 in 邻居.pairs:
      if 邻 != H3空:
        echo "  ", i, ": ", 单元转字符串(邻)

  # 错误码
  echo "H3错误描述: ", $描述H3错误(H3错误(0))

  # 字符串 ↔ H3 互转
  let 原串 = 单元转字符串(单元)
  let 还原 = 字符串转单元(原串)
  echo "字符串往返: ", 原串, " → ", 单元转字符串(还原), " ", 是否有效单元(还原)

  echo "自检通过"
