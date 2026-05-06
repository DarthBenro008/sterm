# PRD gap analysis after G002

This analysis is the post-`G002-tauri-desktop-runtime` read-through of
`plans/prd.md` against the current implementation. It is intentionally
evidence-oriented: implemented surfaces are separated from mock/scaffold surfaces
so later goals do not claim production readiness prematurely.

## Implemented baseline

| PRD area | Current evidence |
| --- | --- |
| Monorepo shape | `apps/desktop`, `crates`, `cli/sterm-cli`, `packages`, `proto`, `docs`, `scripts` exist and are verified by `bash scripts/verify.sh`. |
| Tauri v2 desktop boundary | `apps/desktop/src-tauri/tauri.conf.json`, platform-specific Tauri bundle configs, command registration in `src/lib.rs`, and `bun run desktop:build` producing a Linux `.deb`. |
| Shared protocol model | Rust and TypeScript protocol/domain models plus golden JSON fixtures under `fixtures/protocol`; Zig validates the fixture envelope. |
| Safety defaults | Unix-socket-first tunnel planning, no public TCP by default, redaction helpers, private mode constants, bootstrap command validation. |
| Renderer seam | Dirty-region render model and tests in `packages/renderer`; frontend does not parse VT escape sequences. |
| Verification posture | Bun/Cargo/Zig/Tauri/signing-readiness gates in `scripts/verify.sh`; production-readiness contract in `scripts/check-production-readiness.sh`. |

## Missing production coverage

| Priority | PRD requirement | Current gap | Goal lane |
| --- | --- | --- | --- |
| P0 | Remote `sterm-cli` daemon owns sockets, config, auth, state, logs, PTYs, processes, VT, and persistence. | G003 adds runtime/config/state/auth/process/PTY/VT readiness contracts and an honest `libghostty-vt` unavailable gate. Remaining after G003: long-running socket accept loop, real PTY spawn, linked SQLite, and linked `libghostty-vt`. | `G003-agent-daemon-storage-process-vt` |
| P0 | Production protocol transport uses typed request/response plus framed binary stream with version negotiation. | JSON fixtures are golden compatibility inputs, but there is no production frame codec/transport handshake across Rust/TS/Zig. | `G004-final-protocol-transport` |
| P0 | Desktop connects to VMs, performs SSH auth/bootstrap/update/tunnel, stores secrets securely, and speaks to the daemon over a persistent channel. | Rust backend plans SSH/bootstrap/tunnels but does not execute SSH sessions, upload binaries, open tunnels, store Keychain secrets, or maintain a persistent IPC/stream bridge. | `G005-full-production-hardening` |
| P1 | Frontend production UX for VM manager, first connect, workspace picker, command palette, keyboard shortcuts, search, clipboard/file paste, and resilient error states. | React app renders mock fixture data and a visual shell; no live connection state or interactive workspace operations. | `G006-mature-ui-polish` |
| P1 | Notifications and agent-aware panes with robust status detection. | Only fixture-based notification display exists; no detector/rule engine or remote event processing. | `G007-multi-client-mosh-agent-detection` |
| P1 | Reconnect, multi-client stance, Mosh/UDP-ready transport boundary, and process resilience. | Protocol/domain docs mention these decisions, but runtime session ownership and conflict controls are not implemented. | `G007-multi-client-mosh-agent-detection` |
| P1 | CI/release builds supported agent binaries, runs bootstrap/upgrade/security/golden tests, and signs/releases cross-platform artifacts. | CI runs core checks; release has signing preflight and local Linux package verification but no full signed cross-platform matrix. | `G008-ci-release-observability-doctor` |
| P2 | Final production evidence bundle maps every PRD success criterion to verified code/tests/docs. | Needs to run after implementation lanes complete. | `G009-final-production-readiness-audit` |

## Goal refresh

The existing ultragoal lanes remain valid after the PRD read. The next
implementation order is:

1. `G003-agent-daemon-storage-process-vt` — replace the Zig scaffold with real
   daemon foundations: path resolution, private directory creation, remote
   config defaults, Unix-socket lifecycle, auth-token file handling, state/log
   layout, migration metadata, process/PTY ownership contracts, and an honest
   `libghostty-vt` availability gate.
2. `G004-final-protocol-transport` — add a production frame codec and explicit
   negotiation/failure behavior while keeping fixtures as golden compatibility
   inputs.
3. `G005-full-production-hardening` — make Rust SSH/bootstrap/tunnel/keychain
   paths executable and security-tested rather than plan-only.

The product is not production-ready until all P0 lanes are complete and the
final audit passes.
