# 在其他项目中使用 zsh Release

Release 地址：<https://github.com/2niuhe/zsh_musl/releases/tag/v5.9.2>

## 1. 选择并下载目标包

按运行平台选择对应文件：

| 平台 | 文件 |
| --- | --- |
| Linux amd64 | `zsh-5.9.2-linux-amd64-musl.tar.gz` |
| Linux arm64 | `zsh-5.9.2-linux-arm64-musl.tar.gz` |
| macOS amd64 | `zsh-5.9.2-darwin-amd64.tar.gz` |
| macOS arm64 | `zsh-5.9.2-darwin-arm64.tar.gz` |

例如：

```sh
base=https://github.com/2niuhe/zsh_musl/releases/download/v5.9.2
archive=zsh-5.9.2-linux-amd64-musl.tar.gz
curl -fsSLo "$archive" "$base/$archive"
curl -fsSLo SHA256SUMS "$base/SHA256SUMS"
sha256sum --check --ignore-missing SHA256SUMS
tar -xzf "$archive"
```

macOS 可将最后的校验命令替换为：

```sh
shasum -a 256 "$archive"
```

并与 `SHA256SUMS` 中对应行比较。

## 2. 调用 runtime

解压后直接使用包内的 `bin/zsh`，不要调用 `/bin/zsh`：

```sh
ZSH_RUNTIME="$PWD/bin/zsh"
"$ZSH_RUNTIME" -f -c 'print -r -- "$ZSH_VERSION"'
"$ZSH_RUNTIME" -f -c 'printf "%s\\n" hello'
```

建议始终使用 `-f`，避免宿主机上的 zsh 配置文件影响嵌入行为。项目可以把归档解压到自己的资源目录，并通过绝对路径启动；无需安装 zsh，也无需修改系统 shell。

包内还包含：

- `BUILD-METADATA.json`：版本、目标架构、源码校验值和构建 commit；
- `LICENSE.zsh`、`LICENSE.ncurses`：随 runtime 分发的许可证。

