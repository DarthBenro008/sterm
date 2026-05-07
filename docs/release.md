# Release and signing readiness

`sterm` now has a real Tauri v2 application boundary and signing-ready package
scripts. Local unsigned builds are allowed for development, but release jobs must
fail honestly when signing prerequisites are absent.

## Commands

```bash
bun run desktop:dev
bun run desktop:build
bun run desktop:signing-check
bun run agent:build
bun run release:check
```

`bun run desktop:build` runs the frontend build and Tauri build through
`scripts/package-desktop.sh`. On Linux the local default is `deb` so the command
has a deterministic package target for verification; set
`STERM_DESKTOP_BUNDLES=deb,rpm,appimage` to request the full Linux bundle set.

Platform-specific Tauri bundle targets live beside the base config:

- `apps/desktop/src-tauri/tauri.linux.conf.json` — `deb`, `rpm`, `appimage`
- `apps/desktop/src-tauri/tauri.macos.conf.json` — `app`, `dmg`
- `apps/desktop/src-tauri/tauri.windows.conf.json` — `nsis`, `msi`

## Signing gates

Set `STERM_REQUIRE_SIGNING=1` in production release jobs. When enabled, the
signing check requires:

- `APPLE_SIGNING_IDENTITY`
- `APPLE_ID`
- `APPLE_PASSWORD`
- `APPLE_TEAM_ID`

The current release preflight prevents a signed-release claim without the macOS
signing prerequisites. Additional platform-specific signing keys can be added to
the same hard-fail pattern as the release matrix expands.

## Agent artifacts and checksums

`scripts/build-agent.sh` builds `sterm-cli`, copies executable artifacts into
`dist/agent/`, and writes `checksums.sha256` plus a small manifest. Set
`STERM_AGENT_TARGETS` to a space-separated target list for release builds, for
example:

```bash
STERM_AGENT_TARGETS="x86_64-linux-gnu aarch64-linux-gnu" bash scripts/build-agent.sh
```

`scripts/check-release-artifacts.sh` verifies the checksum file and executable
bits. `scripts/check-artifact-policy.sh` asserts generated outputs remain
ignored and untracked.

## CI/release gates

- `.github/workflows/ci.yml` installs Bun, Rust/rustfmt, Zig, Linux Tauri
  prerequisites, prints tool versions, and runs `bash scripts/verify.sh`.
- `.github/workflows/release.yml` runs artifact policy, doctor output, agent
  build/checksum verification, signing preflight, desktop packaging, and uploads
  generated artifacts. Missing signing credentials fail the workflow before a
  signed-release claim can be made.
