#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${STERM_GHOSTTY_ZIG_VERSION:-0.15.2}"

if [[ -n "${STERM_GHOSTTY_ZIG:-}" ]]; then
  exec "$STERM_GHOSTTY_ZIG" "$@"
fi

case "$(uname -s)" in
  Linux) os="linux" ;;
  Darwin) os="macos" ;;
  *)
    echo "zig-ghostty: unsupported OS $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="x86_64" ;;
  aarch64|arm64) arch="aarch64" ;;
  *)
    echo "zig-ghostty: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac

name="zig-${arch}-${os}-${VERSION}"
cache_dir="$ROOT/.cache/zig"
zig="$cache_dir/$name/zig"
archive="$cache_dir/zig-${VERSION}-${arch}-${os}.tar.xz"
url="https://ziglang.org/download/${VERSION}/${name}.tar.xz"

if [[ ! -x "$zig" ]]; then
  mkdir -p "$cache_dir"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -c -x 8 -s 8 -k 1M --file-allocation=none \
      --allow-overwrite=true -d "$cache_dir" -o "$(basename "$archive")" "$url"
  else
    curl -L --fail --show-error --continue-at - "$url" -o "$archive"
  fi
  rm -rf "$cache_dir/$name"
  tar -C "$cache_dir" -xf "$archive"
fi

exec "$zig" "$@"
