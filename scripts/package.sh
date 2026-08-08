#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/common.sh
. "$SCRIPT_DIR/common.sh"

TARGET="${TARGET:-}"
DIST_DIR="$ROOT_DIR/dist"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a value"
      TARGET="$2"
      shift 2
      ;;
    --dist-dir)
      [[ $# -ge 2 ]] || die "--dist-dir requires a value"
      DIST_DIR="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$TARGET" in
  linux-amd64-musl|linux-arm64-musl|darwin-amd64|darwin-arm64) ;;
  *) die "target must be a supported target" ;;
esac

STAGE="$ROOT_DIR/build/$TARGET/stage"
ARCHIVE="$DIST_DIR/zsh-${ZSH_VERSION}-${TARGET}.tar.gz"
[[ -x "$STAGE/bin/zsh" ]] || die "missing staged zsh; build $TARGET first"
[[ -s "$STAGE/LICENSE.zsh" ]] || die "missing LICENSE.zsh"
[[ -s "$STAGE/LICENSE.ncurses" ]] || die "missing LICENSE.ncurses"
[[ -s "$STAGE/BUILD-METADATA.json" ]] || die "missing BUILD-METADATA.json"

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE"
if tar --version 2>/dev/null | grep -q 'GNU tar'; then
  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
    -czf "$ARCHIVE" -C "$STAGE" bin/zsh LICENSE.zsh LICENSE.ncurses BUILD-METADATA.json
else
  COPYFILE_DISABLE=1 tar -czf "$ARCHIVE" -C "$STAGE" \
    bin/zsh LICENSE.zsh LICENSE.ncurses BUILD-METADATA.json
fi

SUMS="$DIST_DIR/SHA256SUMS"
: > "$SUMS"
for archive in "$DIST_DIR"/zsh-*.tar.gz; do
  [[ -f "$archive" ]] || continue
  printf '%s  %s\n' "$(sha256_file "$archive")" "$(basename -- "$archive")" >> "$SUMS"
done
sort -o "$SUMS" "$SUMS"

printf 'packaged %s\n' "$ARCHIVE"

