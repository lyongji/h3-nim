# 更新 H3 版本指南

本文档描述如何升级 h3-nim 内置的 Uber H3 C 源码，并让绑定版本保持一致。

相关文件：

| 文件 | 作用 |
|------|------|
| `update_bindings.nims` | 更新脚本，包含 `update` / `sync` / `header` / `verify` / `info` 任务 |
| `src/h3lib/lib/*.c` | vendored 的 H3 C 实现（由脚本生成，请勿手改） |
| `src/h3lib/include/*.h` | vendored 的 H3 头文件（由脚本生成，请勿手改） |
| `src/h3lib/include/h3api.h.in` | CMake 模板，`h3api.h` 由它生成 |
| `src/h3lib/include/h3api.h` | 由脚本从 `h3api.h.in` 生成（版本宏在其中） |
| `src/h3nim.nim` | Nim 绑定；`{.compile:}` 列表由脚本自动维护 |
| `h3/` | 脚本克隆的上游源码缓存，已被 `.gitignore` 忽略 |

> 设计参考了 [naylib](https://github.com/planetis-m/naylib) 的
> `update_bindings.nims` 与 `manual/update_guide.md`。

## 快速升级

```bash
# 1. 修改 update_bindings.nims 顶部的 H3版本 常量
#    - git tag：  "v4.6.0"
#    - 精确提交： "910f93d5b3d8a072ba4fa8a49c89ea9cc7982165"

# 2. 拉取上游源码并同步到 src/h3lib
nim update update_bindings.nims

# 3. 校验（绑定自检 + 单元测试）
nim verify update_bindings.nims
```

`update` 是幂等的：若 `H3版本` 与当前 vendored 源码一致，重复运行不会产生任何改动。

## 脚本任务

| 命令 | 说明 |
|------|------|
| `nim update update_bindings.nims` | 拉取 `H3版本` → 同步源码/头文件 → 生成 `h3api.h` → 同步编译列表与版本号 |
| `nim sync update_bindings.nims` | 不联网：仅根据已 vendored 的文件重算 `{.compile:}` 列表、回写版本字符串 |
| `nim header update_bindings.nims` | 不联网：仅由 `src/h3lib/include/h3api.h.in` 重新生成 `h3api.h` |
| `nim verify update_bindings.nims` | 运行 `src/h3nim.nim` 自检与 `tests/test_h3nim.nim` 单元测试 |
| `nim info update_bindings.nims` | 打印当前 vendored 版本、C 源文件数量与脚本目标 |

## 脚本做了什么

### 1. 拉取上游源码

在 `h3/`（首次运行时创建，之后复用）中执行：

```bash
git fetch --tags --force --filter=blob:none origin
git fetch --force --filter=blob:none origin <H3版本>
git checkout --force --detach <H3版本>
```

首次克隆使用 **稀疏 + 部分克隆**（`--filter=blob:none --no-checkout`，
并 `git sparse-checkout set src/h3lib`），只检出必需的 `src/h3lib` 与根目录文件，
缓存体积约 5MB（完整克隆约 120MB）。`H3版本` 既可以是 tag（`v4.6.0`），
也可以是 commit（`910f93d5...`）。

### 2. 同步源码到 `src/h3lib/`

`h3/src/h3lib/lib/*.c` 与 `h3/src/h3lib/include/*.h`（含 `h3api.h.in`）
会被完整复制到 `src/h3lib/` 对应目录。`src/h3lib/` 位于 `srcDir` 内，
因此 Nimble 安装时会随包一起复制。

### 3. 生成 `h3api.h`

等价于 CMake 的 `configure_file(h3api.h.in h3api.h)`：把模板里的
`@H3_VERSION_MAJOR@` / `@H3_VERSION_MINOR@` / `@H3_VERSION_PATCH@`
替换成上游 `VERSION` 文件中的版本号（自动去掉 `-rc1` 之类的后缀）。

### 4. 同步编译列表与版本号

- 扫描 `src/h3lib/lib/*.c`，重写 `src/h3nim.nim` 中两个标记之间的内容：

  ```nim
  # >>> h3lib 编译列表（由 update_bindings.nims 自动生成，请勿手动修改）
  {.compile: currentSourcePath.parentDir / "h3lib" / "lib" / "algos.c".}
  ...
  # <<< h3lib 编译列表
  ```

- 从 `h3api.h` 的 `H3_VERSION_*` 宏读取语义版本，回写到以下位置：
  - `h3nim.nimble` 的 `description`
  - `README.md` 首段的 `vX.Y.Z`
  - `src/h3nim.nim` 的模块文档与自检输出

## 版本变更检查清单

运行 `nim update` 后，按以下清单人工复核：

- [ ] `git diff src/h3lib/` 检查 C 源码与头文件变化
- [ ] `git diff src/h3nim.nim` 确认 `{.compile:}` 列表已包含所有新增 `.c`、移除已删除的 `.c`
- [ ] 如 `h3api.h.in` 新增 / 删除 / 修改了公共函数或类型，同步更新 `src/h3nim.nim` 中的 `importc` 绑定（见下节）
- [ ] 确认 `h3nim.nimble` / `README.md` / `src/h3nim.nim` 的版本号已更新
- [ ] `nim verify update_bindings.nims` 全部通过
- [ ] `nimble test` 通过
- [ ] 按需递增 `h3nim.nimble` 中绑定自身的 `version`（H3 升级通常对应次版本号 +1）
- [ ] 在提交信息中注明 H3 版本（如 `chore: bump H3 to v4.6.0`）

## 新增 / 删除 API 时

脚本只能同步 C 源码、头文件、编译列表和版本号，**不能**自动生成 Nim 绑定。
当上游 API 有变化时：

1. 对比 `src/h3lib/include/h3api.h.in` 的差异：

   ```bash
   git diff src/h3lib/include/h3api.h.in
   ```

2. 在 `src/h3nim.nim` 中：
   - 新增函数：按现有风格添加对应中文命名的 `importc` 声明；
   - 新增类型 / 结构体：在「基础类型」区域补充 Nim 类型并映射 C 类型；
   - 删除函数：移除对应绑定；
   - 参数或返回类型变化：同步修改签名。
3. 在 `tests/test_h3nim.nim` 中补充或调整测试。

命名规范见 `README.md` 与 `src/h3nim.nim` 顶部说明（V8.0 中文代码命名规范，
保留 H3 等专有名词英文原样）。

## 常见问题

**Q：`H3版本` 应该用 tag 还是 commit？**

- 固定到正式发布版：用 tag，例如 `"v4.6.0"`，便于阅读与升级。
- 需要包含发布后的修复 / 新特性：用 commit，例如本文档编写时仓库内对应
  `v4.5.0-3-g910f93d5`，即 `"910f93d5b3d8a072ba4fa8a49c89ea9cc7982165"`。

**Q：`h3/` 需要提交吗？**

不需要。它只是脚本的克隆缓存（稀疏部分克隆，约 5MB），已在 `.gitignore`
中忽略。真正随包发布的是 `src/h3lib/`。若想释放磁盘，删除 `h3/` 即可，
下次 `nim update` 会重新创建。

**Q：为什么不用 git submodule？**

Nimble 安装库包时只复制 `srcDir` 下的文件，子模块即使被拉取也不会进入安装目录，
导致安装后无法编译。因此改为把 H3 C 源码 vendored 到 `src/h3lib/`。

**Q：离线时能做什么？**

`nim sync` 与 `nim header` 不需要联网，可基于已 vendored 的文件重新生成
编译列表、版本字符串和 `h3api.h`。
