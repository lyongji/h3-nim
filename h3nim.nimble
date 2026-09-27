# Package

version       = "0.2.0"
author        = "lyj"
description   = "Uber H3 六边形地理索引系统 Nim 绑定 (v4.5.0)"
license       = "Apache-2.0"
srcDir        = "src"
binDir        = "bin"

# 无外部依赖 — C 编译器后端直接编译 vendored H3 源码
requires "nim >= 2.2.10"

proc build() =
  # 编译时传递平台相关标志
  when defined(windows):
    --passC:"-D_USE_MATH_DEFINES"
  when defined(linux) or defined(macosx):
    --passL:"-lm"

proc test() =
  # 运行测试
  exec "nim c -r src/h3nim.nim"
  # 单元测试
  exec "nim c -r tests/test_h3nim.nim"
