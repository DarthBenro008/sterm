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

G007 adds daemon-owned coordination primitives for:

- one active read/write client lease per workspace, with explicit read-only
  observer attach policy,
- SSH-control-plane plus encrypted roaming-UDP stream offers with SSH fallback,
- built-in agent detection for Claude, Codex, aider, cursor-agent, opencode,
  custom commands, and low-confidence unknown panes.

`libghostty-vt` remains isolated behind
`cli/sterm-cli/src/vt/ghostty_adapter.zig`. When the library is not linked, the
agent reports `libghostty-vt-unavailable` explicitly instead of silently moving
VT parsing into the frontend.
