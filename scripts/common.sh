#!/usr/bin/env bash

ZSH_VERSION="5.9.2"
ZSH_SOURCE_URL="https://www.zsh.org/pub/zsh-${ZSH_VERSION}.tar.xz"
ZSH_SOURCE_SHA256="36fa734374b44783582cec09bcd67822e2f992c779ec1624ab5596df078d2f81"

NCURSES_VERSION="6.5"
NCURSES_SOURCE_URL="https://invisible-island.net/archives/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"
NCURSES_SOURCE_SHA256="136d91bc269a9a5785e5f9e980bc76ab57428f604ce3e5a5a90cebc767971cc6"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "sha256sum or shasum is required"
  fi
}

download_verified() {
  local url="$1"
  local expected="$2"
  local destination="$3"
  local actual

  mkdir -p "$(dirname -- "$destination")"
  curl --fail --location --retry 3 --retry-delay 1 --proto '=https' --tlsv1.2 \
    "$url" -o "$destination"
  actual="$(sha256_file "$destination")"
  [[ "$actual" == "$expected" ]] || die "SHA-256 mismatch for $(basename -- "$destination")"
}

build_commit() {
  local value="${BUILD_COMMIT:-}"
  if [[ -z "$value" ]] && command -v git >/dev/null 2>&1; then
    value="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)"
  fi
  if [[ "$value" =~ ^[0-9a-fA-F]{7,64}$ ]]; then
    printf '%s' "$value"
  else
    printf '%s' 'unknown'
  fi
}

compiler_metadata() {
  local cc="$1"
  local first_line
  first_line="$($cc --version 2>/dev/null | sed -n '1p' | tr -cd '[:alnum:] ._-')" || true
  if [[ -n "$first_line" ]]; then
    printf '%s' "$first_line"
  else
    printf '%s' "$cc"
  fi
}

write_metadata() {
  local destination="$1"
  local target="$2"
  local cc="$3"
  local compiler
  local commit

  compiler="$(compiler_metadata "$cc")"
  commit="$(build_commit)"
  mkdir -p "$(dirname -- "$destination")"
  printf '{\n  "zsh_version": "%s",\n  "target": "%s",\n  "source_sha256": "%s",\n  "ncurses_version": "%s",\n  "ncurses_source_sha256": "%s",\n  "compiler": "%s",\n  "build_commit": "%s"\n}\n' \
    "$ZSH_VERSION" "$target" "$ZSH_SOURCE_SHA256" "$NCURSES_VERSION" \
    "$NCURSES_SOURCE_SHA256" "$compiler" "$commit" > "$destination"
}

jobs_count() {
  local jobs
  jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
  if [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    printf '%s' "$jobs"
  else
    printf '%s' '2'
  fi
}

