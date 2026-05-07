#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v zig >/dev/null 2>&1 && [[ -x /root/zig/zig ]]; then
  export PATH="/root/zig:$PATH"
fi

if ! command -v zig >/dev/null 2>&1 && [[ -f "$HOME/.zshrc" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.zshrc" >/dev/null 2>&1 || true
fi

output="$(mktemp)"
trap 'rm -f "$output"' EXIT

(
  cd cli/sterm-cli
  zig build run -- doctor
) >"$output"

required_patterns=(
  '"socket_mode":"0600"'
  '"parent_dir_mode":"0700"'
  '"sqlite":"sqlite3-unlinked"'
  '"vt":"libghostty-vt-unavailable"'
  '"multi_client"'
  '"roaming_transport"'
  '"agent_detection"'
  '"recent_errors"'
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -q "$pattern" "$output"; then
    echo "doctor output: missing $pattern" >&2
    cat "$output" >&2
    exit 1
  fi
done

if grep -Eiq 'token=|password=|passphrase=|private_key=|secret=' "$output"; then
  echo "doctor output: leaked secret-looking value" >&2
  cat "$output" >&2
  exit 1
fi

cat "$output"
echo "doctor output: contract ok"
