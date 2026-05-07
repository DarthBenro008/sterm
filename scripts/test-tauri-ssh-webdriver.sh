#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

missing=0
for bin in bun cargo ssh sshpass scp tauri-driver WebKitWebDriver; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "missing required command: $bin" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  exit 1
fi

export STERM_E2E_SSH_HOST="${STERM_E2E_SSH_HOST:-0.0.0.0}"
export STERM_E2E_SSH_USERNAME="${STERM_E2E_SSH_USERNAME:-root}"
export STERM_E2E_SSH_PASSWORD="${STERM_E2E_SSH_PASSWORD:-krishna5243}"

rm -f /root/iwashere.txt

if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a bun --cwd apps/desktop/web e2e:ssh
else
  bun --cwd apps/desktop/web e2e:ssh
fi

ls -l /root/iwashere.txt
