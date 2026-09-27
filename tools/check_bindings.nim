## H3 绑定一致性静态校验
##
## 校验 src/h3nim.nim 中手写的 importc 绑定是否与 vendored 的 H3 C 头文件一致：
##   1. 函数签名：函数名、参数个数、参数类型、返回类型
##   2. 结构体 ABI：sizeof 与字段 offsetof（由 C 编译器按真实头文件计算）
##
## 用法（仓库根目录）：
##   nim c -r --path:src tools/check_bindings.nim
## 退出码非 0 表示存在不一致。
##
## 校验失败通常意味着 H3 升级后 C API 变化而 Nim 绑定未同步，
## 请按 manual/update_guide.md 更新 src/h3nim.nim。

import std/[os, strutils, tables, algorithm, strformat, sequtils]
import h3nim

const
  仓库根 = currentSourcePath.parentDir.parentDir
  头文件目录 = 仓库根 / "src" / "h3lib" / "include"
  绑定文件 = 仓库根 / "src" / "h3nim.nim"

# ── 待校验的结构体 ───────────────────────────────
# 新增/删除绑定的结构体时，请同步维护这里的 emit 报告与 nimLayout。

{.emit: """
#include <stddef.h>
#include <stdio.h>
#include "h3api.h"
#include "iterators.h"
#include "polyfill.h"
#include "bbox.h"

static void h3nim_layout_report(char *buf, size_t n) {
  snprintf(buf, n,
    "LatLng|%zu|%zu|%zu\n"
    "CellBoundary|%zu|%zu|%zu\n"
    "GeoLoop|%zu|%zu|%zu\n"
    "GeoPolygon|%zu|%zu|%zu|%zu\n"
    "LinkedLatLng|%zu|%zu|%zu\n"
    "LinkedGeoLoop|%zu|%zu|%zu|%zu\n"
    "LinkedGeoPolygon|%zu|%zu|%zu|%zu\n"
    "CoordIJ|%zu|%zu|%zu\n"
    "IterCellsChildren|%zu|%zu|%zu|%zu\n"
    "IterCellsResolution|%zu|%zu|%zu|%zu|%zu\n"
    "IterCellsPolygonCompact|%zu|%zu|%zu|%zu|%zu|%zu|%zu|%zu\n"
    "IterCellsPolygon|%zu|%zu|%zu|%zu|%zu\n",
    sizeof(LatLng), offsetof(LatLng, lat), offsetof(LatLng, lng),
    sizeof(CellBoundary), offsetof(CellBoundary, numVerts), offsetof(CellBoundary, verts),
    sizeof(GeoLoop), offsetof(GeoLoop, numVerts), offsetof(GeoLoop, verts),
    sizeof(GeoPolygon), offsetof(GeoPolygon, geoloop), offsetof(GeoPolygon, numHoles),
      offsetof(GeoPolygon, holes),
    sizeof(LinkedLatLng), offsetof(LinkedLatLng, vertex), offsetof(LinkedLatLng, next),
    sizeof(LinkedGeoLoop), offsetof(LinkedGeoLoop, first), offsetof(LinkedGeoLoop, last),
      offsetof(LinkedGeoLoop, next),
    sizeof(LinkedGeoPolygon), offsetof(LinkedGeoPolygon, first),
      offsetof(LinkedGeoPolygon, last), offsetof(LinkedGeoPolygon, next),
    sizeof(CoordIJ), offsetof(CoordIJ, i), offsetof(CoordIJ, j),
    sizeof(IterCellsChildren), offsetof(IterCellsChildren, h),
      offsetof(IterCellsChildren, _parentRes), offsetof(IterCellsChildren, _skipDigit),
    sizeof(IterCellsResolution), offsetof(IterCellsResolution, h),
      offsetof(IterCellsResolution, _baseCellNum), offsetof(IterCellsResolution, _res),
      offsetof(IterCellsResolution, _itC),
    sizeof(IterCellsPolygonCompact), offsetof(IterCellsPolygonCompact, cell),
      offsetof(IterCellsPolygonCompact, error), offsetof(IterCellsPolygonCompact, _res),
      offsetof(IterCellsPolygonCompact, _flags), offsetof(IterCellsPolygonCompact, _polygon),
      offsetof(IterCellsPolygonCompact, _bboxes), offsetof(IterCellsPolygonCompact, _started),
    sizeof(IterCellsPolygon), offsetof(IterCellsPolygon, cell),
      offsetof(IterCellsPolygon, error), offsetof(IterCellsPolygon, _cellIter),
      offsetof(IterCellsPolygon, _childIter));
}
""".}

proc h3nimLayoutReport(buf: cstring, n: csize_t) {.importc: "h3nim_layout_report".}

# ── 类型映射 ─────────────────────────────────────

const C到Nim = {
  "H3Index": "H3索引", "H3Error": "H3错误",
  "int": "cint", "int32_t": "cint", "int64_t": "int64", "uint32_t": "uint32",
  "size_t": "csize_t", "double": "float64", "char": "cstring",
  "LatLng": "经纬度", "CellBoundary": "单元边界", "GeoPolygon": "地理多边形",
  "GeoLoop": "地理环", "CoordIJ": "坐标IJ", "LinkedGeoPolygon": "链接地理多边形",
  "IterCellsChildren": "迭代子单元", "IterCellsResolution": "迭代分辨率",
  "IterCellsPolygonCompact": "迭代多边形紧凑", "IterCellsPolygon": "迭代多边形",
}.toTable

const C返回到Nim = {
  "H3Error": "H3错误", "int": "cint", "double": "float64", "void": "",
  "const char *": "cstring", "char *": "cstring",
  "IterCellsChildren": "迭代子单元", "IterCellsResolution": "迭代分辨率",
  "IterCellsPolygonCompact": "迭代多边形紧凑", "IterCellsPolygon": "迭代多边形",
}.toTable

type
  C声明 = object
    返回类型: string
    参数: string

var 问题: seq[string]

proc 报错(msg: string) =
  问题.add msg

# ── C 头文件解析 ─────────────────────────────────

proc 括号内容(s: string, 开: int): string =
  ## 返回 s[开] 处 '(' 匹配的 ')' 之间的内容。
  var 深度 = 0
  var i = 开
  while i < s.len:
    if s[i] == '(': inc 深度
    elif s[i] == ')':
      dec 深度
      if 深度 == 0:
        return s[开 + 1 ..< i]
    inc i
  result = ""

proc 解析H3API(): Table[string, C声明] =
  let 文本 = readFile(头文件目录 / "h3api.h")
  var i = 0
  while true:
    let p = 文本.find("H3_EXPORT(", i)
    if p < 0: break
    let 名末 = 文本.find(')', p)
    if 名末 < 0: break
    let 名称 = 文本[p + "H3_EXPORT(".len ..< 名末]
    var q = 名末 + 1
    while q < 文本.len and 文本[q] in {' ', '\t'}: inc q
    if q < 文本.len and 文本[q] == '(':
      # 返回类型：本行 H3_EXPORT 之前、去掉 DECLSPEC
      let 行首 = 文本.rfind('\n', 0, p) + 1
      var 返回 = 文本[行首 ..< p].strip()
      if 返回.startsWith("DECLSPEC"):
        返回 = 返回["DECLSPEC".len .. ^1].strip()
      result[名称] = C声明(返回类型: 返回, 参数: 括号内容(文本, q))
      i = q + 1
    else:
      i = 名末 + 1

proc 解析DECLSPEC头文件(路径: string): seq[(string, C声明)] =
  let 文本 = readFile(路径)
  for 语句 in 文本.split(';'):
    let d = 语句.find("DECLSPEC")
    if d < 0: continue
    let 括号 = 语句.find('(', d)
    if 括号 < 0: continue
    let 前部 = 语句[d + "DECLSPEC".len ..< 括号].strip()
    let 词 = 前部.splitWhitespace()
    if 词.len < 2: continue
    let 名称 = 词[^1]
    let 返回 = 词[0 ..< ^1].join(" ")
    result.add (名称, C声明(返回类型: 返回, 参数: 括号内容(语句, 括号)))

proc 解析C函数(): Table[string, C声明] =
  result = 解析H3API()
  for 路径 in ["iterators.h", "polyfill.h"]:
    for (名称, 声明) in 解析DECLSPEC头文件(头文件目录 / 路径):
      result[名称] = 声明

# ── Nim 绑定解析 ─────────────────────────────────

proc 匹配括号(s: string, 开: int): int =
  var 深度 = 0
  for i in 开 ..< s.len:
    if s[i] == '(': inc 深度
    elif s[i] == ')':
      dec 深度
      if 深度 == 0: return i
  result = -1

proc 解析Nim绑定(): Table[string, C声明] =
  let 文本 = readFile(绑定文件)
  for 块 in 文本.split("\nproc "):
    let 括号 = 块.find('(')
    if 括号 < 0: continue
    let 右 = 匹配括号(块, 括号)
    if 右 < 0: continue
    let 参数 = 块[括号 + 1 ..< 右]
    let 之后 = 块[右 + 1 .. ^1]
    let im = 之后.find("importc:")
    if im < 0: continue
    let q1 = 之后.find('"', im) + 1
    let q2 = 之后.find('"', q1)
    if q1 <= 0 or q2 < 0: continue
    let c名 = 之后[q1 ..< q2]
    # 返回类型：跳过空白后若为 ':' 则读到 '{'、'=' 或换行
    var k = 0
    while k < 之后.len and 之后[k] in {' ', '\t'}: inc k
    var 返回 = ""
    if k < 之后.len and 之后[k] == ':':
      inc k
      var e = k
      while e < 之后.len and 之后[e] notin {'{', '=', '\n'}: inc e
      返回 = 之后[k ..< e].strip()
    result[c名] = C声明(返回类型: 返回, 参数: 参数)

# ── 参数类型解析 ─────────────────────────────────

proc 拆分顶层(参数: string, 分隔: char): seq[string] =
  var 深度 = 0
  var 当前 = ""
  for ch in 参数:
    if ch in {'(', '['}: inc 深度
    elif ch in {')', ']'}: dec 深度
    if ch == 分隔 and 深度 == 0:
      result.add 当前
      当前 = ""
    else:
      当前.add ch
  result.add 当前

proc C参数类型(参数: string): seq[string] =
  if 参数.strip() in ["", "void"]: return @[]
  for 段 in 拆分顶层(参数, ','):
    var s = 段.strip().replace("const ", "")
    let 是指针 = '*' in s
    s = s.replace("*", "")
    # 去掉数组维度
    while '[' in s:
      let a = s.find('[')
      let b = s.find(']', a)
      if b < 0: break
      s = s[0 ..< a] & s[b + 1 .. ^1]
    let 词 = s.splitWhitespace()
    if 词.len == 0: continue
    let 基 = 词[0]
    if 基 notin C到Nim:
      result.add "?" & 基
    else:
      var t = C到Nim[基]
      if 是指针 and t != "cstring": t = "ptr " & t
      result.add t

proc Nim参数类型(参数: string): seq[string] =
  if 参数.strip() == "": return @[]
  var 挂起 = 0
  for 段 in 参数.split(','):
    let p = 段.strip()
    let 冒号 = p.find(':')
    if 冒号 >= 0:
      let cnt = 1 + 挂起
      挂起 = 0
      let t = p[冒号 + 1 .. ^1].strip()
      for _ in 0 ..< cnt: result.add t
    else:
      inc 挂起

proc C返回类型(返回: string): string =
  let r = 返回.strip()
  if r in C返回到Nim: C返回到Nim[r]
  else: "?" & r

# ── 校验 ─────────────────────────────────────────

proc 校验签名() =
  let c函数 = 解析C函数()
  let nim绑定 = 解析Nim绑定()

  echo &"签名校验：C 函数 {c函数.len} 个，Nim importc {nim绑定.len} 个"

  for 名称 in c函数.keys.toSeq.sorted:
    if 名称 notin nim绑定:
      报错 &"缺少绑定: {名称}"
      continue
    let cp = C参数类型(c函数[名称].参数)
    let np = Nim参数类型(nim绑定[名称].参数)
    let c返回 = C返回类型(c函数[名称].返回类型)
    let n返回 = nim绑定[名称].返回类型
    if cp.len != np.len:
      报错 &"参数个数不匹配 {名称}: C={cp.len} Nim={np.len}"
    else:
      for idx in 0 ..< cp.len:
        if cp[idx] != np[idx]:
          报错 &"参数类型不匹配 {名称}[{idx}]: C={cp[idx]} Nim={np[idx]}"
    if c返回 != n返回:
      报错 &"返回类型不匹配 {名称}: C={c返回} Nim={n返回}"

  for 名称 in nim绑定.keys.toSeq.sorted:
    if 名称 notin c函数:
      报错 &"多余绑定（C 头文件中不存在）: {名称}"

# ── 结构体 ABI 校验 ──────────────────────────────

proc nimLayout(): Table[string, tuple[大小: int, 偏移: seq[int]]] =
  result["LatLng"] = (sizeof(经纬度), @[offsetOf(经纬度, 纬度), offsetOf(经纬度, 经度)])
  result["CellBoundary"] = (sizeof(单元边界), @[offsetOf(单元边界, 顶点数), offsetOf(单元边界, 顶点)])
  result["GeoLoop"] = (sizeof(地理环), @[offsetOf(地理环, 顶点数), offsetOf(地理环, 顶点)])
  result["GeoPolygon"] = (sizeof(地理多边形), @[offsetOf(地理多边形, 外环), offsetOf(地理多边形, 孔数), offsetOf(地理多边形, 孔)])
  result["LinkedLatLng"] = (sizeof(链接经纬度), @[offsetOf(链接经纬度, 坐标), offsetOf(链接经纬度, 下一)])
  result["LinkedGeoLoop"] = (sizeof(链接地理环), @[offsetOf(链接地理环, 首), offsetOf(链接地理环, 尾), offsetOf(链接地理环, 下一)])
  result["LinkedGeoPolygon"] = (sizeof(链接地理多边形), @[offsetOf(链接地理多边形, 首), offsetOf(链接地理多边形, 尾), offsetOf(链接地理多边形, 下一)])
  result["CoordIJ"] = (sizeof(坐标IJ), @[offsetOf(坐标IJ, i), offsetOf(坐标IJ, j)])
  result["IterCellsChildren"] = (sizeof(迭代子单元), @[offsetOf(迭代子单元, 单元), offsetOf(迭代子单元, 父级分辨率), offsetOf(迭代子单元, 跳过位)])
  result["IterCellsResolution"] = (sizeof(迭代分辨率), @[offsetOf(迭代分辨率, 单元), offsetOf(迭代分辨率, 基单元号), offsetOf(迭代分辨率, 分辨率), offsetOf(迭代分辨率, 子迭代)])
  result["IterCellsPolygonCompact"] = (sizeof(迭代多边形紧凑), @[offsetOf(迭代多边形紧凑, 单元), offsetOf(迭代多边形紧凑, 错误), offsetOf(迭代多边形紧凑, 目标分辨率), offsetOf(迭代多边形紧凑, 标志), offsetOf(迭代多边形紧凑, 多边形), offsetOf(迭代多边形紧凑, 包围盒), offsetOf(迭代多边形紧凑, 已开始)])
  result["IterCellsPolygon"] = (sizeof(迭代多边形), @[offsetOf(迭代多边形, 单元), offsetOf(迭代多边形, 错误), offsetOf(迭代多边形, 单元迭代), offsetOf(迭代多边形, 子迭代)])

proc 校验布局() =
  var 缓冲: array[8192, char]
  h3nimLayoutReport(cast[cstring](addr 缓冲[0]), 8192)
  let nim = nimLayout()
  var 已查 = 0
  for 行 in ($cast[cstring](addr 缓冲[0])).splitLines():
    if 行.len == 0: continue
    let 段 = 行.split('|')
    if 段.len < 3: continue
    let 名称 = 段[0]
    let c大小 = parseInt(段[1])
    var c偏移: seq[int]
    for i in 2 ..< 段.len: c偏移.add parseInt(段[i])
    if 名称 notin nim:
      报错 &"结构体 {名称}: checker 缺少对应的 Nim 布局"
      continue
    inc 已查
    if nim[名称].大小 != c大小:
      报错 &"结构体大小不匹配 {名称}: C={c大小} Nim={nim[名称].大小}"
    if nim[名称].偏移.len != c偏移.len:
      报错 &"结构体字段数不匹配 {名称}: C={c偏移.len} Nim={nim[名称].偏移.len}"
    else:
      for i in 0 ..< c偏移.len:
        if nim[名称].偏移[i] != c偏移[i]:
          报错 &"结构体字段偏移不匹配 {名称}[{i}]: C={c偏移[i]} Nim={nim[名称].偏移[i]}"
  echo &"结构体 ABI 校验：{已查} 个结构体"

# ── 主流程 ───────────────────────────────────────

校验签名()
校验布局()

if 问题.len > 0:
  echo &"\n发现 {问题.len} 处不一致："
  for p in 问题: echo "  ✗ ", p
  echo "\n请按 manual/update_guide.md 同步 src/h3nim.nim 后重试。"
  quit(1)
else:
  echo "\n✓ 绑定与 H3 C 头文件一致。"
