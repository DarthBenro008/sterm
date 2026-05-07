#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

artifact_dir="${STERM_AGENT_DIST:-$ROOT/dist/agent}"
checksum_file="$artifact_dir/checksums.sha256"

if [[ ! -s "$checksum_file" ]]; then
  echo "release artifacts: missing $checksum_file; run scripts/build-agent.sh first" >&2
  exit 1
fi

(
  cd "$artifact_dir"
  sha256sum -c "$(basename "$checksum_file")"
)

while read -r checksum artifact; do
  if [[ -z "$checksum" || -z "$artifact" ]]; then
    continue
  fi
  if [[ ! -x "$artifact_dir/$artifact" ]]; then
    echo "release artifacts: $artifact is not executable" >&2
    exit 1
  fi
done <"$checksum_file"

echo "release artifacts: checksums and executable bits ok"
