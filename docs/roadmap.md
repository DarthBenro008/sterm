# Roadmap and production readiness ledger

## Risk-first production lanes

| Item | Lane | Status |
| --- | --- | --- |
| Real Tauri runtime and signing-ready release | desktop/release | completed in `$ultragoal` G002 |
| SSH/PTY/libghostty daemon/native-link gates | integration | completed as daemon foundations plus linked Ghostty VT production build gate; live VM PTY depth remains an external prerequisite |
| Final protocol transport | protocol | completed in `$ultragoal` G004 |
| Full production hardening | security/reliability | completed in `$ultragoal` G005 |
| Mature UI polish | frontend/ux | completed in `$ultragoal` G006 |
| Multi-client mode | protocol/agent | completed in `$ultragoal` G007 |
| Mosh/UDP transport | transport | completed as encrypted roaming-UDP boundary in `$ultragoal` G007 |
| Exhaustive agent detection | notifications/agent-workflows | completed as builtin detector/evidence contract in `$ultragoal` G007 |
| CI/release/observability/doctor gates | release/ops | completed in `$ultragoal` G008 |

## Open PRD questions resolved or gated

- `libghostty-vt` API stability: adapter isolation exists, production builds
  link Ghostty as a Zig dependency, and unlinked development builds fail
  explicitly with `libghostty-vt-unavailable`.
- Multi-client support: G007 implements a single-writer/read-only-observer
  contract.
- Process resilience: G003/G005 provide per-pane supervisor/process-group
  contracts and security gates.
- Transport evolution: G007 adds SSH-control plus encrypted roaming-UDP stream
  offers with SSH fallback.
