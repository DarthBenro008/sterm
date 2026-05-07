# Production readiness contract

This document is the gating contract for the completed `$ultragoal` production
readiness run. It exists to prevent the earlier first-wave scaffold from being
mistaken for live-environment production proof while recording the executable
code, tests, docs, release gates, and explicit external blockers that now make
up the repository production-readiness contract.

## Standing constraints

- JavaScript and TypeScript package management, scripts, tests, and builds use
  Bun.
- Legacy non-Bun package manager references must not appear in source/docs/scripts
  outside ignored OMX or VCS state.
- File edits in this run are made with the built-in patch tool, not Python.
- The remote daemon remains the owner of terminal truth: PTY/process state,
  VT/snapshot/diff state, scrollback, workspace/tab/split layout, and lifecycle.

## Risk-first production gates

| Gate | Current state | Required production outcome | Ultragoal lane |
| --- | --- | --- | --- |
| Real Tauri runtime and signing | G002 complete: desktop app builds through a real Tauri v2 boundary; release signing preflight fails honestly when signing credentials are absent. | Desktop app can run/build through a real Tauri boundary; release signing is configured or fails with explicit missing-certificate evidence. | `G002-tauri-desktop-runtime` |
| SSH/PTY/libghostty daemon gates | G003 complete for daemon/runtime/storage/process/PTY/VT adapter contracts; live VM PTY and linked `libghostty-vt` remain explicit environment blockers. | Daemon has durable state, safe process/PTY ownership, and a real integration boundary for PTY/libghostty or an honest compile-time unavailable gate. | `G003-agent-daemon-storage-process-vt` |
| Final protocol transport | G004 complete: production `STRM` transport framing/version negotiation exists across Rust, TypeScript, and Zig; fixtures remain golden semantic inputs. | Production transport framing/version negotiation exists, with Rust/TS/Zig compatibility and failure tests. | `G004-final-protocol-transport` |
| Full production hardening | G005 complete: SSH/tunnel/bootstrap/keychain/security defaults have failure-mode tests and docs. | SSH/tunnel/bootstrap/keychain/process reliability defaults are hardened with failure-mode tests. | `G005-full-production-hardening` |
| Mature UI polish | G006 adds an accessible fixture-backed desktop shell with explicit loading/error states, keyboard focus, command palette/shortcut surfaces, honest disabled live mutations, and dirty-region invariant tests. | Desktop UI has accessible navigation, resilient errors/loading, polished surfaces, and targeted tests without claiming live SSH bridge ownership. | `G006-mature-ui-polish` |
| Multi-client, Mosh/UDP, agent detection | G007 adds protocol fixtures/types, Zig session attach decisions, encrypted roaming-UDP offer validation with SSH fallback, and builtin agent detection with confidence/evidence. | Protocol/session/transport/detection primitives are implemented or blocked with environment-specific evidence rather than roadmap deferral. | `G007-multi-client-mosh-agent-detection` |
| CI/release/observability/doctor | G008 adds executable artifact policy, doctor-output, agent artifact/checksum, CI toolchain/dependency, and release preflight gates. | CI/release/doctor/logging gates execute real checks and fail honestly for missing production prerequisites. | `G008-ci-release-observability-doctor` |
| Final readiness audit | G009 complete: `docs/final-production-readiness-audit.md` maps success criteria to code/tests/docs and external blockers. | Evidence bundle maps every gate to code, docs, tests, and remaining impossible prerequisites. | `G009-final-production-readiness-audit` |

## Current classification after final audit

| Area | Classification | Evidence |
| --- | --- | --- |
| Bun workspace and legacy-package-manager guard | Implemented baseline | `package.json`, `bun.lock`, `scripts/verify.sh` |
| Rust protocol fixtures | Implemented baseline | `crates/sterm-protocol`, `fixtures/protocol` |
| TypeScript protocol/renderer/frontend tests | Implemented baseline | `packages/*`, `apps/desktop/web/tests` |
| Tauri runnable app/signing | Implemented with honest signing gate | Tauri configs, `scripts/package-desktop.sh`, `scripts/check-release-signing.sh`, `docs/release.md` |
| SSH/PTY/libghostty daemon boundary | Implemented with explicit native-link blockers | `cli/sterm-cli/src/daemon.zig`, `process.zig`, `pty.zig`, `vt.zig`, `docs/agent.md` |
| Final binary/production transport | Implemented | `crates/sterm-protocol/src/lib.rs`, `packages/protocol-client/src/index.ts`, `cli/sterm-cli/src/transport.zig`, `docs/protocol.md` |
| Desktop UI resilience and accessibility | Implemented G006 baseline | `apps/desktop/web/src/App.tsx`, `apps/desktop/web/src/appState.ts`, `apps/desktop/web/tests/mock-shell.test.ts`, `packages/renderer/tests/render-model.test.ts` |
| Multi-client/roaming/agent primitives | Implemented G007 baseline | `fixtures/protocol/client_session.json`, `fixtures/protocol/transport_offer.json`, `fixtures/protocol/agent_detection.json`, `cli/sterm-cli/src/session.zig`, `cli/sterm-cli/src/transport_mode.zig`, `cli/sterm-cli/src/notify.zig` |
| CI/release/doctor gates | Implemented G008 baseline | `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `scripts/check-doctor-output.sh`, `scripts/check-release-artifacts.sh`, `scripts/check-artifact-policy.sh`, `scripts/build-agent.sh` |
| Zig CLI command surface | Implemented baseline with daemon foundation readiness output | `cli/sterm-cli/src/cli.zig`, `cli/sterm-cli/src/test_all.zig` |
| Final evidence bundle | Implemented G009 baseline | `docs/final-production-readiness-audit.md`, `docs/production-goals.json`, `scripts/check-final-readiness.sh` |

## Completion rule

The repository production-readiness contract is complete only when all
risk-first gates above are implemented or fail closed with concrete external
blocker evidence, and `bash scripts/verify.sh` passes. A passing build alone is
not a live production-readiness claim; the final audit records remaining
environment prerequisites for live VM, linked native dependencies, packet-loss
UDP, and signed cross-platform release validation.
