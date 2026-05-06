#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash scripts/check-release-signing.sh
bun --cwd apps/desktop/web build

case "$(uname -s)" in
  Linux*) default_bundles="deb" ;;
  *) default_bundles="" ;;
esac

bundles="${STERM_DESKTOP_BUNDLES:-$default_bundles}"
args=(--ci)
if [[ -n "$bundles" ]]; then
  args+=(--bundles "$bundles")
fi

(
  cd apps/desktop/src-tauri
  bunx tauri build "${args[@]}"
)
