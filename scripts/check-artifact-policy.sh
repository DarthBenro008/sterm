#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ignored_paths=(
  "node_modules/"
  ".cache/"
  "dist/"
  "target/"
  "zig-out/"
  "zig-cache/"
  ".zig-cache/"
)

for path in "${ignored_paths[@]}"; do
  if ! git check-ignore -q "$path"; then
    echo "artifact policy: $path is not ignored" >&2
    exit 1
  fi
done

if tracked_generated="$(git ls-files '.cache/*' '*/.cache/*' 'dist/*' '*/dist/*' 'target/*' '*/target/*' 'zig-out/*' '*/zig-out/*' 'zig-cache/*' '*/zig-cache/*' '.zig-cache/*' '*/.zig-cache/*')" && [[ -n "$tracked_generated" ]]; then
  echo "artifact policy: generated artifacts are tracked:" >&2
  echo "$tracked_generated" >&2
  exit 1
fi

echo "artifact policy: ignored generated outputs are not tracked"
