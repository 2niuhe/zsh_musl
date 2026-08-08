#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/common.sh
. "$SCRIPT_DIR/common.sh"

TARGET="${TARGET:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a value"
      TARGET="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$TARGET" in
  darwin-amd64)
    EXPECTED_ARCH="x86_64"
    ;;
  darwin-arm64)
    EXPECTED_ARCH="arm64"
    ;;
  *)
    die "target must be darwin-amd64 or darwin-arm64"
    ;;
esac

[[ "$(uname -s)" == Darwin ]] || die "macOS builds must run on macOS"
[[ "$(uname -m)" == "$EXPECTED_ARCH" ]] || die "runner architecture $(uname -m) does not match $TARGET"
command -v xcrun >/dev/null 2>&1 || die "Xcode command line tools are required"

BUILD_ROOT="$ROOT_DIR/build/$TARGET"
DOWNLOADS="$BUILD_ROOT/downloads"
ZSH_SRC="$BUILD_ROOT/zsh-${ZSH_VERSION}"
NCURSES_SRC="$BUILD_ROOT/ncurses-${NCURSES_VERSION}"
STAGE="$BUILD_ROOT/stage"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
CC="$(xcrun --sdk macosx -f clang)"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"

rm -rf "$BUILD_ROOT"
mkdir -p "$DOWNLOADS" "$BUILD_ROOT"
download_verified "$ZSH_SOURCE_URL" "$ZSH_SOURCE_SHA256" "$DOWNLOADS/zsh.tar.xz"
download_verified "$NCURSES_SOURCE_URL" "$NCURSES_SOURCE_SHA256" "$DOWNLOADS/ncurses.tar.gz"
tar -xf "$DOWNLOADS/zsh.tar.xz" -C "$BUILD_ROOT"
tar -xf "$DOWNLOADS/ncurses.tar.gz" -C "$BUILD_ROOT"

export CC
export CPPFLAGS="-isysroot $SDKROOT -I$SDKROOT/usr/include"
export CPP="$CC -E $CPPFLAGS"
export CFLAGS="-O2 -arch $EXPECTED_ARCH -isysroot $SDKROOT -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
export LDFLAGS="-arch $EXPECTED_ARCH -isysroot $SDKROOT -L$SDKROOT/usr/lib -isysroot $SDKROOT -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"

(
  cd "$ZSH_SRC"
  ./configure \
    --prefix="$BUILD_ROOT/install" \
    --disable-dynamic \
    --disable-dynamic-nss \
    --with-term-lib="ncursesw tinfo termcap ncurses curses"
  make -j"$(jobs_count)"
)

[[ -x "$ZSH_SRC/Src/zsh" ]] || die "zsh executable was not produced"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin"
install -m 0755 "$ZSH_SRC/Src/zsh" "$STAGE/bin/zsh"
install -m 0644 "$ZSH_SRC/LICENCE" "$STAGE/LICENSE.zsh"
install -m 0644 "$NCURSES_SRC/COPYING" "$STAGE/LICENSE.ncurses"
write_metadata "$STAGE/BUILD-METADATA.json" "$TARGET" "$CC"

printf 'built %s at %s\n' "$TARGET" "$STAGE/bin/zsh"
