#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export STERM_REQUIRE_SIGNING="${STERM_REQUIRE_SIGNING:-1}"
bash scripts/check-artifact-policy.sh
bash scripts/check-doctor-output.sh
bash scripts/build-agent.sh
bash scripts/check-release-artifacts.sh
bash scripts/package-desktop.sh
