#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash scripts/check-production-readiness.sh
bash scripts/check-artifact-policy.sh

audit="docs/final-production-readiness-audit.md"
if [[ ! -f "$audit" ]]; then
  echo "final readiness: missing $audit" >&2
  exit 1
fi

required_patterns=(
  "Success criteria coverage"
  "Verification evidence"
  "Environment-impossible blockers"
  "Architect approval"
  "bash scripts/verify.sh"
  "PASS"
  "G009-final-production-readiness-audit"
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -q "$pattern" "$audit"; then
    echo "final readiness: missing '$pattern' in $audit" >&2
    exit 1
  fi
done

stale_patterns=(
  'active in `\$ultragoal`'
  'Active implementation lane'
  'In progress under risk-first lane'
  'Final readiness audit | Not complete'
  'Needs to run after implementation lanes complete'
  'The next implementation order is'
)

for pattern in "${stale_patterns[@]}"; do
  if grep -RIn "$pattern" docs >/tmp/sterm-final-stale-grep.txt; then
    cat /tmp/sterm-final-stale-grep.txt >&2
    exit 1
  fi
done

if grep -RIn 'Real SSH/PTY/libghostty E2E.*completed' docs >/tmp/sterm-final-stale-grep.txt; then
  cat /tmp/sterm-final-stale-grep.txt >&2
  exit 1
fi

echo "final readiness: audit evidence present"
