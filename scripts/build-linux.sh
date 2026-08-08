#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/common.sh
. "$SCRIPT_DIR/common.sh"

TARGET="${TARGET:-}"
IN_CONTAINER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a value"
      TARGET="$2"
      shift 2
      ;;
    --in-container)
      IN_CONTAINER=1
      shift
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$TARGET" in
  linux-amd64-musl)
    DOCKER_PLATFORM="linux/amd64"
    EXPECTED_MACHINE="x86_64"
    ;;
  linux-arm64-musl)
    DOCKER_PLATFORM="linux/arm64"
    EXPECTED_MACHINE="aarch64"
    ;;
  *)
    die "target must be linux-amd64-musl or linux-arm64-musl"
    ;;
esac

if [[ "$IN_CONTAINER" != 1 ]]; then
  command -v docker >/dev/null 2>&1 || die "Docker is required for Linux builds"
  ALPINE_IMAGE="${ALPINE_IMAGE:-alpine:3.22}"
  COMMIT="$(build_commit)"
  exec docker run --rm --platform="$DOCKER_PLATFORM" \
    --mount "type=bind,src=$ROOT_DIR,dst=/src" \
    --workdir /src \
    --env "TARGET=$TARGET" \
    --env "BUILD_COMMIT=$COMMIT" \
    "$ALPINE_IMAGE" \
    sh -c 'apk add --no-cache bash binutils build-base curl file gawk tar xz && exec /src/scripts/build-linux.sh --in-container --target "$TARGET"'
fi

[[ "$(uname -s)" == Linux ]] || die "Linux builds must run on Linux"
case "$(uname -m)" in
  "$EXPECTED_MACHINE") ;;
  *) die "runner architecture $(uname -m) does not match $TARGET" ;;
esac

CC="${CC:-gcc}"
command -v "$CC" >/dev/null 2>&1 || die "compiler not found: $CC"
BUILD_ROOT="$ROOT_DIR/build/$TARGET"
DOWNLOADS="$BUILD_ROOT/downloads"
ZSH_SRC="$BUILD_ROOT/zsh-${ZSH_VERSION}"
NCURSES_SRC="$BUILD_ROOT/ncurses-${NCURSES_VERSION}"
DEPS_PREFIX="$BUILD_ROOT/deps"
STAGE="$BUILD_ROOT/stage"

rm -rf "$BUILD_ROOT"
mkdir -p "$DOWNLOADS" "$BUILD_ROOT"
download_verified "$ZSH_SOURCE_URL" "$ZSH_SOURCE_SHA256" "$DOWNLOADS/zsh.tar.xz"
download_verified "$NCURSES_SOURCE_URL" "$NCURSES_SOURCE_SHA256" "$DOWNLOADS/ncurses.tar.gz"
tar -xf "$DOWNLOADS/zsh.tar.xz" -C "$BUILD_ROOT"
tar -xf "$DOWNLOADS/ncurses.tar.gz" -C "$BUILD_ROOT"

JOBS="$(jobs_count)"
export CC

(
  cd "$NCURSES_SRC"
  ./configure \
    --prefix="$DEPS_PREFIX" \
    --with-normal \
    --without-debug \
    --without-shared \
    --enable-static \
    --enable-widec \
    --with-termlib=tinfo \
    --without-cxx \
    --without-cxx-binding \
    --without-ada \
    --without-manpages \
    --without-progs \
    --without-tests \
    --disable-db-install
  make -j"$JOBS"
  make install
)

export CPPFLAGS="-I$DEPS_PREFIX/include -I$DEPS_PREFIX/include/ncursesw"
export CFLAGS="-O2"
export LDFLAGS="-static -L$DEPS_PREFIX/lib"

(
  cd "$ZSH_SRC"
  ./configure \
    --prefix="$DEPS_PREFIX/zsh" \
    --disable-dynamic \
    --disable-dynamic-nss \
    --with-term-lib="tinfow ncursesw tinfo ncurses"
  make -j"$JOBS"
)

[[ -x "$ZSH_SRC/Src/zsh" ]] || die "zsh executable was not produced"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin"
install -m 0755 "$ZSH_SRC/Src/zsh" "$STAGE/bin/zsh"
install -m 0644 "$ZSH_SRC/LICENCE" "$STAGE/LICENSE.zsh"
install -m 0644 "$NCURSES_SRC/COPYING" "$STAGE/LICENSE.ncurses"
write_metadata "$STAGE/BUILD-METADATA.json" "$TARGET" "$CC"

printf 'built %s at %s\n' "$TARGET" "$STAGE/bin/zsh"
