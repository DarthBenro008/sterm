import { loadFixtureFrame, type AgentDetectionFrame, type NotificationFrame, type PaneDiffFrame, type PaneSnapshotFrame, type WorkspaceSnapshotFrame } from "@sterm/protocol-client";

export interface MockDesktopState {
  workspace: WorkspaceSnapshotFrame;
  paneSnapshot: PaneSnapshotFrame;
  paneDiff: PaneDiffFrame;
  notification: NotificationFrame;
  agentDetection: AgentDetectionFrame;
}

export async function loadMockDesktopState(): Promise<MockDesktopState> {
  const [workspace, paneSnapshot, paneDiff, notification, agentDetection] = await Promise.all([
    loadFixtureFrame("workspace_snapshot"),
    loadFixtureFrame("pane_snapshot"),
    loadFixtureFrame("pane_diff"),
    loadFixtureFrame("notification"),
    loadFixtureFrame("agent_detection"),
  ]);

  if (
    workspace.type !== "workspace_snapshot" ||
    paneSnapshot.type !== "pane_snapshot" ||
    paneDiff.type !== "pane_diff" ||
    notification.type !== "notification" ||
    agentDetection.type !== "agent_detection"
  ) {
    throw new Error("Mock desktop fixtures did not match expected frame types");
  }

  return { workspace, paneSnapshot, paneDiff, notification, agentDetection };
}
