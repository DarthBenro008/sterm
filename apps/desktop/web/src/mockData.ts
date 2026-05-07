import { parseProtocolFrame, type AgentDetectionFrame, type NotificationFrame, type PaneDiffFrame, type PaneSnapshotFrame, type WorkspaceSnapshotFrame } from "@sterm/protocol-client";
import agentDetectionFixture from "../../../../fixtures/protocol/agent_detection.json";
import notificationFixture from "../../../../fixtures/protocol/notification.json";
import paneDiffFixture from "../../../../fixtures/protocol/pane_diff.json";
import paneSnapshotFixture from "../../../../fixtures/protocol/pane_snapshot.json";
import workspaceSnapshotFixture from "../../../../fixtures/protocol/workspace_snapshot.json";

export interface MockDesktopState {
  workspace: WorkspaceSnapshotFrame;
  paneSnapshot: PaneSnapshotFrame;
  paneDiff: PaneDiffFrame;
  notification: NotificationFrame;
  agentDetection: AgentDetectionFrame;
}

export async function loadMockDesktopState(): Promise<MockDesktopState> {
  const workspace = parseProtocolFrame(workspaceSnapshotFixture);
  const paneSnapshot = parseProtocolFrame(paneSnapshotFixture);
  const paneDiff = parseProtocolFrame(paneDiffFixture);
  const notification = parseProtocolFrame(notificationFixture);
  const agentDetection = parseProtocolFrame(agentDetectionFixture);

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
