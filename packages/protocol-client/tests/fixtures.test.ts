import { describe, expect, test } from "bun:test";
import {
  assertProtocolVersion,
  loadFixtureFrame,
  parseProtocolFrame,
  PROTOCOL_VERSION,
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
    const health = await loadFixtureFrame("health");
    const logs = await loadFixtureFrame("logs");

    expect(auth.type).toBe("auth");
    if (auth.type === "auth") expect(auth.token_ref.startsWith("keychain://")).toBe(true);
    expect(workspaceOpen.type).toBe("workspace_open");
    expect(paneCreate.type).toBe("pane_create");
    expect(paneInput.type).toBe("pane_input");
    expect(scrollback.type).toBe("scrollback_chunk");
    if (health.type === "health") expect(health.protocol_version).toBe(PROTOCOL_VERSION);
    if (logs.type === "logs") expect(logs.entries.every((entry) => !entry.message.includes("<fixture-secret>"))).toBe(true);
  });
});
