#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_DIR="$ROOT/cli/sterm-cli"
OUT_DIR="${STERM_AGENT_DIST:-$ROOT/dist/agent}"

if ! command -v zig >/dev/null 2>&1 && [[ -x /root/zig/zig ]]; then
  export PATH="/root/zig:$PATH"
fi

if ! command -v zig >/dev/null 2>&1 && [[ -f "$HOME/.zshrc" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.zshrc" >/dev/null 2>&1 || true
fi

if ! command -v zig >/dev/null 2>&1; then
  echo "agent build: zig is required" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
: >"$OUT_DIR/checksums.sha256"

native_label() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
  esac
  printf '%s-%s' "$os" "$arch"
}

targets="${STERM_AGENT_TARGETS:-native}"
for target in $targets; do
  args=()
  label="$target"
  if [[ "$target" == "native" ]]; then
    label="$(native_label)"
  else
    args+=("-Dtarget=$target")
  fi

  (
    cd "$AGENT_DIR"
    zig build "${args[@]}" "$@"
  )

  binary="$AGENT_DIR/zig-out/bin/sterm-cli"
  if [[ ! -x "$binary" ]]; then
    echo "agent build: expected executable missing at $binary" >&2
    exit 1
  fi

  artifact="sterm-cli-$label"
  cp "$binary" "$OUT_DIR/$artifact"
  chmod 755 "$OUT_DIR/$artifact"
  (
    cd "$OUT_DIR"
    sha256sum "$artifact" >>checksums.sha256
  )
done

cat >"$OUT_DIR/manifest.json" <<EOF
{
  "artifact": "sterm-cli",
  "targets": "$targets",
  "checksum_file": "checksums.sha256"
}
EOF

echo "agent build: wrote artifacts to $OUT_DIR"
