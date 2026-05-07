//! Fixture-first protocol/domain model shared by the desktop backend and agent lanes.

use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u32 = 1;
pub const FEATURE_PANE_DIFF: &str = "pane-diff-v1";
pub const FEATURE_SCROLLBACK: &str = "scrollback-v1";
pub const FEATURE_NOTIFICATIONS: &str = "notifications-v1";
pub const FEATURE_AUTH_TOKEN_REF: &str = "auth-token-ref-v1";
pub const FEATURE_WORKSPACE_OPS: &str = "workspace-ops-v1";
pub const FEATURE_HEALTH_LOGS: &str = "health-logs-v1";
pub const TRANSPORT_MAGIC: [u8; 4] = *b"STRM";
pub const TRANSPORT_WIRE_VERSION: u16 = 1;
pub const TRANSPORT_HEADER_LEN: usize = 12;
pub const TRANSPORT_MAX_PAYLOAD_BYTES: usize = 16 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FrameType {
    Hello,
    HelloAck,
    Auth,
    WorkspaceOpen,
    WorkspaceClose,
    WorkspaceSnapshot,
    PaneCreate,
    PaneInput,
    PaneResize,
    PaneSnapshot,
    PaneDiff,
    ScrollbackChunk,
    Notification,
    Health,
    Logs,
    Error,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Frame {
    Hello(Hello),
    HelloAck(HelloAck),
    Auth(AuthFrame),
    WorkspaceOpen(WorkspaceOpen),
    WorkspaceClose(WorkspaceClose),
    WorkspaceSnapshot(WorkspaceSnapshotFrame),
    PaneCreate(PaneCreate),
    PaneInput(PaneInput),
    PaneResize(PaneResize),
    PaneSnapshot(PaneSnapshot),
    PaneDiff(PaneDiff),
    ScrollbackChunk(ScrollbackChunk),
    Notification(Notification),
    Health(HealthFrame),
    Logs(LogsFrame),
    Error(ProtocolError),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Hello {
    pub client_version: String,
    pub protocol_version: u32,
    pub supported_features: Vec<String>,
}

impl Hello {
    pub fn current(client_version: impl Into<String>) -> Self {
        Self {
            client_version: client_version.into(),
            protocol_version: PROTOCOL_VERSION,
            supported_features: vec![
                FEATURE_PANE_DIFF.to_string(),
                FEATURE_SCROLLBACK.to_string(),
                FEATURE_NOTIFICATIONS.to_string(),
                FEATURE_AUTH_TOKEN_REF.to_string(),
                FEATURE_WORKSPACE_OPS.to_string(),
                FEATURE_HEALTH_LOGS.to_string(),
            ],
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HelloAck {
    pub agent_version: String,
    pub protocol_version: u32,
    pub supported_features: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuthFrame {
    pub request_id: String,
    pub token_ref: String,
    pub scopes: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkspaceOpen {
    pub request_id: String,
    pub name: String,
    pub root_dir: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WorkspaceClose {
    pub request_id: String,
    pub workspace_id: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WorkspaceSnapshotFrame {
    pub machine: RemoteMachine,
    pub workspace: Workspace,
    pub tabs: Vec<Tab>,
    pub panes: Vec<Pane>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RemoteMachine {
    pub id: String,
    pub hostname: String,
    pub user: String,
    pub os: String,
    pub arch: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Workspace {
    pub id: String,
    pub name: String,
    pub root_dir: String,
    pub active_tab_id: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Tab {
    pub id: String,
    pub title: String,
    pub active_pane_id: String,
    pub split_tree: SplitNode,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SplitNode {
    Pane {
        pane_id: String,
    },
    Split {
        direction: SplitDirection,
        ratio: f32,
        children: Vec<SplitNode>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SplitDirection {
    Horizontal,
    Vertical,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Pane {
    pub id: String,
    pub workspace_id: String,
    pub tab_id: String,
    pub title: String,
    pub cwd: String,
    pub shell: String,
    pub command: String,
    pub rows: u16,
    pub cols: u16,
    pub status: PaneStatus,
    pub process: ProcessMetadata,
    pub pty_id: String,
    pub vt_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProcessMetadata {
    pub pid: u32,
    pub pty_id: String,
    pub command: String,
    pub started_at: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PaneStatus {
    Running,
    Thinking,
    #[serde(rename = "waiting for input")]
    WaitingForInput,
    #[serde(rename = "needs approval")]
    NeedsApproval,
    Error,
    Completed,
    Idle,
    Disconnected,
    Exited,
    Starting,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PaneCreate {
    pub request_id: String,
    pub workspace_id: String,
    pub tab_id: String,
    pub cwd: String,
    pub command: String,
    pub rows: u16,
    pub cols: u16,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PaneInput {
    pub pane_id: String,
    pub seq: u64,
    pub bytes_base64: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PaneResize {
    pub pane_id: String,
    pub rows: u16,
    pub cols: u16,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Cursor {
    pub row: u16,
    pub col: u16,
    pub visible: bool,
    pub style: CursorStyle,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CursorStyle {
    Block,
    Bar,
    Underline,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PaneSnapshot {
    pub pane_id: String,
    pub seq: u64,
    pub rows: u16,
    pub cols: u16,
    pub cursor: Cursor,
    pub cells: String,
    pub scrollback: ScrollbackMetadata,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScrollbackMetadata {
    pub available_lines: u64,
    pub window_start: u64,
    pub window_lines: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PaneDiff {
    pub pane_id: String,
    pub seq: u64,
    pub dirty_rows: Vec<DirtyRow>,
    pub cursor: Cursor,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DirtyRow {
    pub row: u16,
    pub cells: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScrollbackChunk {
    pub pane_id: String,
    pub start_line: u64,
    pub lines: Vec<String>,
    pub has_more: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Notification {
    pub pane_id: String,
    pub level: NotificationLevel,
    pub reason: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotificationLevel {
    Info,
    Attention,
    Warning,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HealthFrame {
    pub status: HealthStatus,
    pub protocol_version: u32,
    pub uptime_ms: u64,
    pub checks: Vec<HealthCheck>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HealthStatus {
    Ok,
    Degraded,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HealthCheck {
    pub name: String,
    pub status: HealthStatus,
    pub detail: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LogsFrame {
    pub scope: LogScope,
    pub entries: Vec<LogEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LogScope {
    Daemon,
    Pane,
    Workspace,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LogEntry {
    pub ts: String,
    pub level: LogLevel,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LogLevel {
    Debug,
    Info,
    Warning,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProtocolError {
    pub code: String,
    pub message: String,
    pub retryable: bool,
}

pub fn parse_frame(json: &str) -> serde_json::Result<Frame> {
    serde_json::from_str(json)
}
pub fn encode_frame(frame: &Frame) -> serde_json::Result<String> {
    serde_json::to_string(frame)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NegotiatedProtocol {
    pub protocol_version: u32,
    pub shared_features: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransportError {
    BadMagic,
    UnsupportedWireVersion(u16),
    UnsupportedProtocolVersion(u32),
    PayloadTooLarge(usize),
    Truncated,
    TrailingBytes,
    InvalidPayload(String),
}

impl std::fmt::Display for TransportError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::BadMagic => f.write_str("bad transport magic"),
            Self::UnsupportedWireVersion(version) => {
                write!(f, "unsupported transport wire version {version}")
            }
            Self::UnsupportedProtocolVersion(version) => {
                write!(f, "unsupported sterm protocol version {version}")
            }
            Self::PayloadTooLarge(size) => write!(f, "transport payload too large: {size} bytes"),
            Self::Truncated => f.write_str("truncated transport frame"),
            Self::TrailingBytes => f.write_str("transport frame has trailing bytes"),
            Self::InvalidPayload(message) => write!(f, "invalid transport payload: {message}"),
        }
    }
}

impl std::error::Error for TransportError {}

pub fn negotiate_protocol(
    hello: &Hello,
    hello_ack: &HelloAck,
) -> Result<NegotiatedProtocol, TransportError> {
    if hello.protocol_version != PROTOCOL_VERSION {
        return Err(TransportError::UnsupportedProtocolVersion(
            hello.protocol_version,
        ));
    }
    if hello_ack.protocol_version != PROTOCOL_VERSION {
        return Err(TransportError::UnsupportedProtocolVersion(
            hello_ack.protocol_version,
        ));
    }
    let shared_features = hello
        .supported_features
        .iter()
        .filter(|feature| hello_ack.supported_features.contains(feature))
        .cloned()
        .collect();
    Ok(NegotiatedProtocol {
        protocol_version: PROTOCOL_VERSION,
        shared_features,
    })
}

pub fn encode_transport_frame(frame: &Frame) -> Result<Vec<u8>, TransportError> {
    let payload =
        encode_frame(frame).map_err(|err| TransportError::InvalidPayload(err.to_string()))?;
    let payload = payload.as_bytes();
    if payload.len() > TRANSPORT_MAX_PAYLOAD_BYTES {
        return Err(TransportError::PayloadTooLarge(payload.len()));
    }

    let mut encoded = Vec::with_capacity(TRANSPORT_HEADER_LEN + payload.len());
    encoded.extend_from_slice(&TRANSPORT_MAGIC);
    encoded.extend_from_slice(&TRANSPORT_WIRE_VERSION.to_be_bytes());
    encoded.extend_from_slice(&(PROTOCOL_VERSION as u16).to_be_bytes());
    encoded.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    encoded.extend_from_slice(payload);
    Ok(encoded)
}

pub fn decode_transport_frame(bytes: &[u8]) -> Result<Frame, TransportError> {
    if bytes.len() < TRANSPORT_HEADER_LEN {
        return Err(TransportError::Truncated);
    }
    if bytes[0..4] != TRANSPORT_MAGIC[..] {
        return Err(TransportError::BadMagic);
    }

    let wire_version = u16::from_be_bytes([bytes[4], bytes[5]]);
    if wire_version != TRANSPORT_WIRE_VERSION {
        return Err(TransportError::UnsupportedWireVersion(wire_version));
    }

    let protocol_version = u16::from_be_bytes([bytes[6], bytes[7]]) as u32;
    if protocol_version != PROTOCOL_VERSION {
        return Err(TransportError::UnsupportedProtocolVersion(protocol_version));
    }

    let payload_len = u32::from_be_bytes([bytes[8], bytes[9], bytes[10], bytes[11]]) as usize;
    if payload_len > TRANSPORT_MAX_PAYLOAD_BYTES {
        return Err(TransportError::PayloadTooLarge(payload_len));
    }
    let expected_len = TRANSPORT_HEADER_LEN + payload_len;
    if bytes.len() < expected_len {
        return Err(TransportError::Truncated);
    }
    if bytes.len() > expected_len {
        return Err(TransportError::TrailingBytes);
    }

    let payload = std::str::from_utf8(&bytes[TRANSPORT_HEADER_LEN..])
        .map_err(|err| TransportError::InvalidPayload(err.to_string()))?;
    parse_frame(payload).map_err(|err| TransportError::InvalidPayload(err.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture(name: &str) -> &'static str {
        match name {
            "hello" => include_str!("../../../fixtures/protocol/hello.json"),
            "hello_ack" => include_str!("../../../fixtures/protocol/hello_ack.json"),
            "auth" => include_str!("../../../fixtures/protocol/auth.json"),
            "workspace_open" => include_str!("../../../fixtures/protocol/workspace_open.json"),
            "workspace_close" => include_str!("../../../fixtures/protocol/workspace_close.json"),
            "workspace_snapshot" => {
                include_str!("../../../fixtures/protocol/workspace_snapshot.json")
            }
            "pane_create" => include_str!("../../../fixtures/protocol/pane_create.json"),
            "pane_input" => include_str!("../../../fixtures/protocol/pane_input.json"),
            "pane_resize" => include_str!("../../../fixtures/protocol/pane_resize.json"),
            "pane_snapshot" => include_str!("../../../fixtures/protocol/pane_snapshot.json"),
            "pane_diff" => include_str!("../../../fixtures/protocol/pane_diff.json"),
            "scrollback_chunk" => include_str!("../../../fixtures/protocol/scrollback_chunk.json"),
            "notification" => include_str!("../../../fixtures/protocol/notification.json"),
            "health" => include_str!("../../../fixtures/protocol/health.json"),
            "logs" => include_str!("../../../fixtures/protocol/logs.json"),
            "error" => include_str!("../../../fixtures/protocol/error.json"),
            _ => unreachable!(),
        }
    }

    #[test]
    fn hello_matches_shared_fixture() {
        let frame = parse_frame(fixture("hello")).unwrap();
        let Frame::Hello(hello) = frame else {
            panic!("expected hello")
        };
        assert_eq!(hello.protocol_version, PROTOCOL_VERSION);
        assert!(hello
            .supported_features
            .contains(&FEATURE_PANE_DIFF.to_string()));
        assert_eq!(Hello::current("0.1.0").protocol_version, PROTOCOL_VERSION);
    }

    #[test]
    fn all_protocol_fixtures_parse_and_round_trip() {
        for name in [
            "hello",
            "hello_ack",
            "auth",
            "workspace_open",
            "workspace_close",
            "workspace_snapshot",
            "pane_create",
            "pane_input",
            "pane_resize",
            "pane_snapshot",
            "pane_diff",
            "scrollback_chunk",
            "notification",
            "health",
            "logs",
            "error",
        ] {
            let frame = parse_frame(fixture(name))
                .unwrap_or_else(|err| panic!("{name} failed to parse: {err}"));
            let encoded = encode_frame(&frame).unwrap();
            let reparsed = parse_frame(&encoded).unwrap();
            assert_eq!(frame, reparsed, "{name} round trip mismatch");
        }
    }

    #[test]
    fn workspace_fixture_preserves_domain_relationships() {
        let Frame::WorkspaceSnapshot(snapshot) =
            parse_frame(fixture("workspace_snapshot")).unwrap()
        else {
            panic!("expected workspace snapshot");
        };
        assert_eq!(snapshot.machine.hostname, "sterm-dev");
        assert_eq!(snapshot.workspace.active_tab_id, "tab_01");
        assert_eq!(snapshot.tabs[0].active_pane_id, "pane_01");
        assert_eq!(snapshot.panes.len(), 2);
        assert_eq!(snapshot.panes[0].process.pty_id, "pty_01");
        assert!(snapshot
            .panes
            .iter()
            .all(|pane| pane.workspace_id == snapshot.workspace.id));
    }

    #[test]
    fn operations_do_not_embed_secret_values() {
        let Frame::Auth(auth) = parse_frame(fixture("auth")).unwrap() else {
            panic!("expected auth frame");
        };
        assert!(auth.token_ref.starts_with("keychain://"));
        assert!(!auth.token_ref.contains("token="));

        let Frame::Logs(logs) = parse_frame(fixture("logs")).unwrap() else {
            panic!("expected logs frame");
        };
        assert!(logs
            .entries
            .iter()
            .all(|entry| !entry.message.contains("<fixture-secret>")));
    }

    #[test]
    fn transport_frame_round_trips_golden_hello() {
        let frame = parse_frame(fixture("hello")).unwrap();
        let encoded = encode_transport_frame(&frame).unwrap();
        assert_eq!(&encoded[0..4], &TRANSPORT_MAGIC);
        assert_eq!(
            u16::from_be_bytes([encoded[4], encoded[5]]),
            TRANSPORT_WIRE_VERSION
        );
        assert_eq!(
            u16::from_be_bytes([encoded[6], encoded[7]]) as u32,
            PROTOCOL_VERSION
        );
        let decoded = decode_transport_frame(&encoded).unwrap();
        assert_eq!(decoded, frame);
    }

    #[test]
    fn transport_rejects_bad_magic_versions_and_truncation() {
        let frame = parse_frame(fixture("hello")).unwrap();
        let mut encoded = encode_transport_frame(&frame).unwrap();

        encoded[0] = b'X';
        assert_eq!(
            decode_transport_frame(&encoded),
            Err(TransportError::BadMagic)
        );

        let mut encoded = encode_transport_frame(&frame).unwrap();
        encoded[5] = 2;
        assert_eq!(
            decode_transport_frame(&encoded),
            Err(TransportError::UnsupportedWireVersion(2))
        );

        let encoded = encode_transport_frame(&frame).unwrap();
        assert_eq!(
            decode_transport_frame(&encoded[0..TRANSPORT_HEADER_LEN - 1]),
            Err(TransportError::Truncated)
        );
    }

    #[test]
    fn handshake_negotiates_shared_features() {
        let Frame::Hello(hello) = parse_frame(fixture("hello")).unwrap() else {
            panic!("expected hello");
        };
        let Frame::HelloAck(ack) = parse_frame(fixture("hello_ack")).unwrap() else {
            panic!("expected hello_ack");
        };
        let negotiated = negotiate_protocol(&hello, &ack).unwrap();
        assert_eq!(negotiated.protocol_version, PROTOCOL_VERSION);
        assert!(negotiated
            .shared_features
            .contains(&FEATURE_PANE_DIFF.to_string()));

        let mut bad_ack = ack;
        bad_ack.protocol_version = 99;
        assert_eq!(
            negotiate_protocol(&hello, &bad_ack),
            Err(TransportError::UnsupportedProtocolVersion(99))
        );
    }
}
