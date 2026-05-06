# Remote agent

`sterm-cli` is the remote source of truth for:

- workspaces,
- tabs,
- split layouts,
- panes,
- PTYs,
- process lifecycle,
- VT state,
- scrollback,
- render snapshots/diffs,
- notifications,
- storage,
- doctor/observability checks.

The first wave includes a mock VT adapter boundary. Real `libghostty-vt` integration is intentionally isolated behind `cli/sterm-cli/src/vt/ghostty_adapter.zig`.
