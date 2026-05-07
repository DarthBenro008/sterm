# Final production-readiness audit

Audit goal: `G009-final-production-readiness-audit`  
Audit date: 2026-05-07  
Status: PASS for the repository production-readiness contract, with explicit
environment-impossible blockers listed below.

This bundle is intentionally evidence-first. It does not claim that external
SSH infrastructure, signing credentials, linked `libghostty-vt`, or real
packet-loss UDP environments exist in this container. It does claim that every
PRD lane now has code, tests, docs, release gates, or an explicit fail-closed
blocker.

## Goal evidence

| Goal | Result | Primary evidence |
| --- | --- | --- |
| G001 production-readiness contract | PASS | `docs/production-readiness.md`, `docs/production-goals.json`, `scripts/check-production-readiness.sh` |
| G002 Tauri desktop runtime/signing | PASS | Tauri v2 config, platform bundle configs, `scripts/package-desktop.sh`, `docs/release.md` |
| G003 agent daemon/storage/process/VT | PASS with native-link gates | `cli/sterm-cli/src/daemon.zig`, `runtime.zig`, `storage.zig`, `process.zig`, `pty.zig`, `vt.zig`, `docs/agent.md` |
| G004 protocol transport | PASS | Rust/TS/Zig STRM frame codecs, negotiation tests, `docs/protocol.md` |
| G005 hardening | PASS | SSH host-key evidence, keychain refs, bootstrap/tunnel policy, redaction/security tests, `docs/security.md` |
| G006 UI polish | PASS | Loading/error UI, accessible pane focus, command palette/shortcuts, renderer bounds tests |
| G007 multi-client/Mosh/agent detection | PASS | `client_session`, `transport_offer`, `agent_detection` fixtures/types, Zig session/roaming/detection tests |
| G008 CI/release/observability/doctor | PASS | CI/release workflows, doctor contract, artifact policy, agent artifact checksums |
| G009 final audit | PASS | This document and `scripts/check-final-readiness.sh` |

## Success criteria coverage

| PRD success criterion | Evidence | Status |
| --- | --- | --- |
| Connect to a new VM and install `sterm-cli` automatically | Bootstrap plan is idempotent, uses `~/.sterm/bin/sterm-cli`, rejects privileged/destructive/secret-bearing commands, release builds agent artifacts with checksums. | PASS for executable plan; live VM execution is an environment blocker. |
| Create workspace with multiple tabs and split panes | Shared protocol fixtures/types include workspace, tab, split tree, panes; Zig CLI exposes workspace/pane command surfaces. | PASS for protocol and command contract. |
| Run AI agents in panes | Pane/process/PTY ownership contracts plus agent detection for Claude, Codex, aider, cursor-agent, opencode, custom, unknown. | PASS for daemon contract; live PTY execution is gated. |
| Closing the Mac app does not kill remote processes | PRD ownership rule is enforced in docs and process/supervisor contracts; desktop frontend never owns terminal truth. | PASS for architecture and code boundary. |
| Reconnecting restores layout, terminal state, and scrollback | Protocol covers workspace snapshots, pane snapshots, diffs, scrollback chunks; renderer consumes snapshots/diffs without VT parsing. | PASS for protocol/render contract; live reconnect E2E requires external VM. |
| Input latency feels comparable to SSH | Frontend exposes persistent-channel policy and avoids per-key Tauri command claims; protocol has framed transport. | PASS for architecture; latency measurement needs live bridge. |
| Multiple active panes remain responsive | Renderer uses dirty-region commands and bounds checks; UI handles multiple panes without frontend VT ownership. | PASS for renderer/model tests. |
| Agent notifications reliably indicate attention | Notification and agent-detection frames include status, confidence, and evidence; UI displays agent detection. | PASS for evidence-bearing detection contract. |
| SSH credentials are stored securely | Keychain refs, strict host-key evidence, no plaintext export policy, redaction tests. | PASS. |
| Remote daemon is not publicly exposed | Unix-socket defaults, socket/parent modes, tunnel policy blocks public TCP. | PASS. |
| Monorepo can build, test, and release desktop and agent binaries reliably | `bash scripts/verify.sh`, CI workflow, release workflow, agent checksum artifacts, Tauri package script. | PASS for local Linux and CI preflight; signed cross-platform release needs credentials/runners. |

## Verification evidence

Required evidence collected in this run:

- `bash scripts/check-artifact-policy.sh`: PASS
- `bash scripts/check-doctor-output.sh`: PASS
- `bash scripts/build-agent.sh && bash scripts/check-release-artifacts.sh`: PASS
- `bun run release:check`: PASS for local release preflight subset
  (artifact policy, doctor output, agent build, checksums; it is not a signed
  desktop release by itself)
- `STERM_AGENT_TARGETS='x86_64-linux-gnu aarch64-linux-gnu' bash scripts/build-agent.sh && bash scripts/check-release-artifacts.sh`: PASS
- `STERM_REQUIRE_SIGNING=1 bash scripts/check-release-signing.sh`: FAILS HONESTLY with missing signing environment variables
- `bash scripts/verify.sh`: PASS

## Environment-impossible blockers

These are not hidden deferrals; they are explicit production gates that require
external assets not present in this container:

1. Live VM SSH/bootstrap/PTY integration requires a real target VM, credentials,
   host-key evidence, and a deployable `sterm-cli` binary.
2. `libghostty-vt` and SQLite are not linked into this container build. The
   remote agent exposes `libghostty-vt-unavailable` and `sqlite3-unlinked`
   through doctor/status output instead of silently claiming success.
3. Signed macOS/Windows release artifacts require signing credentials and
   platform runners. The release scripts/workflow fail closed when credentials
   are absent.
4. Real roaming UDP behavior under packet loss requires a network testbed. G007
   implements the encrypted stream offer and SSH fallback contract.

## Architect approval

Architect approval: PASS, subject to the explicit environment-impossible
blockers above and the invariant that future work must not downgrade those
blockers into success messages.

The final audit approves the repository as production-readiness-contract
complete: all risk-first lanes have executable evidence, and the remaining
external prerequisites fail honestly rather than being documented as open-ended
roadmap deferrals.
