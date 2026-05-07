#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing required production-readiness file: $path" >&2
    exit 1
  fi
}

require_grep() {
  local pattern="$1"
  local path="$2"
  if ! grep -qE "$pattern" "$path"; then
    echo "missing required pattern '$pattern' in $path" >&2
    exit 1
  fi
}

require_file docs/production-readiness.md
require_file docs/production-goals.json
require_file scripts/check-artifact-policy.sh
require_file scripts/check-doctor-output.sh
require_file scripts/check-final-readiness.sh
require_file scripts/check-release-artifacts.sh
require_file .github/workflows/ci.yml
require_file .github/workflows/release.yml

require_grep '"G001-production-readiness-contract"' docs/production-goals.json
require_grep '"G002-tauri-desktop-runtime"' docs/production-goals.json
require_grep '"G003-agent-daemon-storage-process-vt"' docs/production-goals.json
require_grep '"G004-final-protocol-transport"' docs/production-goals.json
require_grep '"G005-full-production-hardening"' docs/production-goals.json
require_grep '"G006-mature-ui-polish"' docs/production-goals.json
require_grep '"G007-multi-client-mosh-agent-detection"' docs/production-goals.json
require_grep '"G008-ci-release-observability-doctor"' docs/production-goals.json
require_grep '"G009-final-production-readiness-audit"' docs/production-goals.json

require_grep 'Risk-first production gates' docs/production-readiness.md
require_grep 'Completion rule' docs/production-readiness.md
require_grep 'scripts/verify.sh' .github/workflows/ci.yml
require_grep 'check-release-artifacts.sh' .github/workflows/release.yml

if grep -qE '"status": "(pending|in_progress|failed)"' docs/production-goals.json; then
  echo "production readiness contract: production-goals.json contains unfinished goals" >&2
  exit 1
fi

if grep -RIn 'p[n]pm\|P[N]PM' . \
  --exclude-dir=.git \
  --exclude-dir=.omx \
  --exclude-dir=.cache \
  --exclude-dir=node_modules \
  --exclude-dir=dist \
  --exclude-dir=target \
  --exclude-dir=zig-out \
  --exclude-dir=zig-cache \
  --exclude-dir=.zig-cache \
  --exclude='bun.lockb' \
  --exclude='bun.lock' >/tmp/sterm-production-pm-grep.txt; then
  cat /tmp/sterm-production-pm-grep.txt >&2
  exit 1
fi

echo "production readiness contract: ok"
