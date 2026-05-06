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

The current daemon foundation validates production-shaped runtime paths, private
Unix-socket defaults, auth-token file mode, state-store migration metadata,
PTY/process ownership contracts, and per-pane supervisor boundaries.

`libghostty-vt` remains isolated behind
`cli/sterm-cli/src/vt/ghostty_adapter.zig`. When the library is not linked, the
agent reports `libghostty-vt-unavailable` explicitly instead of silently moving
VT parsing into the frontend.
