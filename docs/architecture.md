# sterm architecture

`sterm` is remote-first:

```text
macOS desktop app
  -> persistent local IPC/protocol bridge
  -> SSH tunnel
  -> remote Unix socket
  -> sterm-cli daemon
  -> PTY / process / VT / storage
```

## Ownership rules

- `sterm-cli` owns terminal reality.
- The desktop app renders and controls remote state.
- The frontend does not parse VT escape sequences as source of truth.
- Workspace/tab/split layout truth lives with the remote daemon.
- Mock/local flows are development aids, not production integration proof.

## First-wave milestone

After protocol/domain fixtures stabilize, the mock-local vertical milestone proves:

1. workspace snapshot,
2. tab/split/pane render,
3. input event,
4. pane snapshot/diff,
5. renderer dirty-region update,
6. reconnect snapshot reload.
