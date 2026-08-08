# zsh_musl Specification

## 1. 项目目标

构建并发布可被其他项目直接嵌入的 zsh runtime，避免依赖用户已经安装的
zsh、bash、Node 或 Codex。

首期支持：

```text
Linux amd64  - 静态 musl
Linux arm64  - 静态 musl
macOS amd64  - 原生 Mach-O
macOS arm64  - 原生 Mach-O
```

明确不支持 Windows。

## 2. 重要约束

### Linux

- 使用官方 zsh 源码构建，初始版本固定为 zsh 5.9.2。
- 使用 musl 工具链编译。
- zsh 与 ncurses/terminfo 必须使用同一 musl 工具链构建。
- 关闭动态模块，生成静态可执行文件。
- 不依赖 glibc、libtinfo 或用户安装的 zsh。
- 每个 CPU 架构分别构建，禁止跨架构复用二进制。

### macOS

- 使用 Apple Clang 和对应 macOS SDK 构建。
- macOS 不使用 musl，也不要求 libc 静态链接。
- 允许依赖系统 `/usr/lib/libSystem.B.dylib`，但不能依赖用户安装的 zsh。
- amd64 与 arm64 分别产出原生 Mach-O 文件。
- macOS 构建必须在 macOS runner 上完成最终编译和运行验证。

## 3. 产物格式

每个 Release 发布以下文件：

```text
zsh-5.9.2-linux-amd64-musl.tar.gz
zsh-5.9.2-linux-arm64-musl.tar.gz
zsh-5.9.2-darwin-amd64.tar.gz
zsh-5.9.2-darwin-arm64.tar.gz
SHA256SUMS
```

每个压缩包包含：

```text
bin/zsh
LICENSE.zsh
LICENSE.ncurses
BUILD-METADATA.json
```

`BUILD-METADATA.json` 至少记录：

```json
{
  "zsh_version": "5.9.2",
  "target": "linux-amd64-musl",
  "source_sha256": "...",
  "compiler": "...",
  "build_commit": "..."
}
```

## 4. 推荐目录结构

```text
zsh_musl/
├── spec.md
├── Makefile
├── scripts/
│   ├── build-linux.sh
│   ├── build-macos.sh
│   ├── package.sh
│   └── verify.sh
├── patches/
├── licenses/
└── .github/
    └── workflows/
        ├── ci.yml
        └── release.yml
```

## 5. GitHub Actions

### CI

触发条件：

- Pull Request
- push 到默认分支
- 手动触发

CI 至少验证：

- Linux amd64 构建和运行
- macOS amd64 构建和运行
- shell 基础行为测试
- 产物格式和 license 文件

### Release

触发条件：

```text
推送 v* tag
手动 workflow_dispatch
```

推荐 runner：

```text
Linux amd64: ubuntu-24.04
Linux arm64: ubuntu arm64 runner，或固定的交叉编译环境
macOS amd64: macos-13
macOS arm64: macos-14
```

Release workflow 必须：

1. 下载并校验固定版本的 zsh 源码。
2. 为每个目标分别构建。
3. 运行目标平台验证。
4. 生成 tar.gz 和 SHA256SUMS。
5. 创建 GitHub Release 并上传产物。

GitHub Actions 和第三方 Action 应固定到 commit SHA，避免未锁定的 action
版本影响发布结果。

## 6. 验证标准

### Linux 静态检查

```bash
file bin/zsh
ldd bin/zsh
readelf -d bin/zsh
```

验收要求：

- `file` 显示 statically linked。
- `ldd` 显示 `not a dynamic executable`。
- ELF 不包含动态 section。
- 不出现 glibc、libtinfo 或其他宿主机动态库依赖。

### macOS 检查

```bash
file bin/zsh
otool -L bin/zsh
bin/zsh -f -c 'print -r -- "$ZSH_VERSION"'
```

验收要求：

- 文件架构与产物名称一致。
- 只允许系统库依赖。
- 不调用 `/bin/zsh`。
- 在对应 macOS runner 上可以直接运行。

### 通用行为测试

```bash
bin/zsh -f -c 'print -r -- "$ZSH_VERSION"'
bin/zsh -f -c 'printf "%s\\n" ok'
bin/zsh -f -c 'x=1; test "$x" = 1'
bin/zsh -f -c 'printf "%s\\n" one two | wc -l'
```

重点验证环境变量、管道、重定向、退出码、信号和非交互模式。

## 7. 版本和安全策略

- zsh 源码版本必须显式配置，禁止构建时自动获取 latest。
- 每个源码包保存 SHA256 校验值。
- Release 必须生成 SHA256SUMS。
- 构建日志不得包含 secret、token 或用户路径信息。
- 产物只来自 GitHub Actions，不提交二进制到源代码仓库。
- zsh 和 ncurses 的 license 必须随产物发布。

## 8. 非目标

本项目暂不实现：

- Windows 支持。
- zsh 的完整系统安装器或包管理器。
- 交互式终端 UI。
- zsh plugin、主题和用户配置。
- macOS 的所谓“musl 静态版”。
- 对系统 `/bin/zsh` 的替换或修改。

## 9. 阶段计划

### Phase 1 — Linux amd64

- 构建静态 musl zsh。
- 构建静态 ncurses 依赖。
- 生成 tar.gz、license 和 metadata。
- GitHub Actions CI 验证。

### Phase 2 — Linux arm64

- 增加 arm64 原生或交叉构建环境。
- 增加运行验证。
- 发布 Linux 双架构产物。

### Phase 3 — macOS

- 增加 amd64 和 arm64 macOS runner。
- 构建原生 zsh。
- 增加架构、系统库和运行验证。
- 发布 Darwin 双架构产物。

## 10. 完成标准

项目完成的最低标准：

1. 推送一个版本 tag 后，GitHub Actions 能自动完成构建。
2. Release 中包含 Linux 和 macOS 目标产物。
3. Linux 产物不依赖 glibc 或用户安装的 zsh。
4. macOS 产物不调用系统 `/bin/zsh`。
5. 每个产物都有 SHA256、license 和构建 metadata。
6. 其他项目只需下载对应 tar.gz 即可嵌入使用。
