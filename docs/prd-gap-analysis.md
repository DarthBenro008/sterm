# PRD gap analysis through G007

This analysis is the post-`G007-multi-client-mosh-agent-detection` read-through of
`plans/prd.md` against the current implementation. It remains intentionally
evidence-oriented: implemented surfaces are separated from mock/scaffold surfaces
so later goals do not claim production readiness prematurely.

## Implemented baseline

| PRD area | Current evidence |
| --- | --- |
| Monorepo shape | `apps/desktop`, `crates`, `cli/sterm-cli`, `packages`, `proto`, `docs`, `scripts` exist and are verified by `bash scripts/verify.sh`. |
| Tauri v2 desktop boundary | `apps/desktop/src-tauri/tauri.conf.json`, platform-specific Tauri bundle configs, command registration in `src/lib.rs`, and `bun run desktop:build` producing a Linux `.deb`. |
| Shared protocol model | Rust and TypeScript protocol/domain models plus golden JSON fixtures under `fixtures/protocol`; Zig validates the fixture envelope. |
| Safety defaults | Unix-socket-first tunnel planning, no public TCP by default, redaction helpers, private mode constants, bootstrap command validation. |
| Renderer seam | Dirty-region render model and tests in `packages/renderer`; frontend does not parse VT escape sequences; dirty regions are bounds-checked before canvas commands. |
| Desktop UI polish | `apps/desktop/web/src/App.tsx` and `src/appState.ts` provide loading/error states, accessible workspace/pane/status surfaces, keyboard pane navigation, command-palette/shortcut overlays, and honest disabled live mutations while the persistent bridge is absent. |
| Multi-client/roaming/agent detection | Protocol fixtures/types now cover client sessions, encrypted roaming transport offers, and agent detections; Zig owns attach decisions, roaming offer validation, and builtin agent detection with confidence/evidence. |
| Verification posture | Bun/Cargo/Zig/Tauri/signing-readiness gates in `scripts/verify.sh`; production-readiness contract in `scripts/check-production-readiness.sh`. |

## Missing production coverage

| Priority | PRD requirement | Current gap | Goal lane |
| --- | --- | --- | --- |
| P0 | Remote `sterm-cli` daemon owns sockets, config, auth, state, logs, PTYs, processes, VT, and persistence. | G003 adds runtime/config/state/auth/process/PTY/VT readiness contracts and an honest `libghostty-vt` unavailable gate. Remaining after G003: long-running socket accept loop, real PTY spawn, linked SQLite, and linked `libghostty-vt`. | `G003-agent-daemon-storage-process-vt` |
| P0 | Production protocol transport uses typed request/response plus framed binary stream with version negotiation. | JSON fixtures are golden compatibility inputs, but there is no production frame codec/transport handshake across Rust/TS/Zig. | `G004-final-protocol-transport` |
| P0 | Desktop connects to VMs, performs SSH auth/bootstrap/update/tunnel, stores secrets securely, and speaks to the daemon over a persistent channel. | Rust backend plans SSH/bootstrap/tunnels but does not execute SSH sessions, upload binaries, open tunnels, store Keychain secrets, or maintain a persistent IPC/stream bridge. | `G005-full-production-hardening` |
| P1 | Frontend production UX for VM manager, first connect, workspace picker, command palette, keyboard shortcuts, search, clipboard/file paste, and resilient error states. | G006 covers the accessible resilient shell, command palette/shortcut surfaces, keyboard pane focus, and failure states. Remaining live operations are blocked on the persistent Tauri/backend bridge and protocol mutation streams, not on UI-only polish. | `G008-ci-release-observability-doctor` / final bridge work |
| P1 | Notifications and agent-aware panes with robust status detection. | G007 implements builtin detector primitives for common agents and evidence/confidence frames. Remaining production work is wiring live remote output/process events through the daemon loop. | `G008-ci-release-observability-doctor` / final bridge work |
| P1 | Reconnect, multi-client stance, Mosh/UDP-ready transport boundary, and process resilience. | G007 implements explicit single-writer/read-only observer attach decisions and encrypted roaming-UDP offers with SSH fallback. Remaining production work is live daemon loop/session persistence under real network loss. | `G008-ci-release-observability-doctor` / final bridge work |
| P1 | CI/release builds supported agent binaries, runs bootstrap/upgrade/security/golden tests, and signs/releases cross-platform artifacts. | CI runs core checks; release has signing preflight and local Linux package verification but no full signed cross-platform matrix. | `G008-ci-release-observability-doctor` |
| P2 | Final production evidence bundle maps every PRD success criterion to verified code/tests/docs. | Needs to run after implementation lanes complete. | `G009-final-production-readiness-audit` |

## Goal refresh

The existing ultragoal lanes remain valid after the PRD read. The next
implementation order is:

1. `G008-ci-release-observability-doctor` — make CI/release/doctor/logging gates
   execute real checks and fail honestly for unavailable cross-platform signing
   or external production prerequisites.
2. `G009-final-production-readiness-audit` — map every PRD success criterion to
   code, docs, tests, and explicit environment blockers.

The product is not production-ready until all risk-first lanes are complete and
the final audit passes.
