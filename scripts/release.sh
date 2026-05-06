#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export STERM_REQUIRE_SIGNING="${STERM_REQUIRE_SIGNING:-1}"
bash scripts/package-desktop.sh
