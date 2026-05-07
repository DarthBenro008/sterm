# Production readiness contract

This document is the gating contract for the current `$ultragoal` run. It
exists to prevent the earlier first-wave scaffold from being mistaken for
production readiness while still moving the high-risk items first.

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
| Real Tauri runtime and signing | Active implementation lane. | Desktop app can run/build through a real Tauri boundary; release signing is configured or fails with explicit missing-certificate evidence. | `G002-tauri-desktop-runtime` |
| Real SSH/PTY/libghostty integration | G003 is replacing scaffold runtime with daemon foundations, process/PTY contracts, and explicit unavailable gates for unlinked native dependencies. | Daemon has durable state, safe process/PTY ownership, and a real integration boundary for PTY/libghostty or an honest compile-time unavailable gate. | `G003-agent-daemon-storage-process-vt` |
| Final protocol transport | JSON fixtures are golden compatibility inputs. | Production transport framing/version negotiation exists, with Rust/TS/Zig compatibility and failure tests. | `G004-final-protocol-transport` |
| Full production hardening | Security defaults and redaction tests exist. | SSH/tunnel/bootstrap/keychain/process reliability defaults are hardened with failure-mode tests. | `G005-full-production-hardening` |
| Mature UI polish | G006 adds an accessible fixture-backed desktop shell with explicit loading/error states, keyboard focus, command palette/shortcut surfaces, honest disabled live mutations, and dirty-region invariant tests. | Desktop UI has accessible navigation, resilient errors/loading, polished surfaces, and targeted tests without claiming live SSH bridge ownership. | `G006-mature-ui-polish` |
| Multi-client, Mosh/UDP, agent detection | These were previously explicit non-goals. | Protocol/session/transport/detection primitives are implemented or blocked with environment-specific evidence rather than roadmap deferral. | `G007-multi-client-mosh-agent-detection` |
| CI/release/observability/doctor | Baseline verify and docs exist. | CI/release/doctor/logging gates execute real checks and fail honestly for missing production prerequisites. | `G008-ci-release-observability-doctor` |
| Final readiness audit | Not complete. | Evidence bundle maps every gate to code, docs, tests, and remaining impossible prerequisites. | `G009-final-production-readiness-audit` |

## Classification at the start of this ultragoal

| Area | Classification | Evidence |
| --- | --- | --- |
| Bun workspace and legacy-package-manager guard | Implemented baseline | `package.json`, `bun.lock`, `scripts/verify.sh` |
| Rust protocol fixtures | Implemented baseline | `crates/sterm-protocol`, `fixtures/protocol` |
| TypeScript protocol/renderer/frontend tests | Implemented baseline | `packages/*`, `apps/desktop/web/tests` |
| Desktop UI resilience and accessibility | Implemented G006 baseline | `apps/desktop/web/src/App.tsx`, `apps/desktop/web/src/appState.ts`, `apps/desktop/web/tests/mock-shell.test.ts`, `packages/renderer/tests/render-model.test.ts` |
| Zig CLI command surface | Implemented baseline with daemon foundation readiness output | `cli/sterm-cli/src/cli.zig`, `cli/sterm-cli/src/test_all.zig` |
| Tauri runnable app/signing | In progress under risk-first lane | `G002-tauri-desktop-runtime` |
| Real SSH/PTY/libghostty | In progress under risk-first lane | `G003-agent-daemon-storage-process-vt` |
| Final binary/production transport | In progress under risk-first lane | `G004-final-protocol-transport` |
| Multi-client/Mosh/exhaustive agent detection | In progress under risk-first lane | `G007-multi-client-mosh-agent-detection` |

## Completion rule

The repository is not production-ready until all risk-first gates above are
completed or a gate is checkpointed with concrete environment-blocker evidence
that cannot be resolved inside this container. A passing build alone is not a
production-readiness claim.
