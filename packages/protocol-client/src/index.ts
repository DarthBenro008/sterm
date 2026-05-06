export const PROTOCOL_VERSION = 1;

export const FEATURES = [
  "pane-diff-v1",
  "scrollback-v1",
  "notifications-v1",
  "auth-token-ref-v1",
  "workspace-ops-v1",
  "health-logs-v1",
] as const;

export type Feature = (typeof FEATURES)[number];

export interface HelloFrame {
  type: "hello";
  client_version: string;
  protocol_version: number;
  supported_features: Feature[];
}

export interface HelloAckFrame {
  type: "hello_ack";
  agent_version: string;
  protocol_version: number;
  supported_features: Feature[];
}

export interface AuthFrame {
  type: "auth";
  request_id: string;
  token_ref: string;
  scopes: string[];
}

export interface WorkspaceOpenFrame {
  type: "workspace_open";
  request_id: string;
  name: string;
  root_dir: string;
}

export interface WorkspaceCloseFrame {
  type: "workspace_close";
  request_id: string;
  workspace_id: string;
}

export interface WorkspaceSnapshotFrame {
  type: "workspace_snapshot";
  machine: RemoteMachine;
  workspace: Workspace;
  tabs: Tab[];
  panes: Pane[];
}

export interface RemoteMachine {
  id: string;
  hostname: string;
  user: string;
  os: string;
  arch: string;
}

export interface Workspace {
  id: string;
  name: string;
  root_dir: string;
  active_tab_id: string;
}

export interface Tab {
  id: string;
  title: string;
  active_pane_id: string;
  split_tree: SplitNode;
}

export type SplitNode =
  | { type: "pane"; pane_id: string }
  | {
      type: "split";
      direction: "horizontal" | "vertical";
      ratio: number;
      children: SplitNode[];
    };

export interface Pane {
  id: string;
  workspace_id: string;
  tab_id: string;
  title: string;
  cwd: string;
  shell: string;
  command: string;
  rows: number;
  cols: number;
  status: PaneStatus;
  process: ProcessMetadata;
  pty_id: string;
  vt_id: string;
}

export interface ProcessMetadata {
  pid: number;
  pty_id: string;
  command: string;
  started_at: string;
}

export type PaneStatus =
  | "running"
  | "thinking"
  | "waiting for input"
  | "needs approval"
  | "error"
  | "completed"
  | "idle"
  | "disconnected"
  | "exited"
  | "starting";

export interface PaneCreateFrame {
  type: "pane_create";
  request_id: string;
  workspace_id: string;
  tab_id: string;
  cwd: string;
  command: string;
  rows: number;
  cols: number;
}

export interface PaneInputFrame {
  type: "pane_input";
  pane_id: string;
  seq: number;
  bytes_base64: string;
}

export interface PaneResizeFrame {
  type: "pane_resize";
  pane_id: string;
  rows: number;
  cols: number;
}

export interface Cursor {
  row: number;
  col: number;
  visible: boolean;
  style: "block" | "bar" | "underline" | string;
}

export interface PaneSnapshotFrame {
  type: "pane_snapshot";
  pane_id: string;
  seq: number;
  rows: number;
  cols: number;
  cursor: Cursor;
  cells: string;
  scrollback: {
    available_lines: number;
    window_start: number;
    window_lines: number;
  };
}

export interface PaneDiffFrame {
  type: "pane_diff";
  pane_id: string;
  seq: number;
  dirty_rows: Array<{ row: number; cells: string }>;
  cursor: Cursor;
}

export interface ScrollbackChunkFrame {
  type: "scrollback_chunk";
  pane_id: string;
  start_line: number;
  lines: string[];
  has_more: boolean;
}

export interface NotificationFrame {
  type: "notification";
  pane_id: string;
  level: "info" | "attention" | "warning" | "error" | string;
  reason: string;
}

export type HealthStatus = "ok" | "degraded" | "error";

export interface HealthFrame {
  type: "health";
  status: HealthStatus;
  protocol_version: number;
  uptime_ms: number;
  checks: Array<{
    name: string;
    status: HealthStatus;
    detail?: string | null;
  }>;
}

export interface LogsFrame {
  type: "logs";
  scope: "daemon" | "pane" | "workspace";
  entries: Array<{
    ts: string;
    level: "debug" | "info" | "warning" | "error";
    message: string;
  }>;
}

export interface ErrorFrame {
  type: "error";
  code: string;
  message: string;
  retryable: boolean;
}

export type StermFrame =
  | HelloFrame
  | HelloAckFrame
  | AuthFrame
  | WorkspaceOpenFrame
  | WorkspaceCloseFrame
  | WorkspaceSnapshotFrame
  | PaneCreateFrame
  | PaneInputFrame
  | PaneResizeFrame
  | PaneSnapshotFrame
  | PaneDiffFrame
  | ScrollbackChunkFrame
  | NotificationFrame
  | HealthFrame
  | LogsFrame
  | ErrorFrame;

export function createHello(clientVersion: string): HelloFrame {
  return {
    type: "hello",
    client_version: clientVersion,
    protocol_version: PROTOCOL_VERSION,
    supported_features: [...FEATURES],
  };
}

export function assertKnownFrame(frame: StermFrame): StermFrame {
  if (!frame || typeof frame !== "object" || !("type" in frame)) {
    throw new Error("Invalid sterm frame");
  }
  return frame;
}

export type ProtocolFeature = Feature;
export type CursorState = Cursor;
export type DirtyRow = PaneDiffFrame["dirty_rows"][number];
export type ProtocolFrame = StermFrame;

export function isProtocolFrame(value: unknown): value is ProtocolFrame {
  return Boolean(value && typeof value === "object" && "type" in value);
}

export function parseProtocolFrame(value: unknown): ProtocolFrame {
  if (!isProtocolFrame(value)) {
    throw new Error("Invalid sterm protocol frame: missing type");
  }
  return value as ProtocolFrame;
}

export function assertProtocolVersion(frame: HelloFrame | HelloAckFrame): void {
  if (frame.protocol_version !== PROTOCOL_VERSION) {
    throw new Error(`Unsupported sterm protocol version ${frame.protocol_version}`);
  }
}

export function fixturePath(name: string): string {
  return new URL(`../../../fixtures/protocol/${name}.json`, import.meta.url).pathname;
}

export async function loadFixtureFrame(name: string): Promise<ProtocolFrame> {
  return parseProtocolFrame(await Bun.file(fixturePath(name)).json());
}
