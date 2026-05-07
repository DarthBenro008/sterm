import { useCallback, useEffect, useMemo, useState, type CSSProperties, type FormEvent, type KeyboardEvent } from "react";
import { darkTheme, themeToCssVariables } from "@sterm/theme";
import { notificationTone } from "@sterm/ui";
import { createDesktopViewModel, nextPaneId, safeErrorMessage, type DesktopLoadState, type DesktopViewModel, type PaneViewModel } from "./appState";
import { connectRemoteWorkspace, validateConnectionInput, type ConnectionInput, type ConnectionResult } from "./connection";
import { loadMockDesktopState } from "./mockData";
import "./styles.css";

function WorkspaceSidebar({
  view,
  onOpenPalette,
  onSelectPane,
  onShowShortcuts,
}: {
  view: DesktopViewModel;
  onOpenPalette: () => void;
  onSelectPane: (paneId: string) => void;
  onShowShortcuts: () => void;
}) {
  return (
    <aside className="sidebar" aria-label="Workspaces and panes">
      <div className="brand" aria-label="sterm">sterm</div>
      <div className="surface-label">Remote workspace</div>
      <button className="workspace-card active" type="button" aria-current="true">
        <strong>{view.workspace.label}</strong>
        <span>{view.workspace.root}</span>
        <small>{view.workspace.remote}</small>
      </button>
      <div className="connection-note" role="status">{view.workspace.statusText}</div>

      <div className="sidebar-actions" aria-label="Primary actions">
        <button type="button" onClick={onOpenPalette} aria-keyshortcuts="Meta+K Control+K">Command palette</button>
        <button type="button" onClick={onShowShortcuts} aria-keyshortcuts="?">Shortcuts</button>
      </div>

      <div className="pane-nav" aria-label="Pane focus">
        <div className="surface-label">Panes</div>
        {view.panes.map((pane) => (
          <button
            className={`pane-nav-item ${pane.active ? "active" : ""}`}
            key={pane.id}
            type="button"
            onClick={() => onSelectPane(pane.id)}
            aria-current={pane.active ? "true" : undefined}
          >
            <span>{pane.title}</span>
            <small>{pane.command}</small>
          </button>
        ))}
      </div>
    </aside>
  );
}

function TabRail({ view }: { view: DesktopViewModel }) {
  return (
    <nav className="tab-rail" aria-label="Workspace tabs">
      <button className="tab active" type="button" aria-current="page">
        {view.workspace.activeTab.title}
        <span>{view.workspace.paneCount} panes</span>
      </button>
      <div className="tab-meta" role="status">
        {view.workspace.runningPaneCount} running · active pane {view.workspace.activePaneId}
      </div>
    </nav>
  );
}

function Toolbar({
  view,
  onOpenPalette,
  onShowShortcuts,
}: {
  view: DesktopViewModel;
  onOpenPalette: () => void;
  onShowShortcuts: () => void;
}) {
  return (
    <header className="toolbar" aria-label="Workspace toolbar">
      <div>
        <p className="eyebrow">Remote terminal workspace</p>
        <h1>{view.workspace.label}</h1>
      </div>
      <div className="toolbar-actions">
        <button type="button" disabled title="Connected through the bootstrap form">Connected</button>
        <button type="button" onClick={onOpenPalette} aria-keyshortcuts="Meta+K Control+K">Command palette</button>
        <button type="button" onClick={onShowShortcuts} aria-keyshortcuts="?">Help</button>
      </div>
    </header>
  );
}

function PaneCard({ pane, onSelect }: { pane: PaneViewModel; onSelect: (paneId: string) => void }) {
  const handleKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onSelect(pane.id);
    }
  };

  return (
    <article
      className={`pane-card ${pane.active ? "active" : ""} ${pane.snapshotAvailable ? "" : "pending"}`}
      role="listitem"
      tabIndex={0}
      aria-current={pane.active ? "true" : undefined}
      aria-label={pane.ariaLabel}
      onClick={() => onSelect(pane.id)}
      onFocus={() => onSelect(pane.id)}
      onKeyDown={handleKeyDown}
    >
      <header>
        <div>
          <span className="pane-title">{pane.title}</span>
          <small>{pane.cwd}</small>
        </div>
        <span className={`status-pill ${pane.statusTone}`}>{pane.status}</span>
      </header>
      <div className="pane-meta">
        <span>{pane.command}</span>
        <span>{pane.dimensions}</span>
        <span>seq {pane.renderState.seq}</span>
      </div>
      {pane.agentSummary ? <div className="agent-badge" role="status">{pane.agentSummary}</div> : null}
      <div className="terminal-canvas" role="img" aria-label={`${pane.title} server-rendered terminal snapshot`}>
        <pre>{pane.renderState.cells}</pre>
        {pane.renderState.cursor.visible ? (
          <span
            className="cursor"
            aria-hidden="true"
            style={{ gridRow: pane.renderState.cursor.row + 1, gridColumn: pane.renderState.cursor.col + 1 }}
          />
        ) : null}
        {!pane.snapshotAvailable ? <span className="snapshot-note">Snapshot pending</span> : null}
      </div>
      <footer>
        <span>{pane.dirtySummary}</span>
        <span>{pane.canvasCommands.length} canvas command(s)</span>
        <span>{pane.scrollbackSummary}</span>
      </footer>
    </article>
  );
}

function PaneGrid({
  view,
  onSelectPane,
}: {
  view: DesktopViewModel;
  onSelectPane: (paneId: string) => void;
}) {
  const handleGridKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    if (event.key !== "ArrowRight" && event.key !== "ArrowDown" && event.key !== "ArrowLeft" && event.key !== "ArrowUp") return;
    event.preventDefault();
    const direction = event.key === "ArrowRight" || event.key === "ArrowDown" ? 1 : -1;
    onSelectPane(nextPaneId(view.panes, view.workspace.activePaneId, direction));
  };

  return (
    <main className="pane-grid" role="list" aria-label="Split panes" onKeyDown={handleGridKeyDown}>
      {view.panes.map((pane) => (
        <PaneCard key={pane.id} pane={pane} onSelect={onSelectPane} />
      ))}
    </main>
  );
}

function SettingsPanel({ connection, view }: { connection: ConnectionResult; view: DesktopViewModel }) {
  return (
    <section className="settings-panel" aria-label="Runtime contract">
      <h2>Runtime contract</h2>
      <dl>
        <div><dt>Connection</dt><dd>{connection.username}@{connection.host}:{connection.port} · {connection.status}</dd></div>
        <div><dt>Remote agent</dt><dd>{connection.agentVersion} · socket {connection.socketPath}</dd></div>
        <div><dt>Transport</dt><dd>{view.transportSummary}</dd></div>
        <div><dt>Terminal truth</dt><dd>{view.rendererSummary}</dd></div>
        <div><dt>Agent detection</dt><dd>{view.agentDetectionSummary}</dd></div>
        <div><dt>Secrets</dt><dd>Keychain references only; no plaintext export path.</dd></div>
        <div><dt>Mutations</dt><dd>Enabled through the Rust backend bridge; frontend never owns terminal process state.</dd></div>
      </dl>
    </section>
  );
}

function BootstrapPanel({ connection }: { connection: ConnectionResult }) {
  return (
    <section className="settings-panel" aria-label="Connection bootstrap progress">
      <h2>Bootstrap</h2>
      <ol className="bootstrap-steps">
        {connection.steps.map((step) => (
          <li key={step.id} className={step.status}>
            <strong>{step.label}</strong>
            <span>{step.detail}</span>
          </li>
        ))}
      </ol>
    </section>
  );
}

function NotificationCenter({ view }: { view: DesktopViewModel }) {
  const tone = notificationTone(view.notificationSummary.startsWith("attention") ? "attention" : "info");
  return (
    <section className="notifications" aria-label="Notifications" aria-live="polite">
      <h2>Notifications</h2>
      <div className={`notice ${tone}`}>
        <strong>Agent attention</strong>
        <span>{view.notificationSummary}</span>
      </div>
    </section>
  );
}

function ShortcutsPanel({ view, onClose }: { view: DesktopViewModel; onClose: () => void }) {
  return (
    <section className="overlay-panel" role="dialog" aria-modal="true" aria-label="Keyboard shortcuts">
      <div className="overlay-card">
        <header>
          <h2>Keyboard shortcuts</h2>
          <button type="button" onClick={onClose} aria-label="Close shortcuts">Esc</button>
        </header>
        <ul className="shortcut-list">
          {view.shortcuts.map((shortcut) => (
            <li key={shortcut.id}>
              <kbd>{shortcut.keys}</kbd>
              <span>{shortcut.action}</span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

function CommandPalette({ view, onClose }: { view: DesktopViewModel; onClose: () => void }) {
  return (
    <section className="overlay-panel" role="dialog" aria-modal="true" aria-label="Command palette">
      <div className="overlay-card command-palette">
        <header>
          <h2>Command palette</h2>
          <button type="button" onClick={onClose} aria-label="Close command palette">Esc</button>
        </header>
        <label className="palette-search">
          <span className="sr-only">Filter commands</span>
          <input autoFocus placeholder="Search commands…" readOnly aria-describedby="palette-preview-note" />
        </label>
        <p id="palette-preview-note" className="muted">Preview-only actions are disabled until the live bridge exists.</p>
        <ul className="palette-list">
          {view.commandPaletteActions.map((action) => (
            <li key={action.id}>
              <button type="button" disabled={Boolean(action.disabledReason)} title={action.disabledReason}>
                <span>{action.label}</span>
                {action.shortcut ? <kbd>{action.shortcut}</kbd> : null}
              </button>
              <small>{action.description}</small>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

function LoadingScreen({ style }: { style: CSSProperties }) {
  return (
    <div className="app-state-screen" style={style} role="status" aria-live="polite" aria-busy="true">
      <div className="spinner" aria-hidden="true" />
      <h1>Loading sterm workspace…</h1>
      <p>Preparing fixture-backed protocol state and renderer snapshots.</p>
    </div>
  );
}

function ErrorScreen({ message, onRetry, style }: { message: string; onRetry: () => void; style: CSSProperties }) {
  return (
    <div className="app-state-screen error-state" style={style} role="alert" aria-live="assertive">
      <h1>Workspace preview failed</h1>
      <p>{message}</p>
      <button type="button" onClick={onRetry}>Retry preview load</button>
    </div>
  );
}

function ConnectingScreen({ host, style }: { host: string; style: CSSProperties }) {
  return (
    <div className="app-state-screen" style={style} role="status" aria-live="polite" aria-busy="true">
      <div className="spinner" aria-hidden="true" />
      <h1>Connecting to {host}…</h1>
      <p>Authenticating over SSH, building the matching Zig agent, uploading it, and starting the remote daemon.</p>
    </div>
  );
}

function ConnectionScreen({
  error,
  input,
  onChange,
  onSubmit,
  style,
}: {
  error: string | null;
  input: ConnectionInput;
  onChange: (next: ConnectionInput) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  style: CSSProperties;
}) {
  return (
    <main className="connect-screen" style={style}>
      <section className="connect-card" aria-labelledby="connect-title">
        <div className="brand" aria-label="sterm">sterm</div>
        <p className="eyebrow">Remote-first terminal workspace</p>
        <h1 id="connect-title">Connect to your server</h1>
        <p className="connect-copy">
          Enter the VM details. sterm will connect over SSH, install or update the Zig <code>sterm-cli</code> agent,
          start the remote daemon, and attach the terminal workspace.
        </p>

        <form className="connect-form" onSubmit={onSubmit}>
          <label>
            <span>Server IP address</span>
            <input
              autoFocus
              autoComplete="hostname"
              inputMode="url"
              name="host"
              placeholder="203.0.113.10"
              value={input.host}
              onChange={(event) => onChange({ ...input, host: event.target.value })}
            />
          </label>
          <label>
            <span>Username</span>
            <input
              autoComplete="username"
              name="username"
              placeholder="ubuntu"
              value={input.username}
              onChange={(event) => onChange({ ...input, username: event.target.value })}
            />
          </label>
          <label>
            <span>Password</span>
            <input
              autoComplete="current-password"
              name="password"
              placeholder="SSH password"
              type="password"
              value={input.password}
              onChange={(event) => onChange({ ...input, password: event.target.value })}
            />
          </label>
          {error ? <p className="connect-error" role="alert">{error}</p> : null}
          <button className="connect-submit" type="submit">Connect and start terminal</button>
        </form>
      </section>
    </main>
  );
}

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tagName = target.tagName.toLowerCase();
  return target.isContentEditable || tagName === "input" || tagName === "textarea" || tagName === "select";
}

export function App() {
  const [loadState, setLoadState] = useState<DesktopLoadState>({ status: "loading" });
  const [connection, setConnection] = useState<ConnectionResult | null>(null);
  const [connectionInput, setConnectionInput] = useState<ConnectionInput>({ host: "", username: "", password: "", port: 22 });
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [connecting, setConnecting] = useState(false);
  const [reloadNonce, setReloadNonce] = useState(0);
  const [activePaneId, setActivePaneId] = useState<string | undefined>();
  const [shortcutsOpen, setShortcutsOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const cssVariables = themeToCssVariables(darkTheme) as CSSProperties;

  useEffect(() => {
    if (!connection) return;
    let cancelled = false;
    setLoadState({ status: "loading" });
    void loadMockDesktopState()
      .then((data) => {
        if (!cancelled) setLoadState({ status: "ready", data });
      })
      .catch((reason: unknown) => {
        if (!cancelled) setLoadState({ status: "error", message: safeErrorMessage(reason), retryable: true });
      });
    return () => {
      cancelled = true;
    };
  }, [connection, reloadNonce]);

  const view = useMemo(() => {
    if (loadState.status !== "ready" || !connection) return null;
    const base = createDesktopViewModel(loadState.data, activePaneId);
    return {
      ...base,
      workspace: {
        ...base.workspace,
        label: `${connection.host} terminal`,
        remote: `${connection.username}@${connection.host}`,
        statusText: `${connection.status === "connected" ? "Connected" : "Preview"} · agent ${connection.agentVersion} · ${connection.socketPath}`,
      },
    };
  }, [activePaneId, connection, loadState]);

  const openPalette = useCallback(() => setPaletteOpen(true), []);
  const showShortcuts = useCallback(() => setShortcutsOpen(true), []);
  const closeOverlays = useCallback(() => {
    setPaletteOpen(false);
    setShortcutsOpen(false);
  }, []);

  useEffect(() => {
    const handleGlobalKeyDown = (event: globalThis.KeyboardEvent) => {
      if (isEditableTarget(event.target)) return;
      const key = event.key.toLowerCase();
      if ((event.metaKey || event.ctrlKey) && key === "k") {
        event.preventDefault();
        setPaletteOpen(true);
      } else if (event.key === "?") {
        event.preventDefault();
        setShortcutsOpen((open) => !open);
      } else if (event.key === "Escape") {
        closeOverlays();
      }
    };

    window.addEventListener("keydown", handleGlobalKeyDown);
    return () => window.removeEventListener("keydown", handleGlobalKeyDown);
  }, [closeOverlays]);

  const handleConnect = useCallback(async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const validationError = validateConnectionInput(connectionInput);
    if (validationError) {
      setConnectionError(validationError);
      return;
    }

    setConnecting(true);
    setConnectionError(null);
    try {
      const result = await connectRemoteWorkspace(connectionInput);
      setConnection(result);
      setConnectionInput((current) => ({ ...current, password: "" }));
      setReloadNonce((nonce) => nonce + 1);
    } catch (reason: unknown) {
      setConnectionError(safeErrorMessage(reason));
    } finally {
      setConnecting(false);
    }
  }, [connectionInput]);

  if (!connection) {
    if (connecting) {
      return <ConnectingScreen host={connectionInput.host || "server"} style={cssVariables} />;
    }
    return (
      <ConnectionScreen
        error={connectionError}
        input={connectionInput}
        onChange={setConnectionInput}
        onSubmit={handleConnect}
        style={cssVariables}
      />
    );
  }

  if (loadState.status === "loading") {
    return <LoadingScreen style={cssVariables} />;
  }

  if (loadState.status === "error") {
    return <ErrorScreen message={loadState.message} onRetry={() => setReloadNonce((nonce) => nonce + 1)} style={cssVariables} />;
  }

  if (!view) {
    return <ErrorScreen message="The desktop view model was unavailable after loading." onRetry={() => setReloadNonce((nonce) => nonce + 1)} style={cssVariables} />;
  }

  return (
    <div className="app-shell" style={cssVariables}>
      <WorkspaceSidebar view={view} onOpenPalette={openPalette} onSelectPane={setActivePaneId} onShowShortcuts={showShortcuts} />
      <section className="workspace-shell" aria-label="Workspace surface">
        <Toolbar view={view} onOpenPalette={openPalette} onShowShortcuts={showShortcuts} />
        <TabRail view={view} />
        <PaneGrid view={view} onSelectPane={setActivePaneId} />
      </section>
      <aside className="right-rail" aria-label="Status and settings">
        <SettingsPanel connection={connection} view={view} />
        <BootstrapPanel connection={connection} />
        <NotificationCenter view={view} />
      </aside>
      {shortcutsOpen ? <ShortcutsPanel view={view} onClose={closeOverlays} /> : null}
      {paletteOpen ? <CommandPalette view={view} onClose={closeOverlays} /> : null}
    </div>
  );
}
