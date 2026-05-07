# Rendering architecture

The frontend is a renderer, not a terminal emulator.

The first-wave renderer consumes server-owned snapshots and diffs:

- `pane_snapshot` initializes pane render state,
- `pane_diff` mutates dirty rows and cursor state,
- render scheduling happens at animation-frame cadence,
- dirty regions are reason-aware and bounds-checked before canvas commands are
  emitted,
- no frontend package parses VT escape sequences as terminal truth.

Canvas 2D is the initial renderer target. WebGPU remains future work.

## Frontend shell contract

The desktop web shell builds a production-shaped view model from shared protocol
fixtures while keeping live mutations disabled until the persistent Tauri bridge
exists. Loading and error states are explicit, pane focus is keyboard-navigable,
and command-palette/search/split actions are visible but honestly gated when the
fixture preview cannot mutate remote daemon state.
