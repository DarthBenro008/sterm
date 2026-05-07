#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIG="$ROOT/scripts/zig-ghostty.sh"

version="$("$ZIG" version)"
if [[ "$version" != "0.15.2" ]]; then
  echo "libghostty-vt: Ghostty requires Zig 0.15.2, got $version" >&2
  exit 1
fi

(
  cd "$ROOT/cli/sterm-cli"
  "$ZIG" build test -Dghostty-vt=true
  "$ZIG" build -Dghostty-vt=true
)

status="$(
  cd "$ROOT/cli/sterm-cli"
  "$ZIG" build -Dghostty-vt=true run -- status
)"
doctor="$(
  cd "$ROOT/cli/sterm-cli"
  "$ZIG" build -Dghostty-vt=true run -- doctor
)"

if ! grep -q 'vt: libghostty-vt-linked' <<<"$status"; then
  echo "libghostty-vt: status did not report linked VT" >&2
  echo "$status" >&2
  exit 1
fi

if ! grep -q '"vt":"libghostty-vt-linked"' <<<"$doctor"; then
  echo "libghostty-vt: doctor did not report linked VT" >&2
  echo "$doctor" >&2
  exit 1
fi

echo "$doctor"
echo "libghostty-vt: linked Zig dependency ok"
