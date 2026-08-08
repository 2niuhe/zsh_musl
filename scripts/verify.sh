#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=scripts/common.sh
. "$SCRIPT_DIR/common.sh"

TARGET="${TARGET:-}"
ARCHIVE=""
SKIP_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a value"
      TARGET="$2"
      shift 2
      ;;
    --archive)
      [[ $# -ge 2 ]] || die "--archive requires a path"
      ARCHIVE="$2"
      shift 2
      ;;
    --skip-run)
      SKIP_RUN=1
      shift
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

WORK_DIR=""
if [[ -n "$ARCHIVE" ]]; then
  [[ -f "$ARCHIVE" ]] || die "archive does not exist: $ARCHIVE"
  WORK_DIR="$(mktemp -d)"
  trap 'rm -rf "$WORK_DIR"' EXIT
  tar -xzf "$ARCHIVE" -C "$WORK_DIR"
  BINARY="$WORK_DIR/bin/zsh"
  META="$WORK_DIR/BUILD-METADATA.json"
  LICENSE_ZSH="$WORK_DIR/LICENSE.zsh"
  LICENSE_NCURSES="$WORK_DIR/LICENSE.ncurses"
  for required in "$BINARY" "$META" "$LICENSE_ZSH" "$LICENSE_NCURSES"; do
    [[ -s "$required" ]] || die "archive is missing $(basename -- "$required")"
  done
else
  STAGE="$ROOT_DIR/build/$TARGET/stage"
  BINARY="$STAGE/bin/zsh"
  META="$STAGE/BUILD-METADATA.json"
  LICENSE_ZSH="$STAGE/LICENSE.zsh"
  LICENSE_NCURSES="$STAGE/LICENSE.ncurses"
fi

[[ -x "$BINARY" ]] || die "zsh executable is missing: $BINARY"
[[ -s "$META" ]] || die "metadata is missing: $META"
[[ -s "$LICENSE_ZSH" ]] || die "LICENSE.zsh is missing"
[[ -s "$LICENSE_NCURSES" ]] || die "LICENSE.ncurses is missing"
grep -Fq '"zsh_version": "5.9.2"' "$META" || die "metadata has the wrong zsh version"
grep -Fq "\"target\": \"$TARGET\"" "$META" || die "metadata has the wrong target"
grep -Eq '"source_sha256": "[0-9a-f]{64}"' "$META" || die "metadata has no source SHA-256"
grep -Eq '"build_commit": "(unknown|[0-9A-Fa-f]{7,64})"' "$META" || die "metadata has no build commit"

if [[ "$TARGET" == linux-* ]]; then
  FILE_OUTPUT="$(file "$BINARY")"
  case "$TARGET" in
    linux-amd64-musl) echo "$FILE_OUTPUT" | grep -Eiq 'ELF.*(x86-64|x86_64)' || die "wrong Linux amd64 architecture" ;;
    linux-arm64-musl) echo "$FILE_OUTPUT" | grep -Eiq 'ELF.*(aarch64|ARM aarch64)' || die "wrong Linux arm64 architecture" ;;
  esac
  echo "$FILE_OUTPUT" | grep -Eiq 'statically linked|static-pie linked' || die "Linux binary is not static"
  LDD_OUTPUT="$(ldd "$BINARY" 2>&1 || true)"
  echo "$LDD_OUTPUT" | grep -Eiq 'not a dynamic executable|statically linked' || die "ldd reports dynamic dependencies: $LDD_OUTPUT"
  DYNAMIC_OUTPUT="$(readelf -d "$BINARY" 2>&1 || true)"
  echo "$DYNAMIC_OUTPUT" | grep -Eiq 'no dynamic section' || die "ELF has a dynamic section"
  readelf -l "$BINARY" 2>/dev/null | grep -q 'INTERP' && die "ELF has an interpreter"
else
  FILE_OUTPUT="$(file "$BINARY")"
  case "$TARGET" in
    darwin-amd64) echo "$FILE_OUTPUT" | grep -Eiq 'Mach-O.*(x86_64|64-bit)' || die "wrong macOS amd64 architecture" ;;
    darwin-arm64) echo "$FILE_OUTPUT" | grep -Eiq 'Mach-O.*(arm64|arm64e)' || die "wrong macOS arm64 architecture" ;;
  esac
  command -v otool >/dev/null 2>&1 || die "otool is required for macOS verification"
  if otool -L "$BINARY" | tail -n +2 | grep -Ev '^[[:space:]]+(/usr/lib/|/System/Library/)' | grep -q .; then
    die "macOS binary has a non-system library dependency"
  fi
fi

if [[ "$SKIP_RUN" != 1 ]]; then
  VERSION_OUTPUT="$("$BINARY" -f -c 'print -r -- "$ZSH_VERSION"')"
  [[ "$VERSION_OUTPUT" == "$ZSH_VERSION" ]] || die "unexpected zsh version: $VERSION_OUTPUT"
  [[ "$("$BINARY" -f -c 'printf "%s\\n" ok')" == ok ]] || die "basic output test failed"
  [[ -z "$("$BINARY" -f -c 'x=1; test "$x" = 1')" ]] || die "test builtin behavior failed"
  [[ "$("$BINARY" -f -c 'printf "%s\\n" one two | wc -l | tr -d "[:space:]"')" == 2 ]] || die "pipeline behavior failed"
  [[ "$("$BINARY" -f -c 'printf "%s" ok > /tmp/zsh-musl-verify.$$; cat /tmp/zsh-musl-verify.$$; rm -f /tmp/zsh-musl-verify.$$')" == ok ]] || die "redirection behavior failed"
  set +e
  "$BINARY" -f -c 'exit 7'
  EXIT_CODE=$?
  set -e
  [[ "$EXIT_CODE" == 7 ]] || die "exit status behavior failed: $EXIT_CODE"
  set +e
  "$BINARY" -f -c 'kill -TERM $$'
  SIGNAL_CODE=$?
  set -e
  [[ "$SIGNAL_CODE" == 143 || "$SIGNAL_CODE" == 15 ]] || die "signal behavior failed: $SIGNAL_CODE"
fi

if [[ -n "$ARCHIVE" ]]; then
  ARCHIVE_LIST="$(tar -tzf "$ARCHIVE")"
  for member in bin/zsh LICENSE.zsh LICENSE.ncurses BUILD-METADATA.json; do
    echo "$ARCHIVE_LIST" | grep -Fxq "$member" || die "archive is missing $member"
  done
fi

printf 'verified %s\n' "$TARGET"
