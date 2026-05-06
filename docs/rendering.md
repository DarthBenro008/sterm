# Rendering architecture

The frontend is a renderer, not a terminal emulator.

The first-wave renderer consumes server-owned snapshots and diffs:

- `pane_snapshot` initializes pane render state,
- `pane_diff` mutates dirty rows and cursor state,
- render scheduling happens at animation-frame cadence,
- no frontend package parses VT escape sequences as terminal truth.

Canvas 2D is the initial renderer target. WebGPU remains future work.
