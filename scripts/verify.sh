#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

status=0

run_required() {
  local name="$1"
  shift
  echo "==> $name"
  if "$@"; then
    echo "PASS: $name"
  else
    local code=$?
    echo "FAIL: $name (exit $code)"
    status=1
  fi
}

if [[ -d "$HOME/.cargo/bin" ]]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

run_required "no legacy package-manager references outside .omx/.git" bash -lc "! grep -RIn 'p[n]pm\\|P[N]PM' . --exclude-dir=.git --exclude-dir=.omx --exclude-dir=.cache --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=target --exclude-dir=zig-out --exclude-dir=zig-cache --exclude-dir=.zig-cache --exclude='bun.lockb' --exclude='bun.lock' >/tmp/sterm-package-manager-grep.txt || (cat /tmp/sterm-package-manager-grep.txt; false)"
run_required "production readiness contract" bash scripts/check-production-readiness.sh
run_required "final readiness audit" bash scripts/check-final-readiness.sh
run_required "desktop signing optional gate" bash scripts/check-release-signing.sh
run_required "artifact ignore policy" bash scripts/check-artifact-policy.sh
run_required "tauri desktop icon set" bash scripts/check-tauri-icons.sh
run_required "doctor output contract" bash scripts/check-doctor-output.sh
run_required "agent release artifact build/checksum" bash -lc "bash scripts/build-agent.sh && bash scripts/check-release-artifacts.sh"
run_required "bun install" bun install
run_required "bun workspace tests" bun run test
run_required "bun workspace typecheck" bun run typecheck
run_required "bun workspace build" bun run build
run_required "cargo fmt check" cargo fmt --all -- --check
run_required "tauri config check" bash -lc "cd apps/desktop/src-tauri && bunx tauri info >/tmp/sterm-tauri-info.txt && grep -q 'frontendDist: ../web/dist' /tmp/sterm-tauri-info.txt && grep -q 'devUrl: http://127.0.0.1:5173/' /tmp/sterm-tauri-info.txt"
run_required "cargo test workspace" cargo test --workspace
run_required "zig fmt check" bash -lc "find cli/sterm-cli -name '*.zig' -not -path '*/.zig-cache/*' -not -path '*/zig-out/*' -print0 | xargs -0 scripts/zig-ghostty.sh fmt --check"
run_required "libghostty-vt linked build" bash scripts/check-libghostty-vt.sh
run_required "zig build test" bash -lc "cd cli/sterm-cli && ../../scripts/zig-ghostty.sh build test -Dghostty-vt=true"

echo "==> git status"
git status --short

exit "$status"
