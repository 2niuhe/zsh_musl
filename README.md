# zsh_musl

This repository builds zsh 5.9.2 as an embeddable runtime:

- `linux-amd64-musl` and `linux-arm64-musl`: statically linked with musl;
- `darwin-amd64` and `darwin-arm64`: native Mach-O builds using Apple Clang.

The zsh and ncurses source archives are downloaded from fixed URLs and checked
against fixed SHA-256 values. Linux builds compile ncurses and zsh with the
same musl toolchain, and zsh dynamic modules are disabled.

## Local builds

Linux builds use Docker and the matching Alpine architecture:

```sh
make build TARGET=linux-amd64-musl
make verify TARGET=linux-amd64-musl
make package TARGET=linux-amd64-musl
```

The macOS commands must run on the matching native host architecture:

```sh
make build TARGET=darwin-arm64
make verify TARGET=darwin-arm64
make package TARGET=darwin-arm64
```

Packages are written to `dist/`. The package contains `bin/zsh`, both license
files, and `BUILD-METADATA.json`; `SHA256SUMS` is regenerated on every package
operation.

## Releases

Pushing a `v*` tag starts `.github/workflows/release.yml`. It builds all four
targets on their required runners, verifies them, creates the four archives and
`SHA256SUMS`, then uploads them to the GitHub Release. The same workflow can be
started manually with a release tag input.

