# h3-nim

**Uber H3 六边形地理索引系统 — Nim 绑定**

将 Uber H3 v4.5.0 的 C 库完整绑定到 Nim，按照 V8.0 中文代码命名规范，提供全中文 API。

## 特性

- **全 API 覆盖** — 80+ 公共函数、全部公开类型、迭代器
- **中文命名** — `经纬度转单元`、`单元转父级`、`网格圆盘`、`是否有效单元`
- **零外部依赖** — H3 C 源码随包 vendored，Nim 编译器直接编译
- **跨平台** — Linux / macOS / Windows 均支持
- **类型安全** — `H3索引` 为 `distinct uint64`，编译期防止类型混淆

## 快速开始

```bash
# 编译绑定自检
nim c src/h3nim.nim
./src/h3nim

# 运行测试
nim c --path:src -r tests/test_h3nim.nim

# 运行示例
nim c --path:src -r examples/example_basic.nim
nim c --path:src -r examples/example_geofence.nim
nim c --path:src -r examples/example_hierarchy.nim
```

## 使用示例

```nim
import h3nim

# 经纬度 → H3 索引
let 北京 = 度转经纬度(39.9042, 116.4074)
let 单元 = 北京.经纬度转单元(10)
echo 单元转字符串(单元)  # 8a283082800ffff

# H3 索引 → 经纬度
let 中心 = 单元.单元转经纬度()
let (纬度, 经度) = 中心.经纬度转度()
echo 纬度, ", ", 经度     # 37.7743, -122.4193

# 有效性检查
echo 是否有效单元(单元)   # true
echo 是否五边形(单元)     # false
echo 获取分辨率(单元)     # 10

# k-ring 邻居
var 邻居: array[7, H3索引]
if 网格圆盘(单元, 1, addr 邻居[0]) == H3错误(0):
  for 邻 in 邻居:
    if 邻 != H3空: echo 单元转字符串(邻)

# 大圆距离
let 上海 = 度转经纬度(31.2304, 121.4737)
echo 大圆距离千米(addr 北京, addr 上海), " km"

# 父级/子级
let 父 = 单元.单元转父级(8)
let 中子 = 父.单元转中心子级(10)

# 字符串互转
let 串 = 单元转字符串(单元)
let 还原 = 字符串转单元(串)
```

完整示例见 [`examples/`](./examples/) 目录。

## API 总览

### 类型

| 中文类型 | 对应 C 类型 | 说明 |
|----------|-------------|------|
| `H3索引` | `H3Index` | distinct uint64 |
| `H3错误` | `H3Error` | distinct uint32 |
| `经纬度` | `LatLng` | 弧度制 lat/lng |
| `单元边界` | `CellBoundary` | 顶点数组（最多 10 个） |
| `地理环` | `GeoLoop` | 可变顶点数组 |
| `地理多边形` | `GeoPolygon` | 外环 + 孔洞 |
| `链接地理多边形` | `LinkedGeoPolygon` | 链表结构 |
| `坐标IJ` | `CoordIJ` | 局部坐标 |
| `迭代子单元` | `IterCellsChildren` | 子单元迭代器 |
| `迭代多边形` | `IterCellsPolygon` | 多边形填充迭代器 |

### 函数分类

#### 核心转换

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `经纬度转单元` | `latLngToCell` |
| `单元转经纬度` | `cellToLatLng` |
| `单元转边界` | `cellToBoundary` |
| `字符串转单元` | `stringToH3` |
| `单元转字符串` | `h3ToString` |

#### 网格查询（k-ring）

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `最大网格圆盘数` | `maxGridDiskSize` |
| `网格圆盘` | `gridDisk` |
| `网格圆盘不安全` | `gridDiskUnsafe` |
| `网格圆盘距离` | `gridDiskDistances` |
| `网格环` | `gridRing` |
| `网格环不安全` | `gridRingUnsafe` |
| `网格距离` | `gridDistance` |
| `网格路径单元` | `gridPathCells` |

#### 层级关系

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元转父级` | `cellToParent` |
| `单元转子级` | `cellToChildren` |
| `单元转中心子级` | `cellToCenterChild` |
| `紧凑单元` | `compactCells` |
| `解紧凑单元` | `uncompactCells` |

#### 多边形填充

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `最大多边形转单元数` | `maxPolygonToCellsSize` |
| `多边形转单元` | `polygonToCells` |
| `单元转链接多边组` | `cellsToLinkedMultiPolygon` |
| `销毁链接多边组` | `destroyLinkedMultiPolygon` |

#### 有向边 & 顶点

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元转有向边` | `cellsToDirectedEdge` |
| `是否有效有向边` | `isValidDirectedEdge` |
| `获取有向边起点` | `getDirectedEdgeOrigin` |
| `获取有向边终点` | `getDirectedEdgeDestination` |
| `单元转顶点集` | `cellToVertexes` |
| `顶点转经纬度` | `vertexToLatLng` |

#### 面积 & 距离

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元面积平方千米` | `cellAreaKm2` |
| `大圆距离千米` | `greatCircleDistanceKm` |
| `边长度千米` | `edgeLengthKm` |
| `获取六边形平均面积平方千米` | `getHexagonAreaAvgKm2` |

#### 查询 & 检查

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `是否有效单元` | `isValidCell` |
| `是否五边形` | `isPentagon` |
| `是否相邻单元` | `areNeighborCells` |
| `获取分辨率` | `getResolution` |
| `获取基单元号` | `getBaseCellNumber` |
| `获取零级单元` | `getRes0Cells` |
| `零级单元数` | `res0CellCount` |
| `获取单元数` | `getNumCells` |

API 完整列表见 [`src/h3nim.nim`](./src/h3nim.nim)。

## 更新 H3 版本

```bash
# H3 C 源码已 vendored 到 src/h3lib/，不再使用 git submodule，
# 因此从 GitHub 安装 / 下载 tarball 时无需额外拉取。
# 更新步骤：
#   1. 从 https://github.com/uber/h3 获取目标版本源码
#   2. 覆盖 src/h3lib/lib/*.c 与 src/h3lib/include/*.h
#   3. 从 h3api.h.in 重新生成 src/h3lib/include/h3api.h
#      并同步版本号：
#        H3_VERSION_MAJOR / H3_VERSION_MINOR / H3_VERSION_PATCH
#        MAX_CELL_BNDRY_VERTS（如变化）
#      如有新增/删除 API，同步更新 src/h3nim.nim
```

### 版本变更检查清单

- [ ] 更新 `src/h3lib/` 下的 vendored C 源码
- [ ] 更新 `src/h3lib/include/h3api.h`（版本号、新增类型、新增函数声明）
- [ ] 检查 `src/h3lib/include/` 下新增/修改的 `.h` 文件
- [ ] 检查 `src/h3lib/lib/` 下新增/删除的 `.c` 文件，同步更新 `{.compile: ...}` 列表
- [ ] 在 `src/h3nim.nim` 中添加/修改对应中文绑定的 `importc` 声明
- [ ] 递增 `h3nim.nimble` 版本号
- [ ] 运行测试 `nim c --path:src -r tests/test_h3nim.nim`
- [ ] 运行示例确认兼容性

## 构建说明

### 依赖

- **Nim** ≥ 2.2.10
- **C 编译器**（GCC / Clang / MSVC）
- **无**外部库依赖 — H3 C 源码已 vendored 到 `src/h3lib/`，随包一起安装与编译

### 平台

| 平台 | 工具链 | 说明 |
|------|--------|------|
| Linux | GCC/Clang | 自动链接 `-lm` |
| macOS | Apple Clang | 自动链接 `-lm` |
| Windows | MSVC (`--cc:vcc`) | 自动定义 `_USE_MATH_DEFINES` |

```bash
# 编译绑定模块
nim c src/h3nim.nim

# Release 构建
nim c -d:release src/h3nim.nim

# 指定 MSVC（Windows）
nim c --cc:vcc src/h3nim.nim
```

### 作为库使用

在 `*.nimble` 中声明依赖：

```nim
# myproject.nimble
requires "h3nim >= 0.1.0"
```

或直接引用源码：

```bash
nim c --path:path/to/h3-nim/src -r myapp.nim
```

## 命名规范

本绑定遵循 [rgame 项目 V8.0 中文代码命名规范](https://github.com/lyj/rgame/blob/master/CODING_STANDARD.md)：

- 函数: `[动作][主体]` — `经纬度转单元`、`查询用户`
- 布尔: `是否` 前缀 — `是否有效单元`、`是否五边形`
- 类型: 中文命名，专有名词保留 — `H3索引`、`经纬度`
- 枚举: 中文命名 — `成功`、`内存分配失败`
- 导出: `*` 后缀 — `经纬度转单元*`

## 许可

Apache-2.0（与 Uber H3 一致）
