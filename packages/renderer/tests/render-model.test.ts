import { describe, expect, test } from "bun:test";
import { loadFixtureFrame, type PaneDiffFrame, type PaneSnapshotFrame } from "@sterm/protocol-client";
import {
  applyPaneRenderDiff,
  assertDirtyRegionBounds,
  buildCanvasCommands,
  consumeDirtyRegions,
  createPaneRenderState,
  defaultRendererMetrics,
  mergeDirtyRegions,
  scheduleRender,
} from "../src";

describe("snapshot/diff dirty-region model", () => {
  test("creates a full-pane dirty model from a server snapshot", async () => {
    const snapshot = (await loadFixtureFrame("pane_snapshot")) as PaneSnapshotFrame;
    const state = createPaneRenderState(snapshot);
    expect(state.paneId).toBe("pane_01");
    expect(state.dirtyRegions).toHaveLength(snapshot.rows);
    expect(state.dirtyRegions[0]).toEqual({ row: 0, colStart: 0, colEnd: snapshot.cols, reason: "snapshot" });
  });

  test("applies newer server diffs and marks dirty rows plus cursor", async () => {
    const snapshot = (await loadFixtureFrame("pane_snapshot")) as PaneSnapshotFrame;
    const diff = (await loadFixtureFrame("pane_diff")) as PaneDiffFrame;
    const initial = createPaneRenderState(snapshot);
    const clean = consumeDirtyRegions(initial)[0];
    const updated = applyPaneRenderDiff(clean, diff);
    expect(updated.seq).toBe(diff.seq);
    expect(updated.cursor.col).toBe(21);
    expect(updated.dirtyRegions).toContainEqual({ row: 22, colStart: 0, colEnd: snapshot.cols, reason: "diff" });
    expect(updated.dirtyRegions).toContainEqual({ row: 22, colStart: 21, colEnd: 22, reason: "cursor" });
  });

  test("ignores stale diffs and rejects wrong panes", async () => {
    const snapshot = (await loadFixtureFrame("pane_snapshot")) as PaneSnapshotFrame;
    const state = createPaneRenderState(snapshot);
    expect(applyPaneRenderDiff(state, { type: "pane_diff", pane_id: "pane_01", seq: 1, dirty_rows: [], cursor: snapshot.cursor })).toBe(state);
    expect(() => applyPaneRenderDiff(state, { type: "pane_diff", pane_id: "pane_other", seq: 99999, dirty_rows: [], cursor: snapshot.cursor })).toThrow("Cannot apply diff");
  });

  test("keeps dirty regions bounded and reason-aware", async () => {
    const snapshot = (await loadFixtureFrame("pane_snapshot")) as PaneSnapshotFrame;
    const state = createPaneRenderState(snapshot);

    expect(mergeDirtyRegions([
      { row: 2, colStart: 0, colEnd: 4, reason: "diff" },
      { row: 2, colStart: 4, colEnd: 7, reason: "diff" },
      { row: 2, colStart: 4, colEnd: 5, reason: "cursor" },
    ])).toEqual([
      { row: 2, colStart: 0, colEnd: 7, reason: "diff" },
      { row: 2, colStart: 4, colEnd: 5, reason: "cursor" },
    ]);

    assertDirtyRegionBounds({ row: 0, colStart: 0, colEnd: 1, reason: "diff" }, state);
    expect(() => assertDirtyRegionBounds({ row: state.rows, colStart: 0, colEnd: 1, reason: "diff" }, state)).toThrow("outside pane bounds");
    expect(() => applyPaneRenderDiff(state, {
      type: "pane_diff",
      pane_id: state.paneId,
      seq: state.seq + 1,
      dirty_rows: [{ row: state.rows + 1, cells: "" }],
      cursor: snapshot.cursor,
    })).toThrow("outside pane bounds");
  });

  test("builds Canvas-oriented commands without parsing terminal escapes", async () => {
    const snapshot = (await loadFixtureFrame("pane_snapshot")) as PaneSnapshotFrame;
    const commands = buildCanvasCommands(createPaneRenderState(snapshot));
    expect(commands.some((command) => command.kind === "paint-cells")).toBe(true);
    expect(commands.some((command) => command.kind === "paint-cursor")).toBe(true);
  });

  test("schedules rendering at animation-frame cadence", () => {
    let rendered = false;
    const id = scheduleRender((callback) => {
      callback(1);
      return 7;
    }, () => {
      rendered = true;
    });
    expect(id).toBe(7);
    expect(rendered).toBe(true);
    expect(defaultRendererMetrics(40, 120, 2).cellHeight).toBe(36);
  });
});
