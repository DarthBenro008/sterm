import { useEffect, useMemo, useState } from "react";
import { applyPaneRenderDiff, buildCanvasCommands, consumeDirtyRegions, createPaneRenderState, type PaneRenderState } from "@sterm/renderer";
import { darkTheme, themeToCssVariables } from "@sterm/theme";
import { notificationTone } from "@sterm/ui";
import type { MockDesktopState } from "./mockData";
import { loadMockDesktopState } from "./mockData";
import "./styles.css";

function WorkspaceSidebar({ data }: { data: MockDesktopState }) {
  return (
    <aside className="sidebar" aria-label="Workspaces">
      <div className="brand">sterm</div>
      <div className="surface-label">Remote workspace</div>
      <button className="workspace-card active" type="button">
        <strong>{data.workspace.workspace.name}</strong>
        <span>{data.workspace.workspace.root_dir}</span>
      </button>
      <div className="connection-note">Mock fixture transport · no local PTY ownership</div>
    </aside>
  );
}

function TabRail({ data }: { data: MockDesktopState }) {
  return (
    <nav className="tab-rail" aria-label="Workspace tabs">
      {data.workspace.tabs.map((tab) => (
        <button className="tab active" key={tab.id} type="button">
          {tab.title}
        </button>
      ))}
    </nav>
  );
}

function PaneCard({ state, title }: { state: PaneRenderState; title: string }) {
  const commands = buildCanvasCommands(state);
  return (
    <section className="pane-card" aria-label={`${title} terminal pane`}>
      <header>
        <span>{title}</span>
        <small>{state.rows}×{state.cols} · seq {state.seq}</small>
      </header>
      <div className="terminal-canvas-mock" role="img" aria-label="Canvas renderer mock surface">
        <pre>{state.cells}</pre>
        <span className="cursor" style={{ gridRow: state.cursor.row + 1, gridColumn: state.cursor.col + 1 }} />
      </div>
      <footer>{commands.length} canvas command(s) scheduled from dirty regions</footer>
    </section>
  );
}

function PaneGrid({ data }: { data: MockDesktopState }) {
  const renderState = useMemo(() => {
    const fromSnapshot = createPaneRenderState(data.paneSnapshot);
    const clean = consumeDirtyRegions(fromSnapshot)[0];
    return applyPaneRenderDiff(clean, data.paneDiff);
  }, [data]);

  return (
    <main className="pane-grid" aria-label="Split panes">
      {data.workspace.panes.map((pane) => (
        <PaneCard key={pane.id} state={pane.id === renderState.paneId ? renderState : { ...renderState, paneId: pane.id }} title={pane.title} />
      ))}
    </main>
  );
}

function SettingsPanel() {
  return (
    <section className="settings-panel" aria-label="Settings">
      <h2>Settings</h2>
      <dl>
        <div><dt>Transport</dt><dd>SSH tunnel bridge (mocked in web shell)</dd></div>
        <div><dt>Terminal truth</dt><dd>Remote sterm-cli snapshots and diffs</dd></div>
        <div><dt>VT parsing</dt><dd>Not implemented in frontend</dd></div>
      </dl>
    </section>
  );
}

function NotificationCenter({ data }: { data: MockDesktopState }) {
  return (
    <section className="notifications" aria-label="Notifications">
      <h2>Notifications</h2>
      <div className={`notice ${notificationTone(data.notification.level)}`}>
        <strong>{data.notification.level}</strong>
        <span>{data.notification.reason}</span>
      </div>
    </section>
  );
}

export function App() {
  const [state, setState] = useState<MockDesktopState | null>(null);
  const cssVariables = themeToCssVariables(darkTheme) as React.CSSProperties;

  useEffect(() => {
    void loadMockDesktopState().then(setState);
  }, []);

  if (!state) {
    return <div className="loading" style={cssVariables}>Loading mock sterm workspace…</div>;
  }

  return (
    <div className="app-shell" style={cssVariables}>
      <WorkspaceSidebar data={state} />
      <section className="workspace-shell">
        <TabRail data={state} />
        <PaneGrid data={state} />
      </section>
      <aside className="right-rail">
        <SettingsPanel />
        <NotificationCenter data={state} />
      </aside>
    </div>
  );
}
