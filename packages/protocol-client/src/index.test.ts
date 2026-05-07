import { expect, test } from "bun:test";
import { createHello, FEATURES, type PaneDiffFrame, type WorkspaceSnapshotFrame } from "./index";

async function fixture<T>(name: string): Promise<T> {
  return (await Bun.file(new URL(`../../../fixtures/protocol/${name}`, import.meta.url)).json()) as T;
}

test("hello fixture matches client contract", async () => {
  const hello = await fixture<ReturnType<typeof createHello>>("hello.json");
  expect(hello).toEqual(createHello("0.1.0"));
  expect(hello.supported_features).toEqual([...FEATURES]);
  expect(hello.supported_features).toContain("multi-client-v1");
  expect(hello.supported_features).toContain("roaming-transport-v1");
  expect(hello.supported_features).toContain("agent-detection-v1");
});

test("workspace fixture carries remote-owned layout truth", async () => {
  const snapshot = await fixture<WorkspaceSnapshotFrame>("workspace_snapshot.json");
  expect(snapshot.workspace.id).toBe("ws_01");
  expect(snapshot.tabs[0]?.split_tree.type).toBe("split");
  expect(snapshot.panes.map((pane) => pane.pty_id)).toContain("pty_01");
});

test("pane diff fixture has dirty rows", async () => {
  const diff = await fixture<PaneDiffFrame>("pane_diff.json");
  expect(diff.type).toBe("pane_diff");
  expect(diff.dirty_rows[0]?.row).toBe(22);
});
