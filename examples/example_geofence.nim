## 地理围栏示例：多边形区域内的 H3 单元覆盖
##
## 使用: nim c --path:src -r examples/example_geofence.nim

import std/[math, strformat, sequtils]
import h3nim

# ── 定义一个简单多边形（北京故宫区域，近似）────

proc 故宫多边形(): 地理多边形 =
  ## 故宫近似边界（经纬度度）
  const 故宫顶点 = [
    (39.9150, 116.3970),  # 西北
    (39.9150, 116.4030),  # 东北
    (39.9070, 116.4030),  # 东南
    (39.9070, 116.3970),  # 西南
  ]
  var 环 = 地理环(
    顶点数: 4,
    顶点: cast[ptr 经纬度](alloc0(sizeof(经纬度) * 4)),
  )
  let 顶点数组 = cast[ptr array[4, 经纬度]](环.顶点)
  for i, (lat, lng) in 故宫顶点:
    顶点数组[i] = 度转经纬度(lat, lng)
  result = 地理多边形(外环: 环, 孔数: 0, 孔: nil)

proc 释放*(多边形: 地理多边形) =
  if 多边形.外环.顶点 != nil:
    dealloc(多边形.外环.顶点)

# ── 计算多边形内的 H3 单元 ──────────────────

echo "=== 故宫区域 H3 覆盖 ==="
let 故宫 = 故宫多边形()

for 分辨率 in [8, 9]:
  var 预估数: int64
  if 最大多边形转单元数(addr 故宫, 分辨率.cint, 0, addr 预估数) != H3错误(0):
    echo &"  res {分辨率}: 无法计算"
    continue

  # ponytail: maxPolygonToCellsSize 返回的是宽松上界，分配 ut 即可
  let 分配数 = min(预估数, 10_000)
  var 结果 = newSeq[H3索引](分配数)
  let 错误 = 多边形转单元(addr 故宫, 分辨率.cint, 0, addr 结果[0])
  if 错误 == H3错误(0):
    let 有效数 = 结果.countIt(it != H3空)
    echo &"  res {分辨率}: 预估 {预估数}, 实际 {有效数} 个单元"

    echo "  部分单元:"
    for i in 0..<min(有效数, 5):
      echo &"    {单元转字符串(结果[i])}"

故宫.释放()

# ── 点包含检测（用 H3 覆盖判断）─────────────

echo "\n=== 点包含检测 ==="
let 故宫覆盖 = 故宫多边形()
var 估: int64
if 最大多边形转单元数(addr 故宫覆盖, 13.cint, 0, addr 估) == H3错误(0):
  let 限额 = min(估, 200_000)
  var 覆盖集 = newSeq[H3索引](限额)
  if 多边形转单元(addr 故宫覆盖, 13.cint, 0, addr 覆盖集[0]) == H3错误(0):
    let 覆盖有效 = 覆盖集.countIt(it != H3空)
    echo &"故宫 res 13 覆盖: {覆盖有效} 个六边形"

    let 午门 = 度转经纬度(39.9093, 116.3972)
    let 国贸 = 度转经纬度(39.9082, 116.4605)
    let 午门单元 = 午门.经纬度转单元(13)
    let 国贸单元 = 国贸.经纬度转单元(13)
    echo &"午门({单元转字符串(午门单元)}) 在故宫内: {午门单元 in 覆盖集}"
    echo &"国贸({单元转字符串(国贸单元)}) 在故宫内: {国贸单元 in 覆盖集}"
故宫覆盖.释放()

# ── 大范围区域统计（低分辨率）───────────────

echo "\n=== 北京市粗略覆盖统计 ==="
proc 北京矩形(): 地理多边形 =
  const 顶点 = [
    (40.25, 116.10), (40.25, 116.75),
    (39.70, 116.75), (39.70, 116.10),
  ]
  var 环 = 地理环(顶点数: 4, 顶点: cast[ptr 经纬度](alloc0(sizeof(经纬度) * 4)))
  let 顶点数组 = cast[ptr array[4, 经纬度]](环.顶点)
  for i, (lat, lng) in 顶点:
    顶点数组[i] = 度转经纬度(lat, lng)
  result = 地理多边形(外环: 环)

let 北京框 = 北京矩形()
var 预估: int64
if 最大多边形转单元数(addr 北京框, 7.cint, 0, addr 预估) == H3错误(0):
  let 分配 = min(预估, 50_000)
  var 覆盖 = newSeq[H3索引](分配)
  if 多边形转单元(addr 北京框, 7.cint, 0, addr 覆盖[0]) == H3错误(0):
    let 有效 = 覆盖.countIt(it != H3空)
    echo &"res 7: {有效} 个六边形 (~{有效 * 23} km²)"
dealloc(北京框.外环.顶点)

echo "\n✅ 地理围栏示例完成"
