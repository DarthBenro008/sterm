import { describe, expect, test } from "bun:test";
import {
  assertProtocolVersion,
  decodeTransportFrame,
  encodeTransportFrame,
  loadFixtureFrame,
  negotiateProtocol,
  parseProtocolFrame,
  PROTOCOL_VERSION,
  TRANSPORT_HEADER_BYTES,
  TRANSPORT_MAGIC,
  TRANSPORT_WIRE_VERSION,
  TransportError,
  type HelloAckFrame,
  type HelloFrame,
  type PaneDiffFrame,
  type PaneSnapshotFrame,
  type WorkspaceSnapshotFrame,
} from "../src";

const fixtureNames = [
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
  "client_session",
  "transport_offer",
  "agent_detection",
  "health",
  "logs",
  "error",
] as const;

describe("shared protocol fixtures", () => {
  for (const name of fixtureNames) {
    test("loads " + name + ".json as a protocol frame", async () => {
      const frame = await loadFixtureFrame(name);
      expect(String(frame.type)).toBe(name);
    });
  }

  test("handshake fixtures use the package protocol version", async () => {
    const hello = await loadFixtureFrame("hello");
    const ack = await loadFixtureFrame("hello_ack");
    expect(hello.type).toBe("hello");
    expect(ack.type).toBe("hello_ack");
    if (hello.type === "hello") assertProtocolVersion(hello);
    if (ack.type === "hello_ack") assertProtocolVersion(ack);
    expect(PROTOCOL_VERSION).toBe(1);
  });

  test("transport frame round-trips golden hello fixture", async () => {
    const hello = await loadFixtureFrame("hello");
    const encoded = encodeTransportFrame(hello);
    expect([...encoded.slice(0, 4)]).toEqual([...TRANSPORT_MAGIC]);
    const header = new DataView(encoded.buffer, encoded.byteOffset, encoded.byteLength);
    expect(header.getUint16(4, false)).toBe(TRANSPORT_WIRE_VERSION);
    expect(header.getUint16(6, false)).toBe(PROTOCOL_VERSION);
    expect(header.getUint32(8, false)).toBe(encoded.byteLength - TRANSPORT_HEADER_BYTES);
    expect(decodeTransportFrame(encoded)).toEqual(hello);
  });

  test("transport rejects bad magic, bad version, truncation, and trailing bytes", async () => {
    const hello = await loadFixtureFrame("hello");
    const encoded = encodeTransportFrame(hello);

    const badMagic = new Uint8Array(encoded);
    badMagic[0] = 0;
    expect(() => decodeTransportFrame(badMagic)).toThrow(TransportError);

    const badVersion = new Uint8Array(encoded);
    badVersion[5] = 2;
    expect(() => decodeTransportFrame(badVersion)).toThrow(/Unsupported transport wire version 2/);

    expect(() => decodeTransportFrame(encoded.slice(0, TRANSPORT_HEADER_BYTES - 1))).toThrow(/Truncated/);

    const trailing = new Uint8Array(encoded.byteLength + 1);
    trailing.set(encoded);
    expect(() => decodeTransportFrame(trailing)).toThrow(/trailing bytes/);
  });

  test("handshake negotiates shared features and rejects incompatible protocol versions", async () => {
    const hello = (await loadFixtureFrame("hello")) as HelloFrame;
    const ack = (await loadFixtureFrame("hello_ack")) as HelloAckFrame;
    const negotiated = negotiateProtocol(hello, ack);
    expect(negotiated.protocol_version).toBe(PROTOCOL_VERSION);
    expect(negotiated.shared_features).toContain("pane-diff-v1");
    expect(negotiated.shared_features).toContain("multi-client-v1");
    expect(negotiated.shared_features).toContain("roaming-transport-v1");
    expect(negotiated.shared_features).toContain("agent-detection-v1");

    expect(() => negotiateProtocol(hello, { ...ack, protocol_version: 99 })).toThrow(/Unsupported sterm protocol version 99/);
  });

  test("workspace fixture includes tabs, panes, and split layout truth", async () => {
    const frame = (await loadFixtureFrame("workspace_snapshot")) as WorkspaceSnapshotFrame;
    expect(frame.workspace.active_tab_id).toBe("tab_01");
    expect(frame.tabs[0]?.split_tree.type).toBe("split");
    expect(frame.panes.map((pane) => pane.id)).toEqual(["pane_01", "pane_02"]);
  });

  test("render fixtures preserve server-owned snapshot and diff sequences", async () => {
    const snapshot = (await loadFixtureFrame("pane_snapshot")) as PaneSnapshotFrame;
    const diff = (await loadFixtureFrame("pane_diff")) as PaneDiffFrame;
    expect(diff.pane_id).toBe(snapshot.pane_id);
    expect(diff.seq).toBe(snapshot.seq + 1);
    expect(diff.dirty_rows).toHaveLength(1);
  });

  test("operation fixtures cover auth, workspace, pane, health, and logs", async () => {
    const auth = await loadFixtureFrame("auth");
    const workspaceOpen = await loadFixtureFrame("workspace_open");
    const paneCreate = await loadFixtureFrame("pane_create");
    const paneInput = await loadFixtureFrame("pane_input");
    const scrollback = await loadFixtureFrame("scrollback_chunk");
    const session = await loadFixtureFrame("client_session");
    const transportOffer = await loadFixtureFrame("transport_offer");
    const agentDetection = await loadFixtureFrame("agent_detection");
    const health = await loadFixtureFrame("health");
    const logs = await loadFixtureFrame("logs");

    expect(auth.type).toBe("auth");
    if (auth.type === "auth") expect(auth.token_ref.startsWith("keychain://")).toBe(true);
    expect(workspaceOpen.type).toBe("workspace_open");
    expect(paneCreate.type).toBe("pane_create");
    expect(paneInput.type).toBe("pane_input");
    expect(scrollback.type).toBe("scrollback_chunk");
    expect(session.type).toBe("client_session");
    if (session.type === "client_session") expect(session.conflict_policy).toBe("single_writer");
    expect(transportOffer.type).toBe("transport_offer");
    if (transportOffer.type === "transport_offer") expect(transportOffer.requires_ssh_control).toBe(true);
    expect(agentDetection.type).toBe("agent_detection");
    if (agentDetection.type === "agent_detection") expect(agentDetection.agent).toBe("claude");
    if (health.type === "health") expect(health.protocol_version).toBe(PROTOCOL_VERSION);
    if (logs.type === "logs") expect(logs.entries.every((entry) => !entry.message.includes("<fixture-secret>"))).toBe(true);
  });
});
