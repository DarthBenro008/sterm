export const PROTOCOL_VERSION = 1;
export const TRANSPORT_MAGIC = new Uint8Array([0x53, 0x54, 0x52, 0x4d]); // STRM
export const TRANSPORT_WIRE_VERSION = 1;
export const TRANSPORT_HEADER_BYTES = 12;
export const TRANSPORT_MAX_PAYLOAD_BYTES = 16 * 1024 * 1024;

export const FEATURES = [
  "pane-diff-v1",
  "scrollback-v1",
  "notifications-v1",
  "auth-token-ref-v1",
  "workspace-ops-v1",
  "health-logs-v1",
  "multi-client-v1",
  "roaming-transport-v1",
  "agent-detection-v1",
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

export type ClientSessionMode = "read_write" | "read_only_observer";
export type ClientConflictPolicy = "single_writer" | "read_only_observers";

export interface ClientSessionFrame {
  type: "client_session";
  session_id: string;
  client_id: string;
  workspace_id: string;
  mode: ClientSessionMode;
  conflict_policy: ClientConflictPolicy;
  lease_owner: string | null;
  lease_expires_at: string | null;
}

export type ControlTransport = "ssh_tunnel";
export type StreamTransport = "ssh_tunnel" | "roaming_udp";
export type TransportEncryption = "ssh" | "noise_xk";

export interface TransportOfferFrame {
  type: "transport_offer";
  request_id: string;
  control: ControlTransport;
  stream: StreamTransport;
  encryption: TransportEncryption;
  requires_ssh_control: boolean;
  udp_port: number | null;
  fallback: StreamTransport;
}

export type AgentKind = "claude" | "codex" | "aider" | "cursor-agent" | "opencode" | "custom" | "unknown";
export type DetectionConfidence = "low" | "medium" | "high";
export type DetectionEvidenceSource = "process_command" | "pane_title" | "terminal_output" | "manual_tag" | "custom_rule";

export interface AgentDetectionFrame {
  type: "agent_detection";
  pane_id: string;
  agent: AgentKind;
  status: PaneStatus;
  confidence: DetectionConfidence;
  evidence: Array<{
    source: DetectionEvidenceSource;
    value: string;
  }>;
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
  | ClientSessionFrame
  | TransportOfferFrame
  | AgentDetectionFrame
  | HealthFrame
  | LogsFrame
  | ErrorFrame;

export interface NegotiatedProtocol {
  protocol_version: number;
  shared_features: Feature[];
}

export class TransportError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TransportError";
  }
}

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

export function negotiateProtocol(hello: HelloFrame, ack: HelloAckFrame): NegotiatedProtocol {
  assertProtocolVersion(hello);
  assertProtocolVersion(ack);
  return {
    protocol_version: PROTOCOL_VERSION,
    shared_features: hello.supported_features.filter((feature) => ack.supported_features.includes(feature)),
  };
}

export function encodeTransportFrame(frame: ProtocolFrame): Uint8Array {
  const payload = new TextEncoder().encode(JSON.stringify(frame));
  if (payload.byteLength > TRANSPORT_MAX_PAYLOAD_BYTES) {
    throw new TransportError(`Transport payload too large: ${payload.byteLength} bytes`);
  }
  const encoded = new Uint8Array(TRANSPORT_HEADER_BYTES + payload.byteLength);
  encoded.set(TRANSPORT_MAGIC, 0);
  const view = new DataView(encoded.buffer);
  view.setUint16(4, TRANSPORT_WIRE_VERSION, false);
  view.setUint16(6, PROTOCOL_VERSION, false);
  view.setUint32(8, payload.byteLength, false);
  encoded.set(payload, TRANSPORT_HEADER_BYTES);
  return encoded;
}

export function decodeTransportFrame(bytes: Uint8Array): ProtocolFrame {
  if (bytes.byteLength < TRANSPORT_HEADER_BYTES) {
    throw new TransportError("Truncated transport frame");
  }
  for (let index = 0; index < TRANSPORT_MAGIC.byteLength; index += 1) {
    if (bytes[index] !== TRANSPORT_MAGIC[index]) {
      throw new TransportError("Bad transport magic");
    }
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const wireVersion = view.getUint16(4, false);
  if (wireVersion !== TRANSPORT_WIRE_VERSION) {
    throw new TransportError(`Unsupported transport wire version ${wireVersion}`);
  }
  const protocolVersion = view.getUint16(6, false);
  if (protocolVersion !== PROTOCOL_VERSION) {
    throw new TransportError(`Unsupported sterm protocol version ${protocolVersion}`);
  }
  const payloadLength = view.getUint32(8, false);
  if (payloadLength > TRANSPORT_MAX_PAYLOAD_BYTES) {
    throw new TransportError(`Transport payload too large: ${payloadLength} bytes`);
  }
  const expectedLength = TRANSPORT_HEADER_BYTES + payloadLength;
  if (bytes.byteLength < expectedLength) {
    throw new TransportError("Truncated transport frame");
  }
  if (bytes.byteLength > expectedLength) {
    throw new TransportError("Transport frame has trailing bytes");
  }
  const payload = new TextDecoder().decode(bytes.slice(TRANSPORT_HEADER_BYTES));
  return parseProtocolFrame(JSON.parse(payload));
}

export function fixturePath(name: string): string {
  return new URL(`../../../fixtures/protocol/${name}.json`, import.meta.url).pathname;
}

export async function loadFixtureFrame(name: string): Promise<ProtocolFrame> {
  return parseProtocolFrame(await Bun.file(fixturePath(name)).json());
}
