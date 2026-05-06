# sterm protocol

The first-wave protocol contract is fixture-first and dependency-light. `proto/sterm.proto` records the canonical message surface, while JSON fixtures in `fixtures/protocol/` provide cross-language compatibility inputs for Rust, Zig, and TypeScript.

## Required frame families

- `hello` / `hello_ack` version handshake
- `auth` envelope using keychain/token references, not secret values
- workspace operations (`workspace_open`, `workspace_close`) and `workspace_snapshot`
- remote machine, workspace, tab, split, pane, PTY/process metadata, and status domain model
- pane operations (`pane_create`, `pane_input`, `pane_resize`)
- pane snapshot and pane diff
- scrollback metadata and `scrollback_chunk`
- notification
- error
- health/logs/doctor surfaces (`health`, `logs`)

## Fixture coverage

The shared JSON fixture set currently covers every first-wave frame family:

`hello`, `hello_ack`, `auth`, `workspace_open`, `workspace_close`,
`workspace_snapshot`, `pane_create`, `pane_input`, `pane_resize`,
`pane_snapshot`, `pane_diff`, `scrollback_chunk`, `notification`, `health`,
`logs`, and `error`.

## First-wave serialization decision

The PRD allows MessagePack, Protobuf, or a custom framed binary protocol for production. This first wave keeps the schema and fixtures dependency-light so all package lanes can consume the same contracts before committing to a binary serializer.

## Contract gate

No package lane may define a private incompatible domain/message shape. CLI, Rust backend, frontend, renderer, and storage tests must consume the shared fixtures or record an explicit blocker.
