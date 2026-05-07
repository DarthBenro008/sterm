# Roadmap and deferred scope ledger

## Risk-first production lanes

| Item | Lane | Status |
| --- | --- | --- |
| Real Tauri runtime and signing-ready release | desktop/release | active in `$ultragoal` G002 |
| Real SSH/PTY/libghostty E2E | integration | active in `$ultragoal` G003 |
| Final protocol transport | protocol | active in `$ultragoal` G004 |
| Full production hardening | security/reliability | active in `$ultragoal` G005 |
| Mature UI polish | frontend/ux | completed in `$ultragoal` G006 |
| Multi-client mode | protocol/agent | completed in `$ultragoal` G007 |
| Mosh/UDP transport | transport | completed as encrypted roaming-UDP boundary in `$ultragoal` G007 |
| Exhaustive agent detection | notifications/agent-workflows | completed as builtin detector/evidence contract in `$ultragoal` G007 |
| CI/release/observability/doctor gates | release/ops | active in `$ultragoal` G008 |

## Open PRD questions carried forward

- `libghostty-vt` API stability: adapter isolation exists; vendoring/version policy is handled by G003.
- Multi-client support: the previous one-client stance is superseded by G007.
- Process resilience: supervisor separation moves into G003/G005.
- Transport evolution: SSH tunnel plus Mosh/UDP-compatible boundaries move into G007.
