import { describe, expect, test } from "bun:test";
import { buildCanvasCommands, consumeDirtyRegions, createPaneRenderState } from "@sterm/renderer";
import { loadMockDesktopState } from "../src/mockData";

describe("desktop web mock fixture shell", () => {
  test("loads shared protocol fixtures for workspace surfaces", async () => {
    const state = await loadMockDesktopState();
    expect(state.workspace.workspace.name).toBe("agent-runner");
    expect(state.workspace.tabs).toHaveLength(1);
    expect(state.workspace.panes).toHaveLength(2);
    expect(state.notification.reason).toBe("agent-needs-approval");
  });

  test("uses renderer snapshots instead of frontend VT parsing", async () => {
    const state = await loadMockDesktopState();
    const renderState = createPaneRenderState(state.paneSnapshot);
    const [, dirtyRegions] = consumeDirtyRegions(renderState);
    expect(dirtyRegions).toHaveLength(state.paneSnapshot.rows);
    expect(buildCanvasCommands(renderState).length).toBeGreaterThan(0);
  });
});
