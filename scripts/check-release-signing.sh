#!/usr/bin/env bash
set -euo pipefail

if [[ "${STERM_REQUIRE_SIGNING:-0}" != "1" ]]; then
  echo "release signing: optional for local build (set STERM_REQUIRE_SIGNING=1 in release jobs)"
  exit 0
fi

missing=0
for name in APPLE_SIGNING_IDENTITY APPLE_ID APPLE_PASSWORD APPLE_TEAM_ID; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing required signing environment variable: $name" >&2
    missing=1
  fi
done

if [[ "$missing" != "0" ]]; then
  echo "release signing: blocked until signing credentials are configured" >&2
  exit 1
fi

echo "release signing: required macOS signing environment is present"
