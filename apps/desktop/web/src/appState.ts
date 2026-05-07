import { applyPaneRenderDiff, buildCanvasCommands, consumeDirtyRegions, createPaneRenderState, type CanvasRenderCommand, type PaneRenderState } from "@sterm/renderer";
import { PROTOCOL_VERSION, TRANSPORT_MAGIC, TRANSPORT_WIRE_VERSION, type Pane, type PaneStatus, type Tab } from "@sterm/protocol-client";
import type { MockDesktopState } from "./mockData";

export type DesktopLoadState =
  | { status: "loading" }
  | { status: "ready"; data: MockDesktopState }
  | { status: "error"; message: string; retryable: true };

export interface KeyboardShortcut {
  id: string;
  keys: string;
  action: string;
  ariaKeyShortcuts: string;
}

export interface CommandPaletteAction {
  id: string;
  label: string;
  description: string;
  shortcut?: string;
  disabledReason?: string;
}

export interface WorkspaceSummary {
  label: string;
  root: string;
  remote: string;
  paneCount: number;
  runningPaneCount: number;
  activeTab: Tab;
  activePaneId: string;
  statusText: string;
}

export interface PaneViewModel {
  id: string;
  title: string;
  ariaLabel: string;
  active: boolean;
  command: string;
  cwd: string;
  dimensions: string;
  status: PaneStatus;
  statusTone: "neutral" | "running" | "attention" | "danger";
  renderState: PaneRenderState;
  canvasCommands: CanvasRenderCommand[];
  dirtySummary: string;
  scrollbackSummary: string;
  snapshotAvailable: boolean;
}

export interface DesktopViewModel {
  workspace: WorkspaceSummary;
  panes: PaneViewModel[];
  shortcuts: KeyboardShortcut[];
  commandPaletteActions: CommandPaletteAction[];
  transportSummary: string;
  rendererSummary: string;
  notificationSummary: string;
}

export const KEYBOARD_SHORTCUTS: KeyboardShortcut[] = [
  { id: "command-palette", keys: "⌘/Ctrl K", action: "Open command palette", ariaKeyShortcuts: "Meta+K Control+K" },
  { id: "shortcuts", keys: "?", action: "Show keyboard shortcuts", ariaKeyShortcuts: "?" },
  { id: "search", keys: "⌘/Ctrl F", action: "Search active pane scrollback", ariaKeyShortcuts: "Meta+F Control+F" },
  { id: "split-right", keys: "⌘/Ctrl \\", action: "Split pane right", ariaKeyShortcuts: "Meta+\\ Control+\\" },
  { id: "split-down", keys: "⌘/Ctrl Shift D", action: "Split pane down", ariaKeyShortcuts: "Meta+Shift+D Control+Shift+D" },
];

export const COMMAND_PALETTE_ACTIONS: CommandPaletteAction[] = [
  {
    id: "connect-vm",
    label: "Connect VM",
    description: "Start SSH auth, bootstrap, tunnel, and protocol handshake.",
    shortcut: "⌘/Ctrl K",
    disabledReason: "Waiting for live backend bridge wiring.",
  },
  {
    id: "split-right",
    label: "Split pane right",
    description: "Ask the remote daemon to create a sibling PTY and render stream.",
    shortcut: "⌘/Ctrl \\",
    disabledReason: "Fixture preview cannot mutate the remote workspace.",
  },
  {
    id: "split-down",
    label: "Split pane down",
    description: "Create a vertical split without making the frontend own process state.",
    shortcut: "⌘/Ctrl Shift D",
    disabledReason: "Fixture preview cannot mutate the remote workspace.",
  },
  {
    id: "search-scrollback",
    label: "Search scrollback",
    description: "Query server-owned scrollback instead of reflowing terminal content locally.",
    shortcut: "⌘/Ctrl F",
    disabledReason: "Search request/response is not connected to the daemon yet.",
  },
];

export function safeErrorMessage(reason: unknown): string {
  const raw = reason instanceof Error
    ? reason.message
    : typeof reason === "string"
      ? reason
      : "The desktop shell could not load the workspace preview.";

  return raw
    .replace(/(token|secret|password|passphrase)(=|:)\S+/gi, "$1$2<redacted>")
    .replace(/keychain:\/\/[^\s]+/gi, "keychain://<redacted>")
    .slice(0, 240);
}

export function createDesktopViewModel(data: MockDesktopState, activePaneId?: string): DesktopViewModel {
  const activeTab = findActiveTab(data);
  const chosenActivePaneId = activePaneId && data.workspace.panes.some((pane) => pane.id === activePaneId)
    ? activePaneId
    : activeTab.active_pane_id;
  const activeRenderState = createActivePaneRenderState(data);
  const panes = data.workspace.panes.map((pane) => createPaneViewModel(pane, activeRenderState, chosenActivePaneId));
  const runningPaneCount = data.workspace.panes.filter((pane) => pane.status === "running" || pane.status === "thinking").length;

  return {
    workspace: {
      label: data.workspace.workspace.name,
      root: data.workspace.workspace.root_dir,
      remote: `${data.workspace.machine.user}@${data.workspace.machine.hostname}`,
      paneCount: data.workspace.panes.length,
      runningPaneCount,
      activeTab,
      activePaneId: chosenActivePaneId,
      statusText: "Fixture-backed preview · live SSH bridge not connected",
    },
    panes,
    shortcuts: KEYBOARD_SHORTCUTS,
    commandPaletteActions: COMMAND_PALETTE_ACTIONS,
    transportSummary: `STRM frame v${TRANSPORT_WIRE_VERSION} · protocol v${PROTOCOL_VERSION} · magic ${formatTransportMagic()}`,
    rendererSummary: "Server-owned VT snapshots and diffs; frontend draws dirty regions only.",
    notificationSummary: `${data.notification.level}: ${data.notification.reason} on ${data.notification.pane_id}`,
  };
}

export function nextPaneId(panes: PaneViewModel[], currentPaneId: string, direction: 1 | -1): string {
  if (panes.length === 0) return currentPaneId;
  const currentIndex = Math.max(0, panes.findIndex((pane) => pane.id === currentPaneId));
  const nextIndex = (currentIndex + direction + panes.length) % panes.length;
  return panes[nextIndex]?.id ?? currentPaneId;
}

function findActiveTab(data: MockDesktopState): Tab {
  const fallbackPaneId = data.workspace.panes[0]?.id ?? "no-pane";
  return data.workspace.tabs.find((tab) => tab.id === data.workspace.workspace.active_tab_id) ?? data.workspace.tabs[0] ?? {
    id: "no-tab",
    title: "No tab attached",
    active_pane_id: fallbackPaneId,
    split_tree: { type: "pane", pane_id: fallbackPaneId },
  };
}

function createActivePaneRenderState(data: MockDesktopState): PaneRenderState {
  const fromSnapshot = createPaneRenderState(data.paneSnapshot);
  const clean = consumeDirtyRegions(fromSnapshot)[0];
  return applyPaneRenderDiff(clean, data.paneDiff);
}

function createPaneViewModel(pane: Pane, activeRenderState: PaneRenderState, activePaneId: string): PaneViewModel {
  const snapshotAvailable = pane.id === activeRenderState.paneId;
  const renderState = snapshotAvailable ? activeRenderState : createPendingRenderState(pane);
  const canvasCommands = buildCanvasCommands(renderState);
  const dirtyCount = renderState.dirtyRegions.length;
  return {
    id: pane.id,
    title: pane.title,
    ariaLabel: `${pane.title}, ${pane.command}, ${pane.status}, ${pane.rows} by ${pane.cols}`,
    active: pane.id === activePaneId,
    command: pane.command,
    cwd: pane.cwd,
    dimensions: `${pane.rows}×${pane.cols}`,
    status: pane.status,
    statusTone: paneStatusTone(pane.status),
    renderState,
    canvasCommands,
    dirtySummary: dirtyCount === 0 ? "No dirty regions queued" : `${dirtyCount} dirty region${dirtyCount === 1 ? "" : "s"} queued`,
    scrollbackSummary: snapshotAvailable
      ? `${renderState.scrollback.window_lines.toLocaleString()} visible / ${renderState.scrollback.available_lines.toLocaleString()} retained`
      : "Snapshot pending from remote daemon",
    snapshotAvailable,
  };
}

function createPendingRenderState(pane: Pane): PaneRenderState {
  return {
    paneId: pane.id,
    seq: 0,
    rows: pane.rows,
    cols: pane.cols,
    cells: "Remote pane is running; render snapshot pending.",
    cursor: { row: 0, col: 0, visible: false, style: "block" },
    dirtyRegions: [],
    scrollback: { available_lines: 0, window_start: 0, window_lines: 0 },
  };
}

function paneStatusTone(status: PaneStatus): PaneViewModel["statusTone"] {
  if (status === "error" || status === "disconnected" || status === "exited") return "danger";
  if (status === "needs approval" || status === "waiting for input") return "attention";
  if (status === "running" || status === "thinking" || status === "starting") return "running";
  return "neutral";
}

function formatTransportMagic(): string {
  return Array.from(TRANSPORT_MAGIC, (byte) => String.fromCharCode(byte)).join("");
}
