# sterm protocol

The protocol contract now has two layers:

1. **Golden semantic fixtures** in `fixtures/protocol/` used by Rust, Zig, and
   TypeScript compatibility tests.
2. **Production transport framing** used for wire boundaries. The frame header is
   binary and versioned; the current payload remains the canonical JSON frame
   until a later serializer migration is justified by measured pressure.

## Required frame families

- `hello` / `hello_ack` version handshake
- `auth` envelope using keychain/token references, not secret values
- workspace operations (`workspace_open`, `workspace_close`) and `workspace_snapshot`
- remote machine, workspace, tab, split, pane, PTY/process metadata, and status domain model
- pane operations (`pane_create`, `pane_input`, `pane_resize`)
- pane snapshot and pane diff
- scrollback metadata and `scrollback_chunk`
- notification
- client session/attach state (`client_session`) for single-writer and
  read-only observer coordination
- roaming transport offers (`transport_offer`) that keep SSH as the control
  plane and require encrypted UDP streams plus SSH fallback
- agent detection (`agent_detection`) with explicit confidence and evidence
- error
- health/logs/doctor surfaces (`health`, `logs`)

## Fixture coverage

The shared JSON fixture set currently covers every first-wave frame family:

`hello`, `hello_ack`, `auth`, `workspace_open`, `workspace_close`,
`workspace_snapshot`, `pane_create`, `pane_input`, `pane_resize`,
`pane_snapshot`, `pane_diff`, `scrollback_chunk`, `notification`, `health`,
`client_session`, `transport_offer`, `agent_detection`, `logs`, and `error`.

## Multi-client and roaming transport stance

G007 makes the multi-client/Mosh/agent-detection lane explicit in the protocol:

- multi-client attach starts as one active read/write lease per workspace;
  read-only observers must be explicitly allowed by policy,
- roaming/UDP is represented as an encrypted stream offer (`noise_xk`) that
  requires SSH control-plane availability and always advertises SSH tunnel
  fallback,
- agent detection reports the detected agent, status, confidence, and evidence
  source rather than hiding heuristic guesses inside notification copy.

## Production transport frame

The production frame header is 12 bytes:

| Offset | Size | Field |
| --- | ---: | --- |
| 0 | 4 | Magic bytes: `STRM` |
| 4 | 2 | Transport wire version, big-endian (`1`) |
| 6 | 2 | sterm protocol version, big-endian (`1`) |
| 8 | 4 | Payload length, big-endian |

Rules:

- Reject bad magic.
- Reject unsupported transport wire versions.
- Reject unsupported protocol versions during handshake.
- Reject payloads above the configured maximum.
- Reject truncated or trailing-byte frames.
- Keep `hello` / `hello_ack` as the explicit feature negotiation surface.

Rust owns full frame encode/decode in `crates/sterm-protocol`, TypeScript owns
frontend decode/encode in `packages/protocol-client`, and Zig owns header and
frame-boundary validation in `cli/sterm-cli/src/transport.zig`.

## Contract gate

No package lane may define a private incompatible domain/message shape. CLI,
Rust backend, frontend, renderer, and storage tests must consume the shared
fixtures and transport framing or record an explicit blocker.
