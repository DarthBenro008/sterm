# Release and signing readiness

`sterm` now has a real Tauri v2 application boundary and signing-ready package
scripts. Local unsigned builds are allowed for development, but release jobs must
fail honestly when signing prerequisites are absent.

## Commands

```bash
bun run desktop:dev
bun run desktop:build
bun run desktop:signing-check
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

Windows/Linux signing and notarization keys are covered by later CI/release
hardening, but this first Tauri lane already prevents a signed-release claim
without the macOS signing prerequisites.
