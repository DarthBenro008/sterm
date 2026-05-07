import { describe, expect, test } from "bun:test";
import { buildCanvasCommands, consumeDirtyRegions, createPaneRenderState } from "@sterm/renderer";
import { COMMAND_PALETTE_ACTIONS, createDesktopViewModel, KEYBOARD_SHORTCUTS, nextPaneId, safeErrorMessage } from "../src/appState";
import { loadMockDesktopState } from "../src/mockData";

describe("desktop web mock fixture shell", () => {
  test("loads shared protocol fixtures for workspace surfaces", async () => {
    const state = await loadMockDesktopState();
    expect(state.workspace.workspace.name).toBe("agent-runner");
    expect(state.workspace.tabs).toHaveLength(1);
    expect(state.workspace.panes).toHaveLength(2);
    expect(state.notification.reason).toBe("agent-needs-approval");
    expect(state.agentDetection.agent).toBe("claude");
  });

  test("creates an accessible production shell view model without live mutation claims", async () => {
    const state = await loadMockDesktopState();
    const view = createDesktopViewModel(state);

    expect(view.workspace.remote).toBe("ubuntu@sterm-dev");
    expect(view.workspace.statusText).toContain("live SSH bridge not connected");
    expect(view.transportSummary).toContain("STRM");
    expect(view.rendererSummary).toContain("Server-owned VT");
    expect(view.agentDetectionSummary).toContain("claude");
    expect(view.panes).toHaveLength(2);
    expect(view.panes[0]?.ariaLabel).toContain("Claude Agent");
    expect(view.panes[0]?.agentSummary).toContain("needs approval");
    expect(view.panes[0]?.snapshotAvailable).toBe(true);
    expect(view.panes[1]?.snapshotAvailable).toBe(false);
    expect(view.panes[1]?.scrollbackSummary).toContain("Snapshot pending");
  });

  test("keeps pane focus keyboard navigation deterministic", async () => {
    const state = await loadMockDesktopState();
    const view = createDesktopViewModel(state);

    expect(nextPaneId(view.panes, "pane_01", 1)).toBe("pane_02");
    expect(nextPaneId(view.panes, "pane_02", 1)).toBe("pane_01");
    expect(nextPaneId(view.panes, "pane_01", -1)).toBe("pane_02");
  });

  test("documents command palette shortcuts while disabling fixture-only mutations", () => {
    expect(KEYBOARD_SHORTCUTS.map((shortcut) => shortcut.id)).toContain("command-palette");
    expect(KEYBOARD_SHORTCUTS.map((shortcut) => shortcut.id)).toContain("split-down");
    expect(COMMAND_PALETTE_ACTIONS.find((action) => action.id === "connect-vm")?.disabledReason).toContain("live backend bridge");
  });

  test("sanitizes load errors before rendering them", () => {
    expect(safeErrorMessage(new Error("failed token=abc123 keychain://sterm/token password:secret"))).toBe(
      "failed token=<redacted> keychain://<redacted> password:<redacted>",
    );
  });

  test("uses renderer snapshots instead of frontend VT parsing", async () => {
    const state = await loadMockDesktopState();
    const renderState = createPaneRenderState(state.paneSnapshot);
    const [, dirtyRegions] = consumeDirtyRegions(renderState);
    expect(dirtyRegions).toHaveLength(state.paneSnapshot.rows);
    expect(buildCanvasCommands(renderState).length).toBeGreaterThan(0);
  });
});
