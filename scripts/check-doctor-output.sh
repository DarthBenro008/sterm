#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

output="$(mktemp)"
trap 'rm -f "$output"' EXIT

(
  cd cli/sterm-cli
  "$ROOT/scripts/zig-ghostty.sh" build -Dghostty-vt=true run -- doctor
) >"$output"

required_patterns=(
  '"socket_mode":"0600"'
  '"parent_dir_mode":"0700"'
  '"sqlite":"sqlite3-unlinked"'
  '"vt":"libghostty-vt-linked"'
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
