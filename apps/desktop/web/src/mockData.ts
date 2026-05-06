import { loadFixtureFrame, type NotificationFrame, type PaneDiffFrame, type PaneSnapshotFrame, type WorkspaceSnapshotFrame } from "@sterm/protocol-client";

export interface MockDesktopState {
  workspace: WorkspaceSnapshotFrame;
  paneSnapshot: PaneSnapshotFrame;
  paneDiff: PaneDiffFrame;
  notification: NotificationFrame;
}

export async function loadMockDesktopState(): Promise<MockDesktopState> {
  const [workspace, paneSnapshot, paneDiff, notification] = await Promise.all([
    loadFixtureFrame("workspace_snapshot"),
    loadFixtureFrame("pane_snapshot"),
    loadFixtureFrame("pane_diff"),
    loadFixtureFrame("notification"),
  ]);

  if (workspace.type !== "workspace_snapshot" || paneSnapshot.type !== "pane_snapshot" || paneDiff.type !== "pane_diff" || notification.type !== "notification") {
    throw new Error("Mock desktop fixtures did not match expected frame types");
  }

  return { workspace, paneSnapshot, paneDiff, notification };
}
