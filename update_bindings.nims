## H3 绑定更新脚本
##
## 用法（在仓库根目录执行）：
##   nim update update_bindings.nims   # 拉取指定 H3 版本并同步到 src/h3lib
##   nim sync   update_bindings.nims   # 仅根据已 vendored 的文件同步版本号与编译列表
##   nim header update_bindings.nims   # 仅重新生成 src/h3lib/include/h3api.h
##   nim verify update_bindings.nims   # 运行绑定自检与单元测试
##
## 参考 naylib 的 update_bindings.nims 设计。

import std/[os, strutils, algorithm]

const
  H3仓库 = "https://github.com/uber/h3.git"

  ## 目标 H3 版本：可以是 git tag（如 "v4.5.0"）或 commit。
  ## 当前 vendored 源码对应 v4.5.0-3-g910f93d5（v4.5.0 之后 3 个提交，
  ## 其中 44189b11 增加了 Gosper 边界迭代器）；若要固定到正式发布版，
  ## 改为 "v4.5.0" 即可。升级时把这里改成新版本后运行 update。
  H3版本 = "910f93d5b3d8a072ba4fa8a49c89ea9cc7982165"

  H3目录 = thisDir() / "h3"                 # 上游源码克隆缓存（.gitignore）
  H3库目录 = thisDir() / "src" / "h3lib"    # vendored 源码根目录
  H3源文件目录 = H3库目录 / "lib"
  H3头文件目录 = H3库目录 / "include"
  Nim绑定文件 = thisDir() / "src" / "h3nim.nim"
  Nimble文件 = thisDir() / "h3nim.nimble"
  README文件 = thisDir() / "README.md"

  ###### 自动生成区域标记（与 src/h3nim.nim 中的注释保持一致）######
  编译列表开始 = "# >>> h3lib 编译列表"
  编译列表结束 = "# <<< h3lib 编译列表"

# ── 通用工具 ─────────────────────────────────────

proc 替换区间(文件, 开始标记, 结束标记, 新内容: string) =
  ## 把文件中 [开始标记 .. 结束标记] 之间的内容替换为 `新内容`。
  let 原文 = readFile(文件)
  let 起 = 原文.find(开始标记)
  if 起 < 0:
    quit "在 " & 文件 & " 中找不到开始标记: " & 开始标记
  let 止 = 原文.find(结束标记, 起 + 开始标记.len)
  if 止 < 0:
    quit "在 " & 文件 & " 中找不到结束标记: " & 结束标记
  writeFile(文件, 原文[0 ..< 起] & 新内容 & 原文[止 + 结束标记.len .. ^1])

proc 替换版本(文件, 前缀, 后缀, 新版本: string) =
  ## 把文件中 `前缀` 与 `后缀` 之间的内容替换为 `新版本`。
  let 原文 = readFile(文件)
  let 起 = 原文.find(前缀)
  if 起 < 0:
    echo "警告: " & 文件 & " 中找不到前缀: " & 前缀
    return
  let 值起 = 起 + 前缀.len
  let 止 = 原文.find(后缀, 值起)
  if 止 < 0:
    echo "警告: " & 文件 & " 中找不到后缀: " & 后缀
    return
  writeFile(文件, 原文[0 ..< 值起] & 新版本 & 原文[止 .. ^1])

proc 取宏值(头文件, 宏名: string): string =
  ## 从 C 头文件中取出 `#define 宏名 值` 的数字值。
  let 原文 = readFile(头文件)
  let 标记 = "#define " & 宏名
  let 起 = 原文.find(标记)
  if 起 < 0:
    quit "在 " & 头文件 & " 中找不到 " & 宏名
  var 值起 = 起 + 标记.len
  while 值起 < 原文.len and 原文[值起] in {' ', '\t'}:
    inc 值起
  var 值止 = 值起
  while 值止 < 原文.len and 原文[值止] in {'0' .. '9'}:
    inc 值止
  if 值止 == 值起:
    quit "无法解析 " & 宏名 & " 的值"
  result = 原文[值起 ..< 值止]

proc 读取Vendored版本(): string =
  ## 从 vendored 的 h3api.h 宏中读取语义版本，如 "4.5.0"。
  let 头 = H3头文件目录 / "h3api.h"
  if not fileExists(头):
    quit "找不到 " & 头 & "，请先运行 update"
  result = 取宏值(头, "H3_VERSION_MAJOR") & "." &
          取宏值(头, "H3_VERSION_MINOR") & "." &
          取宏值(头, "H3_VERSION_PATCH")

# ── 步骤 1: 拉取上游源码 ─────────────────────────

proc 拉取H3() =
  let 标记 = H3目录 / ".sparse-partial"
  if dirExists(H3目录) and not fileExists(标记):
    # 兼容旧版脚本留下的完整克隆，重建为稀疏部分克隆
    echo "重建稀疏克隆缓存 " & H3目录
    rmDir(H3目录)
  if not dirExists(H3目录):
    echo "克隆 " & H3仓库 & " -> " & H3目录 & "（稀疏 + 部分克隆）"
    # 只检出 src/h3lib，缓存体积从 ~120MB 降到 ~5MB
    exec "git clone --filter=blob:none --no-checkout " & H3仓库 & " " &
         quoteShell(H3目录)
    withDir(H3目录):
      exec "git sparse-checkout init --cone"
      exec "git sparse-checkout set src/h3lib"
      writeFile(".sparse-partial", "1")
  withDir(H3目录):
    echo "获取 " & H3版本
    # tag / 分支 / commit 都可以通过下面两条 fetch 拿到
    exec "git fetch --tags --force --filter=blob:none origin"
    exec "git fetch --force --filter=blob:none origin " & quoteShell(H3版本)
    exec "git checkout --force --detach " & quoteShell(H3版本)
    echo "已检出版本: " & readFile("VERSION").strip()

# ── 步骤 2: 复制源码到 src/h3lib ─────────────────

proc 同步源码() =
  echo "同步 C 源码与头文件到 " & H3库目录
  if dirExists(H3源文件目录): rmDir(H3源文件目录)
  if dirExists(H3头文件目录): rmDir(H3头文件目录)
  cpDir(H3目录 / "src" / "h3lib" / "lib", H3源文件目录)
  cpDir(H3目录 / "src" / "h3lib" / "include", H3头文件目录)

# ── 步骤 3: 由 h3api.h.in 生成 h3api.h ───────────

proc 取版本号(): string =
  ## 优先用上游克隆的 VERSION（update 时拿到新版本），
  ## 否则回退到已 vendored 的 h3api.h（header 任务离线可用）。
  if fileExists(H3目录 / "VERSION"):
    result = readFile(H3目录 / "VERSION").strip()
  elif fileExists(H3头文件目录 / "h3api.h"):
    result = 读取Vendored版本()
  else:
    quit "找不到版本号来源（既无 h3/VERSION 也无 h3api.h）"

proc 生成头文件() =
  ## 等价于 CMake 的 configure_file(h3api.h.in h3api.h)：
  ## 把 @H3_VERSION_*@ 替换成 VERSION 文件中的版本号。
  let 模板 = H3头文件目录 / "h3api.h.in"
  if not fileExists(模板):
    quit "找不到 " & 模板 & "，请先运行 update"
  let 版本号 = 取版本号()
  let 段 = 版本号.split('.')
  if 段.len < 3:
    quit "无法解析版本号: " & 版本号
  var 补丁 = 段[2]
  let 短横 = 补丁.find('-') # 去掉 -rc1 之类的后缀
  if 短横 >= 0: 补丁 = 补丁[0 ..< 短横]
  var 内容 = readFile(模板)
  内容 = 内容.replace("@H3_VERSION_MAJOR@", 段[0])
  内容 = 内容.replace("@H3_VERSION_MINOR@", 段[1])
  内容 = 内容.replace("@H3_VERSION_PATCH@", 补丁)
  writeFile(H3头文件目录 / "h3api.h", 内容)
  echo "已生成 " & (H3头文件目录 / "h3api.h") & " (v" & 版本号 & ")"

# ── 步骤 4: 同步编译列表与版本字符串 ─────────────

proc 生成编译列表() =
  var 源文件: seq[string]
  for 类型, 路径 in walkDir(H3源文件目录):
    if 类型 == pcFile and 路径.endsWith(".c"):
      源文件.add 路径.extractFilename
  源文件.sort()
  if 源文件.len == 0:
    quit H3源文件目录 & " 下没有 .c 文件"
  var 块 = 编译列表开始 & "（由 update_bindings.nims 自动生成，请勿手动修改）\n"
  for 文件 in 源文件:
    块.add "{.compile: currentSourcePath.parentDir / \"h3lib\" / \"lib\" / \"" &
           文件 & "\".}\n"
  块.add 编译列表结束
  替换区间(Nim绑定文件, 编译列表开始, 编译列表结束, 块)
  echo "已同步 " & $源文件.len & " 个 C 源文件到编译列表"

proc 同步版本字符串() =
  let 版本号 = 读取Vendored版本()
  替换版本(Nimble文件, " Nim 绑定 (v", ")", 版本号)
  替换版本(README文件, "将 Uber H3 v", " 的 C 库", 版本号)
  替换版本(Nim绑定文件, "地理索引系统（v", "）", 版本号)
  替换版本(Nim绑定文件, "H3 Nim 绑定 v", " — 自检开始", 版本号)
  echo "已同步版本号: v" & 版本号

# ── 任务 ─────────────────────────────────────────

task update, "拉取指定 H3 版本并同步到 src/h3lib":
  拉取H3()
  同步源码()
  生成头文件()
  生成编译列表()
  同步版本字符串()
  echo "\n完成: H3 v" & 读取Vendored版本() &
       " 已同步。请运行 `nim verify update_bindings.nims` 验证。"

task sync, "根据已 vendored 的文件同步版本号与编译列表":
  生成编译列表()
  同步版本字符串()

task header, "重新生成 src/h3lib/include/h3api.h":
  生成头文件()

task verify, "运行绑定自检与单元测试":
  exec "nim c -r --path:src src/h3nim.nim"
  exec "nim c -r --path:src tests/test_h3nim.nim"

task info, "打印当前 vendored 的 H3 版本与源码文件数":
  var 数量 = 0
  for 类型, 路径 in walkDir(H3源文件目录):
    if 类型 == pcFile and 路径.endsWith(".c"): inc 数量
  echo "vendored H3 版本: v" & 读取Vendored版本()
  echo "C 源文件数量: " & $数量
  echo "脚本目标: " & H3版本
