# PRD gap analysis through G009

This analysis is the post-`G009-final-production-readiness-audit` read-through
of `plans/prd.md` against the current implementation. It remains intentionally
evidence-oriented: implemented surfaces are separated from external environment
blockers so the repository does not claim live VM, signing, or native-link proof
that cannot be produced inside this container.

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
| Verification posture | Bun/Cargo/Zig/Tauri/signing-readiness gates in `scripts/verify.sh`; production-readiness contract in `scripts/check-production-readiness.sh`; G008 adds doctor-output, artifact-policy, agent-artifact, checksum, CI dependency, and release preflight gates; G009 adds final audit evidence and gate checks. |

## External blockers and fail-closed gates

| Priority | PRD requirement | Current state | Gate |
| --- | --- | --- | --- |
| P0 | Remote `sterm-cli` daemon owns sockets, config, auth, state, logs, PTYs, processes, VT, and persistence. | Daemon/runtime/storage/process/PTY/VT contracts exist. Live socket accept loop, real PTY spawn, linked SQLite, and linked `libghostty-vt` require target environment/native dependencies. | Doctor/status report `sqlite3-unlinked` and `libghostty-vt-unavailable`; final audit lists blockers. |
| P0 | Production protocol transport uses typed request/response plus framed binary stream with version negotiation. | `STRM` production frame codec and negotiation exist across Rust, TS, and Zig; fixtures remain golden semantic inputs. | Rust/TS/Zig transport tests and `docs/protocol.md`. |
| P0 | Desktop connects to VMs, performs SSH auth/bootstrap/update/tunnel, stores secrets securely, and speaks to the daemon over a persistent channel. | SSH/bootstrap/tunnel/keychain/security plans and gates exist. Live VM bootstrap requires external VM credentials/host-key evidence. | Strict host-key/secret/tunnel tests; final audit lists live VM blocker. |
| P1 | Frontend production UX for VM manager, first connect, workspace picker, command palette, keyboard shortcuts, search, clipboard/file paste, and resilient error states. | Accessible resilient shell, command palette/shortcut surfaces, keyboard pane focus, failure states, and honest disabled live mutations exist. | Bun web tests/typecheck/build. |
| P1 | Notifications and agent-aware panes with robust status detection. | Builtin detector primitives and evidence/confidence frames exist; live PTY/libghostty event feed requires target environment/native dependencies. | Protocol and Zig detection tests; final audit lists live event-feed blocker. |
| P1 | Reconnect, multi-client stance, Mosh/UDP-ready transport boundary, and process resilience. | Single-writer/read-only observer attach decisions and encrypted roaming-UDP offers with SSH fallback exist; packet-loss proof requires a network testbed. | Zig session/transport tests; final audit lists UDP testbed blocker. |
| P1 | CI/release builds supported agent binaries, runs bootstrap/upgrade/security/golden tests, and signs/releases cross-platform artifacts. | Agent artifacts/checksums, CI deps, doctor/artifact policy, signing preflight, and local Linux packaging gates exist. Signed cross-platform artifacts need signing secrets and platform runners. | Release workflow/scripts fail closed when credentials are absent. |
| P2 | Final production evidence bundle maps every PRD success criterion to verified code/tests/docs. | G009 final audit exists and is gated by `scripts/check-final-readiness.sh`. | `docs/final-production-readiness-audit.md`, `bash scripts/verify.sh`. |

## Goal refresh

All risk-first ultragoal lanes are complete in the repository contract. The
remaining items are explicit external production prerequisites tracked in the
final audit, not hidden implementation lanes.
