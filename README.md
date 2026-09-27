# h3-nim

**Uber H3 六边形地理索引系统 — Nim 绑定**

将 Uber H3 v4.5.0 的 C 库完整绑定到 Nim，按照 V8.0 中文代码命名规范，提供全中文 API。

## 特性

- **全 API 覆盖** — 90+ 公共函数、全部公开类型、迭代器
- **中文命名** — `经纬度转单元`、`单元转父级`、`网格圆盘`、`是否有效单元`
- **零外部依赖** — H3 C 源码 vendored 在 `src/h3lib/`，Nim 编译器直接编译，不依赖 git submodule
- **开箱即用** — `nimble install` 后即可 `import h3nim`，git clone 与 tarball 均可
- **跨平台** — Linux / macOS / Windows 均支持
- **类型安全** — `H3索引` 为 `distinct uint64`，编译期防止类型混淆

## 安装

### 通过 Nimble（推荐）

```bash
nimble install https://github.com/lyongji/h3-nim
```

### 从源码

```bash
git clone https://github.com/lyongji/h3-nim
cd h3-nim
nimble install
```

## 快速开始

```bash
# 运行测试
nimble test

# 运行示例
nim c --path:src -r examples/example_basic.nim
nim c --path:src -r examples/example_geofence.nim
nim c --path:src -r examples/example_hierarchy.nim
nim c --path:src -r examples/example_advanced.nim

# 编译绑定自检
nim c src/h3nim.nim
./src/h3nim
```

## 使用示例

```nim
import h3nim

# 经纬度 → H3 索引
let 北京 = 度转经纬度(39.9042, 116.4074)
let 单元 = 北京.经纬度转单元(10)
echo 单元转字符串(单元)  # 8a31aa4282effff

# H3 索引 → 经纬度
let 中心 = 单元.单元转经纬度()
let (纬度, 经度) = 中心.经纬度转度()
echo 纬度, ", ", 经度     # 39.9038, 116.4077

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

## 错误处理

底层 API（以 `*原` 结尾的绑定）返回 `H3错误`，可用 `描述H3错误` 获取可读信息：

```nim
let 单元 = 字符串转单元("8928308280fffff")
var 子级: H3索引
let 错误 = 单元转中心子级(单元, 10, addr 子级)
if 错误 != H3错误(0):
  echo "失败: ", 描述H3错误(错误)
else:
  echo "中心子级: ", 单元转字符串(子级)
```

常用错误码见 `H3错误码` 枚举（`成功`、`分辨率域错误`、`单元无效`、`内存分配失败` 等）。

## 示例

| 文件 | 内容 |
|------|------|
| [`examples/example_basic.nim`](./examples/example_basic.nim) | 经纬度 ↔ 单元、边界、k-ring、距离、属性查询 |
| [`examples/example_geofence.nim`](./examples/example_geofence.nim) | 多边形填充、地理围栏、点包含检测、实验性填充 API |
| [`examples/example_hierarchy.nim`](./examples/example_hierarchy.nim) | 父级/子级、紧凑/解紧凑、网格路径、有向边、顶点 |
| [`examples/example_advanced.nim`](./examples/example_advanced.nim) | 错误处理、索引位与构造、局部 IJ、二十面体面、多边形迭代器 |

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
| `迭代分辨率` | `IterCellsResolution` | 分辨率迭代器 |
| `迭代多边形紧凑` | `IterCellsPolygonCompact` | 紧凑多边形迭代器 |
| `迭代多边形` | `IterCellsPolygon` | 多边形填充迭代器 |

### 函数分类

> 表中为 Nim 便捷 API；对应的 `*原` 版本直接映射 C 签名（使用 `ptr` 输出参数）。

#### 角度转换

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `度转经纬度` / `经纬度转度` | —（Nim 封装） |
| `度转弧度` | `degsToRads` |
| `弧度转度` | `radsToDegs` |

#### 核心转换

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `经纬度转单元` | `latLngToCell` |
| `单元转经纬度` | `cellToLatLng` |
| `单元转边界` | `cellToBoundary` |
| `字符串转单元` | `stringToH3` |
| `单元转字符串` | `h3ToString` |
| `构造单元` | `constructCell` |
| `获取索引位` | `getIndexDigit` |

#### 索引查询与有效性

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `是否有效单元` | `isValidCell` |
| `是否有效索引` | `isValidIndex` |
| `获取分辨率` | `getResolution` |
| `获取基单元号` | `getBaseCellNumber` |
| `是否五边形` | `isPentagon` |
| `是否三级类` | `isResClassIII` |
| `描述H3错误` | `describeH3Error` |

#### 网格查询（k-ring / 环 / 距离 / 路径）

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `最大网格圆盘数` | `maxGridDiskSize` |
| `网格圆盘` | `gridDisk` |
| `网格圆盘不安全` | `gridDiskUnsafe` |
| `网格圆盘距离` | `gridDiskDistances` |
| `网格圆盘距离不安全` | `gridDiskDistancesUnsafe` |
| `网格圆盘距离安全` | `gridDiskDistancesSafe` |
| `网格圆盘集不安全` | `gridDisksUnsafe` |
| `最大网格环数` | `maxGridRingSize` |
| `网格环` | `gridRing` |
| `网格环不安全` | `gridRingUnsafe` |
| `网格距离` | `gridDistance` |
| `网格路径单元数` | `gridPathCellsSize` |
| `网格路径单元` | `gridPathCells` |

#### 层级关系

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元转父级` | `cellToParent` |
| `单元转子级数` | `cellToChildrenSize` |
| `单元转子级` | `cellToChildren` |
| `单元转中心子级` | `cellToCenterChild` |
| `单元转子级位置` | `cellToChildPos` |
| `子级位置转单元` | `childPosToCell` |
| `紧凑单元` | `compactCells` |
| `解紧凑单元数` | `uncompactCellsSize` |
| `解紧凑单元` | `uncompactCells` |

#### 多边形填充

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `最大多边形转单元数` | `maxPolygonToCellsSize` |
| `多边形转单元` | `polygonToCells` |
| `最大多边形转单元数实验` | `maxPolygonToCellsSizeExperimental` |
| `多边形转单元实验` | `polygonToCellsExperimental` |
| `单元转链接多边组` | `cellsToLinkedMultiPolygon` |
| `销毁链接多边组` | `destroyLinkedMultiPolygon` |

> 经典 `多边形转单元` 按哈希槽位写入输出数组，可能含 `H3空` 空洞，需过滤；
> `多边形转单元实验` 连续写入，需传入缓冲区大小。

#### 有向边

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元转有向边` | `cellsToDirectedEdge` |
| `是否有效有向边` | `isValidDirectedEdge` |
| `获取有向边起点` | `getDirectedEdgeOrigin` |
| `获取有向边终点` | `getDirectedEdgeDestination` |
| `有向边转单元` | `directedEdgeToCells` |
| `起点转有向边集` | `originToDirectedEdges` |
| `有向边转边界` | `directedEdgeToBoundary` |
| `反转有向边` | `reverseDirectedEdge` |

#### 顶点

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元转顶点` | `cellToVertex` |
| `单元转顶点集` | `cellToVertexes` |
| `顶点转经纬度` | `vertexToLatLng` |
| `是否有效顶点` | `isValidVertex` |

#### 局部 IJ 坐标

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元转局部IJ` | `cellToLocalIj` |
| `局部IJ转单元` | `localIjToCell` |

#### 邻接与二十面体面

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `是否相邻单元` | `areNeighborCells` |
| `最大面数` | `maxFaceCount` |
| `获取二十面体面` | `getIcosahedronFaces` |

#### 面积、边长与距离

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `单元面积弧度平方` | `cellAreaRads2` |
| `单元面积平方千米` | `cellAreaKm2` |
| `单元面积平方米` | `cellAreaM2` |
| `获取六边形平均面积平方千米` | `getHexagonAreaAvgKm2` |
| `获取六边形平均面积平方米` | `getHexagonAreaAvgM2` |
| `获取六边形平均边长千米` | `getHexagonEdgeLengthAvgKm` |
| `获取六边形平均边长米` | `getHexagonEdgeLengthAvgM` |
| `边长度弧度` | `edgeLengthRads` |
| `边长度千米` | `edgeLengthKm` |
| `边长度米` | `edgeLengthM` |
| `大圆距离弧度` | `greatCircleDistanceRads` |
| `大圆距离千米` | `greatCircleDistanceKm` |
| `大圆距离米` | `greatCircleDistanceM` |

#### 全局单元枚举

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `零级单元数` | `res0CellCount` |
| `获取零级单元` | `getRes0Cells` |
| `五边形数` | `pentagonCount` |
| `获取五边形` | `getPentagons` |
| `获取单元数` | `getNumCells` |

#### 迭代器

| Nim 函数 | 对应 C 函数 |
|----------|-------------|
| `初始化父级迭代` / `步进子级迭代` | `iterInitParent` / `iterStepChild` |
| `初始化基单元迭代` | `iterInitBaseCellNum` |
| `初始化分辨率迭代` / `步进分辨率迭代` | `iterInitRes` / `iterStepRes` |
| `初始化多边形紧凑迭代` / `步进多边形紧凑迭代` / `销毁多边形紧凑迭代` | `iterInitPolygonCompact` / `iterStepPolygonCompact` / `iterDestroyPolygonCompact` |
| `初始化多边形迭代` / `步进多边形迭代` / `销毁多边形迭代` | `iterInitPolygon` / `iterStepPolygon` / `iterDestroyPolygon` |

API 完整列表见 [`src/h3nim.nim`](./src/h3nim.nim)。

## 更新 H3 版本

H3 C 源码已 vendored 到 `src/h3lib/`，不依赖 git submodule，
`git clone` 与 tarball 安装均可直接使用。升级 / 同步版本统一由
[`update_bindings.nims`](./update_bindings.nims) 完成：

```bash
# 1. 修改 update_bindings.nims 中的 H3版本（git tag 或 commit）
# 2. 拉取上游源码并同步到 src/h3lib（源码、头文件、编译列表、版本号）
nim update update_bindings.nims

# 3. 校验（绑定自检 + 单元测试）
nim verify update_bindings.nims
```

其他可选任务：

```bash
nim sync   update_bindings.nims   # 仅同步版本号与 {.compile:} 列表
nim header update_bindings.nims   # 仅由 h3api.h.in 重新生成 h3api.h
nim info   update_bindings.nims   # 查看当前 vendored 版本
```

完整流程、版本变更检查清单以及新增 / 删除 API 的处理方式见
[`manual/update_guide.md`](./manual/update_guide.md)。

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
