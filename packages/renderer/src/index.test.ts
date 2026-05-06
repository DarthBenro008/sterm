import { expect, test } from "bun:test";
import { applyPaneDiff, createRenderModel, DirtyRegionRenderer } from "./index";
import type { PaneDiffFrame, PaneSnapshotFrame } from "@sterm/protocol-client";

async function fixture<T>(name: string): Promise<T> {
  return (await Bun.file(new URL(`../../../fixtures/protocol/${name}`, import.meta.url)).json()) as T;
}

test("snapshot creates dirty full render model", async () => {
  const snapshot = await fixture<PaneSnapshotFrame>("pane_snapshot.json");
  const model = createRenderModel(snapshot);
  expect(model.paneId).toBe("pane_01");
  expect(model.dirtyRows.has(0)).toBe(true);
  expect(model.dirtyRows.has(39)).toBe(true);
});

test("diff marks dirty rows and advances cursor", async () => {
  const snapshot = await fixture<PaneSnapshotFrame>("pane_snapshot.json");
  const diff = await fixture<PaneDiffFrame>("pane_diff.json");
  const updated = applyPaneDiff(createRenderModel(snapshot), diff);
  expect(updated.seq).toBe(18392);
  expect(updated.dirtyRows.has(22)).toBe(true);
  expect(updated.cursor.col).toBe(21);
});

test("renderer coalesces animation-frame flushes", () => {
  let frames = 0;
  let flushes = 0;
  const renderer = new DirtyRegionRenderer({
    requestFrame(callback) {
      frames += 1;
      callback();
    },
  });
  renderer.scheduleFlush(() => (flushes += 1));
  renderer.scheduleFlush(() => (flushes += 1));
  expect(frames).toBe(2);
  expect(flushes).toBe(2);
});
