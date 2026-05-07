import { useCallback, useEffect, useMemo, useState, type CSSProperties, type KeyboardEvent } from "react";
import { darkTheme, themeToCssVariables } from "@sterm/theme";
import { notificationTone } from "@sterm/ui";
import { createDesktopViewModel, nextPaneId, safeErrorMessage, type DesktopLoadState, type DesktopViewModel, type PaneViewModel } from "./appState";
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
        <p className="eyebrow">Production shell preview</p>
        <h1>{view.workspace.label}</h1>
      </div>
      <div className="toolbar-actions">
        <button type="button" disabled title="Requires live SSH bridge">Connect VM</button>
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

function SettingsPanel({ view }: { view: DesktopViewModel }) {
  return (
    <section className="settings-panel" aria-label="Runtime contract">
      <h2>Runtime contract</h2>
      <dl>
        <div><dt>Transport</dt><dd>{view.transportSummary}</dd></div>
        <div><dt>Terminal truth</dt><dd>{view.rendererSummary}</dd></div>
        <div><dt>Secrets</dt><dd>Keychain references only; no plaintext export path.</dd></div>
        <div><dt>Mutations</dt><dd>Disabled until the persistent Tauri bridge is connected.</dd></div>
      </dl>
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

function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tagName = target.tagName.toLowerCase();
  return target.isContentEditable || tagName === "input" || tagName === "textarea" || tagName === "select";
}

export function App() {
  const [loadState, setLoadState] = useState<DesktopLoadState>({ status: "loading" });
  const [reloadNonce, setReloadNonce] = useState(0);
  const [activePaneId, setActivePaneId] = useState<string | undefined>();
  const [shortcutsOpen, setShortcutsOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const cssVariables = themeToCssVariables(darkTheme) as CSSProperties;

  useEffect(() => {
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
  }, [reloadNonce]);

  const view = useMemo(() => loadState.status === "ready" ? createDesktopViewModel(loadState.data, activePaneId) : null, [activePaneId, loadState]);

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
        <SettingsPanel view={view} />
        <NotificationCenter view={view} />
      </aside>
      {shortcutsOpen ? <ShortcutsPanel view={view} onClose={closeOverlays} /> : null}
      {paletteOpen ? <CommandPalette view={view} onClose={closeOverlays} /> : null}
    </div>
  );
}
