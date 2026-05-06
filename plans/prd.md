# sterm PRD

**Document Type:** Product Requirements Document  
**Project Name:** sterm  
**Remote Agent Binary:** `sterm-cli`  
**Desktop Stack:** Tauri, Rust, Vite, React, TypeScript  
**Remote Agent Stack:** Zig, `libghostty-vt`, SQLite  
**Primary Use Case:** Persistent remote terminal workspaces for AI-agent-heavy server workflows  
**Status:** Draft  

---

## 1. Product Summary

**sterm** is a production-grade remote terminal workspace for developers running long-lived processes, AI agents, coding agents, build systems, and server workflows on remote VMs.

sterm consists of:

- A **macOS desktop app** built with **Tauri**
- A **Rust backend** inside the Tauri app
- A **Vite + React frontend**
- A remote Zig-based server component called **`sterm-cli`**
- Server-side terminal emulation using **`libghostty-vt`**
- SSH-based secure bootstrap, transport, and tunneling
- Persistent remote workspaces, tabs, panes, scrollback, notifications, and reconnectable sessions

The core idea:

> The desktop app is not the owner of terminal processes.  
> The remote VM is the owner of terminal processes.  
> `sterm-cli` owns PTYs, terminal state, scrollback, layouts, and process lifecycle.  
> The Tauri app is a rich client that reconnects to that remote state.

This allows a user to close their Mac, lose network, restart the client, or switch machines while their remote AI agents and shell processes continue running on the VM.

---

## 2. Goals

### 2.1 Primary Goals

- Provide a production-ready advanced SSH terminal client for remote VM workflows.
- Support persistent remote terminal workspaces.
- Support multiple workspaces per VM.
- Support multiple tabs per workspace.
- Support horizontal and vertical split panes.
- Preserve running processes when the local macOS client disconnects.
- Restore full workspace layout and terminal state on reconnect.
- Use `libghostty-vt` server-side for terminal emulation state, scrollback, wrapping, reflow, and render-state generation.
- Use a custom frontend render loop in the Tauri web frontend.
- Optimize for AI-agent-heavy workflows:
  - Claude Code
  - OpenAI Codex-style agents
  - Cursor/CLI agents
  - aider
  - custom shell-based agents
- Provide notifications when a pane or agent needs attention.
- Provide a scriptable CLI/socket API for automation.
- Store SSH credentials securely.
- Use a monorepo architecture.

### 2.2 Non-Goals

- No embedded browser component.
- No local-only terminal mode as the primary use case.
- No reliance on tmux as the core persistence layer.
- No Electron.
- No web-hosted SaaS requirement for core terminal functionality.
- No publicly exposed remote daemon port by default.
- No assumption that the remote process lifetime is tied to the SSH connection.

---

## 3. Product Positioning

### 3.1 What is sterm?

sterm is a **remote-first terminal workspace**.

It behaves like a modern terminal app on macOS, but its sessions live on the server.

A user can:

1. Add a VM.
2. Connect over SSH.
3. Install or update `sterm-cli` automatically.
4. Create a remote workspace.
5. Open panes and tabs.
6. Run AI agents, shells, dev servers, tests, logs, and background processes.
7. Disconnect their Mac.
8. Reconnect later and restore the same workspace exactly.

### 3.2 Core Product Promise

> Your remote terminal workspace keeps running even when your laptop does not.

### 3.3 Target Users

- Developers using cloud VMs for daily work.
- Developers running AI coding agents on powerful remote machines.
- Teams using GPU VMs or high-memory servers.
- Engineers running long-lived dev/test/build processes.
- Power users who currently combine SSH, tmux, iTerm, VS Code Remote, and shell scripts.
- Developers who want a better multi-agent terminal UI.

---

## 4. High-Level Architecture

```text
sterm monorepo
  ├─ apps/desktop
  │   ├─ Tauri app
  │   ├─ Rust backend
  │   └─ Vite + React frontend
  │
  ├─ crates/
  │   ├─ sterm-ssh
  │   ├─ sterm-protocol
  │   ├─ sterm-keychain
  │   ├─ sterm-tunnel
  │   └─ sterm-shared
  │
  ├─ cli/sterm-cli
  │   ├─ Zig remote agent
  │   ├─ PTY manager
  │   ├─ libghostty-vt integration
  │   ├─ workspace manager
  │   ├─ socket API
  │   ├─ SQLite state store
  │   └─ notification/event engine
  │
  ├─ packages/
  │   ├─ renderer
  │   ├─ protocol-client
  │   ├─ ui
  │   └─ theme
  │
  ├─ proto/
  │   └─ sterm protocol definitions
  │
  ├─ docs/
  └─ scripts/
```

---

## 5. System Components

## 5.1 Desktop App

### Name

`sterm`

### Technology

- Tauri
- Rust backend
- Vite
- React
- TypeScript
- Custom terminal renderer
- macOS Keychain integration
- SSH transport and tunnel management

### Responsibilities

The desktop app is responsible for:

- Managing local VM profiles.
- Managing SSH connection setup.
- Bootstrapping `sterm-cli` on the VM.
- Opening secure tunnels to `sterm-cli`.
- Rendering terminal panes.
- Managing local UI state.
- Sending input events to the remote agent.
- Receiving terminal render diffs from the remote agent.
- Handling local clipboard and file paste.
- Displaying workspace, tab, pane, process, and agent notifications.
- Providing command palette and keyboard shortcuts.
- Supporting scriptable local commands.

The desktop app should **not** own the actual shell process lifecycle.

---

## 5.2 Tauri Rust Backend

### Responsibilities

The Tauri Rust backend owns all local native functionality:

- SSH connection lifecycle.
- SSH authentication.
- SSH key discovery.
- SSH agent integration.
- macOS Keychain access.
- Agent bootstrap and update.
- SSH tunnel creation.
- Local socket connections to the tunnel.
- Local file upload.
- Clipboard access.
- Secure local config storage.
- Protocol bridge between frontend and `sterm-cli`.

### Important Design Rule

Avoid sending every keypress through slow Tauri command invocation.

Instead, maintain a persistent low-latency channel:

```text
React frontend
  ↓ persistent IPC/event channel
Tauri Rust backend
  ↓ SSH tunnel
sterm-cli
  ↓ PTY
remote shell/process
```

---

## 5.3 Frontend

### Technology

- Vite
- React
- TypeScript
- Canvas 2D initially
- Potential future WebGPU renderer
- Zustand/Jotai/Redux-style local UI state
- Custom terminal render loop

### Responsibilities

- Workspace sidebar.
- Vertical tabs.
- Split pane layout.
- Terminal pane rendering.
- Pane focus management.
- Keyboard shortcut handling.
- Selection/copy UI.
- Search UI.
- Scrollback UI.
- Notification rings.
- Agent status badges.
- Command palette.
- Settings UI.
- VM manager UI.
- Connection state UI.

### Frontend Should Not

- Parse VT escape sequences.
- Own remote terminal truth.
- Own remote process state.
- Replay raw terminal output as the source of truth.

---

## 5.4 `sterm-cli`

### Name

`sterm-cli`

### Language

Zig.

### Why Zig?

`sterm-cli` should be written in Zig because:

- `libghostty-vt` is Zig-first and exposes Zig/C APIs.
- The agent needs low-level PTY and file descriptor control.
- The agent should compile to a single deployable binary.
- The agent must be easy to upload over SSH.
- Zig is appropriate for long-running systems code with explicit memory control.
- Zig reduces FFI friction with `libghostty-vt`.

### Responsibilities

`sterm-cli` is the remote source of truth.

It owns:

- Workspaces.
- Tabs.
- Split layouts.
- Panes.
- PTYs.
- Child process lifecycle.
- Terminal state.
- Scrollback.
- Render diffs.
- Agent notifications.
- Remote socket API.
- Persistence.
- Reconnect behavior.
- Local VM-side automation.

### `sterm-cli` Modes

```text
sterm-cli daemon
sterm-cli status
sterm-cli version
sterm-cli doctor
sterm-cli workspace list
sterm-cli workspace create
sterm-cli pane create
sterm-cli pane write
sterm-cli pane resize
sterm-cli logs
```

### Daemon Mode

The primary mode is:

```bash
sterm-cli daemon
```

This starts a user-owned daemon listening on a Unix socket:

```text
~/.sterm/sterm.sock
```

The daemon should not listen on public TCP by default.

---

# 6. First Connect Flow

## 6.1 User Adds a VM

User provides:

- Hostname or IP.
- SSH port.
- Username.
- Authentication method.
- Optional SSH config alias.
- Optional identity file.
- Optional remote install path.
- Optional default workspace directory.

Example profile:

```json
{
  "id": "vm_prod_1",
  "name": "AI GPU VM",
  "host": "gpu-1.example.com",
  "port": 22,
  "user": "ubuntu",
  "auth": {
    "method": "ssh-agent",
    "identity_file": "~/.ssh/id_ed25519"
  },
  "remote": {
    "install_dir": "~/.sterm",
    "socket_path": "~/.sterm/sterm.sock"
  }
}
```

---

## 6.2 SSH Bootstrap

On first connect:

```text
1. User clicks Connect.
2. Tauri Rust backend resolves VM profile.
3. Rust backend checks local SSH config.
4. Rust backend authenticates using SSH agent, key file, or password.
5. Rust backend opens a bootstrap SSH session.
6. Rust backend detects remote OS and architecture.
7. Rust backend checks whether ~/.sterm/bin/sterm-cli exists.
8. Rust backend checks remote sterm-cli version and protocol version.
9. If missing or outdated, Rust backend uploads the correct binary.
10. Rust backend verifies checksum/signature.
11. Rust backend starts or restarts sterm-cli daemon.
12. Rust backend opens an SSH tunnel to ~/.sterm/sterm.sock.
13. Desktop app begins speaking the sterm protocol.
```

Binary path:

```text
~/.sterm/bin/sterm-cli
```

Socket path:

```text
~/.sterm/sterm.sock
```

State path:

```text
~/.sterm/state/sterm.db
```

Logs path:

```text
~/.sterm/logs/sterm-cli.log
```

---

## 6.3 First Install

The desktop app uploads a platform-specific binary:

```text
sterm-cli-linux-x86_64
sterm-cli-linux-aarch64
```

Install commands:

```bash
mkdir -p ~/.sterm/bin ~/.sterm/state ~/.sterm/logs
chmod 700 ~/.sterm
install -m 755 /tmp/sterm-cli ~/.sterm/bin/sterm-cli
~/.sterm/bin/sterm-cli version
```

The app should verify:

- Binary checksum.
- Expected version.
- Expected protocol version.
- Executable permission.
- Socket directory permission.
- State directory permission.

---

## 6.4 Starting `sterm-cli`

Preferred start method:

```bash
~/.sterm/bin/sterm-cli daemon --socket ~/.sterm/sterm.sock
```

Production should support both on-demand mode and user service mode.

### On-Demand Mode

The client starts `sterm-cli` when connecting.

Pros:

- Simple.
- No systemd requirement.
- Works on more servers.

Cons:

- Agent may stop if process supervisor is not configured.
- Less robust after VM logout or daemon crash.

### User Service Mode

Install a user-level systemd service when available:

```text
~/.config/systemd/user/sterm-cli.service
```

Example:

```ini
[Unit]
Description=sterm remote terminal agent

[Service]
ExecStart=%h/.sterm/bin/sterm-cli daemon --socket %h/.sterm/sterm.sock
Restart=always
RestartSec=2
Environment=STERM_HOME=%h/.sterm

[Install]
WantedBy=default.target
```

The app should support:

```bash
systemctl --user enable sterm-cli
systemctl --user start sterm-cli
```

Important:

- Do not automatically run `loginctl enable-linger` without explicit user approval.
- If lingering is needed, explain the impact.
- On shared or managed servers, default to on-demand mode.

---

# 7. SSH Authentication and Key Storage

## 7.1 Authentication Methods

sterm should support:

- SSH agent.
- macOS Keychain-backed keys.
- Identity file from `~/.ssh/config`.
- Explicit private key path.
- Password authentication.
- Passphrase-protected private keys.
- Keyboard-interactive authentication.
- Host key verification.
- Bastion/jump hosts via SSH config.
- ProxyCommand / ProxyJump where feasible.

## 7.2 Key Storage Principles

sterm should avoid storing private keys directly unless the user explicitly imports one.

Preferred model:

```text
Use existing SSH keys from ~/.ssh
Use ssh-agent when available
Store passphrases in macOS Keychain only with user approval
Store VM profile metadata locally
Never store raw private key material in app config by default
```

## 7.3 macOS Keychain

Store in Keychain:

- SSH passphrases, if user opts in.
- Password auth passwords, if user opts in.
- Per-VM auth tokens for `sterm-cli`.
- Local app encryption keys.
- Optional imported private keys.

Do not store in plaintext:

- SSH passwords.
- SSH private keys.
- Agent auth tokens.
- Remote session tokens.

## 7.4 Local Config Storage

Non-secret config can be stored in:

```text
~/Library/Application Support/sterm/config.json
```

Example:

```json
{
  "vms": [
    {
      "id": "vm_123",
      "name": "AI GPU VM",
      "host": "gpu-1.example.com",
      "port": 22,
      "user": "ubuntu",
      "auth_strategy": "ssh-agent",
      "identity_file": "~/.ssh/id_ed25519",
      "remote_install_dir": "~/.sterm"
    }
  ]
}
```

## 7.5 Host Key Verification

sterm must verify host keys.

Supported behavior:

- Use `~/.ssh/known_hosts`.
- Warn on unknown host.
- Block on changed host key unless explicitly approved.
- Show fingerprint.
- Allow enterprise-managed known host policy later.

Do not silently accept changed host keys.

---

# 8. SSH Connection Architecture

## 8.1 SSH Roles

SSH is used for:

- Authentication.
- First install.
- Updating `sterm-cli`.
- Starting `sterm-cli`.
- Creating a secure tunnel to the remote Unix socket.
- SFTP/file upload.
- Optional port forwarding for internal sterm needs.

SSH is **not** used as the owner of long-lived terminal sessions.

## 8.2 Connection Model

```text
Tauri app
  ↓ SSH
Remote VM
  ↓ local Unix socket
sterm-cli daemon
  ↓ PTYs
shells / AI agents / processes
```

## 8.3 Tunnel Model

Use SSH local forwarding:

```text
macOS localhost:random_port
  ↓ SSH tunnel
remote ~/.sterm/sterm.sock
  ↓
sterm-cli
```

The frontend connects to the Rust backend, not directly to the remote socket.

Recommended internal path:

```text
React frontend
  ↓ local app protocol
Tauri Rust backend
  ↓ local TCP or in-process channel
SSH tunnel
  ↓
sterm-cli Unix socket
```

## 8.4 Reconnect Model

When the connection drops:

```text
Mac app disconnects
SSH tunnel closes
sterm-cli continues running
PTYs continue running
libghostty-vt continues consuming output
workspace state remains persisted
```

When reconnecting:

```text
1. Re-open SSH.
2. Check sterm-cli status.
3. Restart if needed.
4. Open tunnel.
5. Authenticate to sterm-cli.
6. Fetch workspace snapshot.
7. Rebuild UI layout.
8. Subscribe to pane render streams.
9. Resume input and output.
```

---

# 9. Should sterm Support Mosh?

## 9.1 Recommendation

Support Mosh later as an optional transport mode, but do not make it the primary architecture.

Primary production transport should be:

```text
SSH + SSH tunnel + sterm protocol
```

Mosh solves intermittent network and roaming problems for interactive terminal sessions, but sterm already separates process lifetime from the SSH connection. sterm’s main persistence comes from `sterm-cli`, not from Mosh.

## 9.2 Why Mosh Is Not Core

Mosh is useful for:

- Roaming networks.
- High latency.
- Temporary packet loss.
- Better interactive feel over bad links.

But sterm needs:

- Agent bootstrap.
- Secure installation.
- Unix socket tunneling.
- Structured workspace protocol.
- Render diff transport.
- File upload.
- Authentication lifecycle.
- Remote daemon management.

SSH remains the simpler and more universal control plane.

## 9.3 Future Mosh-Like Mode

Instead of integrating Mosh directly, sterm can later implement a Mosh-inspired transport:

```text
control plane: SSH
streaming plane: UDP encrypted transport
state sync: sterm-cli authoritative terminal state
```

This would allow:

- Local echo prediction.
- Loss-tolerant pane output.
- Session roaming.
- Better poor-network behavior.

But this should not replace SSH bootstrap.

## 9.4 Product Decision

Production v1 should include:

- SSH only.
- Robust reconnect.
- Fast resume.
- Backpressure.
- Render diff batching.

Future:

- Optional Mosh-compatible or Mosh-inspired transport.
- Per-VM setting: “Use experimental roaming transport.”

---

# 10. Workspace Model

## 10.1 Concepts

```text
VM
  └─ Workspace
      └─ Tab
          └─ Split Tree
              └─ Pane
                  └─ PTY
                      └─ Process
```

## 10.2 Workspace

A workspace is a persistent remote working environment.

Fields:

```json
{
  "id": "ws_01",
  "name": "agent-runner",
  "root_dir": "/home/ubuntu/projects/app",
  "created_at": "2026-05-07T12:00:00Z",
  "updated_at": "2026-05-07T12:30:00Z",
  "active_tab_id": "tab_01",
  "metadata": {
    "git_branch": "main",
    "git_repo": "git@github.com:org/app.git"
  }
}
```

## 10.3 Tab

A tab contains a split tree.

```json
{
  "id": "tab_01",
  "title": "Agents",
  "active_pane_id": "pane_01",
  "split_tree": {}
}
```

## 10.4 Split Tree

Example:

```json
{
  "type": "split",
  "direction": "horizontal",
  "ratio": 0.5,
  "children": [
    {
      "type": "pane",
      "pane_id": "pane_01"
    },
    {
      "type": "split",
      "direction": "vertical",
      "ratio": 0.6,
      "children": [
        {
          "type": "pane",
          "pane_id": "pane_02"
        },
        {
          "type": "pane",
          "pane_id": "pane_03"
        }
      ]
    }
  ]
}
```

## 10.5 Pane

Each pane maps to a remote PTY and terminal state.

```json
{
  "id": "pane_01",
  "workspace_id": "ws_01",
  "tab_id": "tab_01",
  "title": "Claude Agent",
  "cwd": "/home/ubuntu/projects/app",
  "shell": "/bin/bash",
  "command": "claude",
  "rows": 40,
  "cols": 120,
  "status": "running",
  "pty_id": "pty_01",
  "vt_id": "vt_01",
  "created_at": "2026-05-07T12:00:00Z",
  "last_activity_at": "2026-05-07T12:30:00Z"
}
```

---

# 11. PTY and Process Lifecycle

## 11.1 PTY Ownership

`sterm-cli` owns PTYs.

The desktop app never directly owns remote PTYs.

For each pane:

```text
sterm-cli
  ├─ creates PTY
  ├─ spawns shell/process
  ├─ reads PTY output
  ├─ writes PTY input
  ├─ resizes PTY
  ├─ forwards output to libghostty-vt
  └─ emits render diffs to clients
```

## 11.2 Process Groups

Each pane process should be launched in its own process group/session where appropriate.

The agent must handle:

- `SIGHUP`.
- `SIGTERM`.
- `SIGKILL`.
- `SIGWINCH`.
- Child process exit.
- Zombie reaping.
- Shell login/non-login modes.
- Environment setup.
- Working directory.

## 11.3 Pane Close Behavior

When closing a pane, user should be prompted if a foreground process is running.

Options:

- Close pane and terminate process.
- Detach pane but leave process running.
- Cancel.

## 11.4 Detached Panes

A detached pane continues running but is not visible in the current layout.

This is useful for:

- Background AI agents.
- Watch processes.
- Long-running test suites.
- Logs.

---

# 12. libghostty-vt Integration

## 12.1 Server-Side VT Ownership

`libghostty-vt` should run inside `sterm-cli`.

For every pane:

```text
PTY output bytes
  ↓
libghostty-vt
  ↓
terminal state
  ↓
render diff generation
  ↓
client renderer
```

## 12.2 Why Server-Side?

Server-side VT state provides:

- Accurate reconnect.
- No raw-output replay requirement.
- Persistent scrollback.
- Better multi-client support.
- Server-side search/export possibilities.
- Consistent state if the Mac app disconnects.
- Better AI-agent monitoring.

## 12.3 Adapter Layer

Because `libghostty-vt` API may change, sterm must isolate it:

```text
cli/sterm-cli/src/vt/
  ├─ mod.zig
  ├─ ghostty_adapter.zig
  ├─ snapshot.zig
  ├─ diff.zig
  ├─ scrollback.zig
  └─ tests.zig
```

No other part of `sterm-cli` should call `libghostty-vt` directly.

## 12.4 VT Responsibilities

The VT adapter should expose:

```text
createTerminal(rows, cols)
feed(bytes)
resize(rows, cols)
getSnapshot()
getDirtyRegions()
getScrollbackWindow(offset, limit)
getCursor()
getTitle()
encodeInput(event)
destroy()
```

## 12.5 Scrollback

Scrollback should be handled primarily through `libghostty-vt` where possible.

Recommended production approach:

```text
PTY bytes
  ↓
append to pane output journal
  ↓
feed libghostty-vt
  ↓
store scrollback checkpoints
  ↓
emit render diffs
```

This gives both:

- Fast current-state rendering via `libghostty-vt`.
- Recovery/debuggability via output journal.
- Future migration if `libghostty-vt` changes.

## 12.6 Scrollback Storage Strategy

Use a layered model:

```text
Hot scrollback:
  in-memory ring buffer inside sterm-cli

Warm scrollback:
  SQLite-backed compressed chunks

Cold recovery:
  append-only PTY output journal, bounded by retention policy
```

Configurable limits:

```json
{
  "scrollback": {
    "default_lines": 100000,
    "max_lines_per_pane": 500000,
    "persist_scrollback": true,
    "compress_chunks": true,
    "output_journal_retention_days": 7
  }
}
```

## 12.7 Reflow

On pane resize:

```text
client resize
  ↓
sterm-cli pane resize
  ↓
PTY TIOCSWINSZ
  ↓
libghostty-vt resize/reflow
  ↓
new render snapshot/diff
```

The frontend should not independently reflow terminal content.

---

# 13. Rendering Architecture

## 13.1 Rendering Philosophy

The frontend is a renderer, not a terminal emulator.

The server sends render-state snapshots and incremental diffs.

```text
sterm-cli
  owns VT state

frontend
  draws VT state
```

## 13.2 Render Transport

Preferred:

```text
control plane: JSON-RPC or typed request/response
render stream: binary framed protocol
```

Initial production protocol may use MessagePack or a custom binary frame format.

Avoid sending full JSON screen grids for every update.

## 13.3 Render Snapshot

On reconnect or pane attach:

```json
{
  "type": "pane_snapshot",
  "pane_id": "pane_01",
  "seq": 18391,
  "rows": 40,
  "cols": 120,
  "cursor": {
    "row": 22,
    "col": 14,
    "visible": true,
    "style": "block"
  },
  "cells": "...binary encoded cell grid...",
  "scrollback": {
    "available_lines": 32144,
    "window_start": 31800,
    "window_lines": 344
  }
}
```

## 13.4 Render Diff

For live output:

```json
{
  "type": "pane_diff",
  "pane_id": "pane_01",
  "seq": 18392,
  "dirty_rows": [
    {
      "row": 22,
      "cells": "...binary encoded cells..."
    }
  ],
  "cursor": {
    "row": 22,
    "col": 21,
    "visible": true
  }
}
```

## 13.5 Frontend Render Loop

Use a custom render loop:

```text
incoming render frames
  ↓
decode frame
  ↓
update pane render model
  ↓
mark dirty rows/cells
  ↓
requestAnimationFrame
  ↓
draw dirty regions
```

Do not render on every incoming byte.

Do not repaint the entire canvas for every update.

## 13.6 Canvas 2D Renderer

Initial production renderer should use Canvas 2D with careful optimization.

Responsibilities:

- Draw background cells.
- Draw foreground glyphs.
- Draw cursor.
- Draw selection.
- Draw search highlights.
- Draw underline/strikethrough.
- Draw bold/italic.
- Handle retina scaling.
- Maintain glyph measurement.
- Support scrollback viewport.
- Support dirty-region rendering.

## 13.7 Future WebGPU Renderer

A future renderer may use WebGPU for:

- Large panes.
- Many simultaneous streaming panes.
- GPU glyph atlases.
- Better animation.
- Lower CPU usage.

The renderer package should be abstracted:

```text
packages/renderer
  ├─ core/
  ├─ canvas2d/
  ├─ webgpu/
  └─ react/
```

## 13.8 Renderer Input

Input path should be optimized separately from output path.

```text
keydown
  ↓
frontend input encoder
  ↓
persistent low-latency channel
  ↓
Tauri Rust backend
  ↓
SSH tunnel
  ↓
sterm-cli
  ↓
PTY write
```

The app should avoid:

- Heavy synchronous React work on keydown.
- Per-key Tauri command round trips.
- JSON-heavy input messages.
- Waiting for render confirmation before sending next input.

## 13.9 Input Latency Target

Target latency added by sterm excluding network RTT:

```text
keypress frontend handling: < 2ms
local backend dispatch: < 2ms
protocol serialization: < 1ms
agent PTY write: < 2ms
render response scheduling: next animation frame
```

Network RTT will dominate remote feel.

---

# 14. AI Agent Workflow Features

## 14.1 Design Requirement

sterm is optimized for servers running AI agents.

This means the UI must help users monitor, control, and resume many long-running agent sessions.

## 14.2 Agent-Aware Pane Detection

sterm should detect common agent processes:

- `claude`
- `codex`
- `aider`
- `cursor-agent`
- `opencode`
- custom user-defined commands

Detection sources:

- Process command.
- Pane title.
- Terminal output heuristics.
- User manual tagging.
- Integration-specific adapters later.

## 14.3 Agent Status

Pane status badges:

```text
running
thinking
waiting for input
needs approval
error
completed
idle
disconnected
```

## 14.4 Notification Rings

Panes and tabs should visually indicate when attention is needed.

Triggers:

- Bell character.
- Process exit.
- Agent asks for approval.
- Agent prompts for input.
- Command completes.
- Error pattern detected.
- User-defined regex match.
- Long silence after active process.
- Long-running task completed.

## 14.5 Sidebar Metadata

Vertical tab/sidebar should show:

- Workspace name.
- Tab name.
- Active pane title.
- Git branch.
- Current working directory.
- Running command.
- Last activity.
- Notification summary.
- Agent status.
- Exit code if completed.
- Remote host.

Example:

```text
AI Refactor
  main · /app
  Claude: needs approval
```

## 14.6 Command Palette

Command palette actions:

- Create workspace.
- Switch workspace.
- Create tab.
- Split right.
- Split down.
- Close pane.
- Detach pane.
- Reattach pane.
- Rename pane.
- Send input to pane.
- Broadcast input to panes.
- Find text in pane.
- Show agent panes needing attention.
- Upload clipboard file.
- Restart `sterm-cli`.
- Open remote logs.
- Run health check.

## 14.7 Broadcast Input

Support sending the same input to multiple panes.

Use cases:

- Run status commands across agents.
- Stop multiple agents.
- Start multiple test watchers.
- Send the same instruction to multiple coding agents.

Safety:

- Require explicit mode.
- Show visual indicator.
- Easy escape/cancel.
- Do not enable by accident.

## 14.8 Agent Session Templates

Users can define workspace templates:

```json
{
  "name": "multi-agent refactor",
  "root_dir": "/home/ubuntu/app",
  "tabs": [
    {
      "title": "Agents",
      "panes": [
        {
          "command": "claude",
          "cwd": "/home/ubuntu/app"
        },
        {
          "command": "codex",
          "cwd": "/home/ubuntu/app"
        }
      ]
    },
    {
      "title": "Tests",
      "panes": [
        {
          "command": "npm test -- --watch"
        },
        {
          "command": "npm run typecheck -- --watch"
        }
      ]
    }
  ]
}
```

---

# 15. Local Clipboard and File Paste

## 15.1 Text Paste

Text paste flow:

```text
macOS clipboard
  ↓
Tauri backend
  ↓
input event
  ↓
sterm-cli
  ↓
PTY
```

Use bracketed paste where appropriate.

## 15.2 File Paste

When user pastes a file:

```text
local file
  ↓
SFTP or sterm-cli upload endpoint
  ↓
~/.sterm/uploads/<workspace>/<file>
  ↓
paste remote path into pane
```

Example:

```text
/home/ubuntu/.sterm/uploads/ws_01/report.csv
```

## 15.3 Clipboard Security

- Do not automatically upload sensitive clipboard content.
- For files, show destination.
- For large files, show progress.
- Keep upload history visible.
- Allow clearing remote uploads.

---

# 16. Protocol

## 16.1 Requirements

The sterm protocol must support:

- Version negotiation.
- Authentication.
- Workspace CRUD.
- Tab CRUD.
- Split layout updates.
- Pane creation.
- Pane input.
- Pane resize.
- Pane close/detach.
- Pane render snapshots.
- Pane render diffs.
- Scrollback fetch.
- Search.
- Notifications.
- File upload metadata.
- Health checks.
- Logs.
- Agent update coordination.

## 16.2 Control Plane

Potential options:

- JSON-RPC over Unix socket.
- HTTP over Unix socket.
- gRPC over Unix socket.
- Custom typed binary protocol.

Recommendation:

```text
Production control plane:
  typed request/response protocol using MessagePack or Protobuf

Production stream plane:
  custom framed binary protocol
```

## 16.3 Frame Types

```text
HELLO
AUTH
PING
PONG
WORKSPACE_LIST
WORKSPACE_SNAPSHOT
PANE_CREATE
PANE_INPUT
PANE_RESIZE
PANE_CLOSE
PANE_SNAPSHOT
PANE_DIFF
SCROLLBACK_REQUEST
SCROLLBACK_CHUNK
NOTIFICATION
ERROR
```

## 16.4 Version Handshake

```json
{
  "type": "hello",
  "client_version": "1.0.0",
  "protocol_version": 1,
  "supported_features": [
    "pane-diff-v1",
    "scrollback-v1",
    "notifications-v1"
  ]
}
```

Agent response:

```json
{
  "type": "hello_ack",
  "agent_version": "1.0.0",
  "protocol_version": 1,
  "supported_features": [
    "pane-diff-v1",
    "scrollback-v1",
    "notifications-v1"
  ]
}
```

---

# 17. Persistence

## 17.1 State Store

Use SQLite on the VM:

```text
~/.sterm/state/sterm.db
```

SQLite stores:

- Workspaces.
- Tabs.
- Split trees.
- Panes.
- Process metadata.
- Notification history.
- Scrollback chunk metadata.
- Agent templates.
- Client sessions.
- Protocol version.
- Migration state.

## 17.2 Output Journal

Store bounded PTY output journals:

```text
~/.sterm/state/journal/<pane_id>.log.zst
```

This is used for:

- Recovery.
- Debugging.
- Rebuilding terminal state after crash.
- Exporting session history.

## 17.3 Crash Recovery

On `sterm-cli` restart:

```text
1. Open SQLite.
2. Load workspaces and panes.
3. Determine which PTYs/processes are still alive.
4. Mark dead panes as exited.
5. Restore terminal state from latest checkpoint.
6. Replay output journal if needed.
7. Accept client reconnect.
```

Important caveat:

If `sterm-cli` itself dies, child PTY processes may die unless they are carefully supervised. Production should use a process model that keeps pane child processes isolated and recoverable where possible.

Options:

- `sterm-cli` parent owns children directly.
- `sterm-cli-supervisor` process owns children.
- Per-pane lightweight supervisor.
- systemd user scopes for pane processes.

Production recommendation:

```text
sterm-cli daemon
  ├─ supervisor layer
  ├─ pane process groups
  └─ resilient child tracking
```

---

# 18. Notifications

## 18.1 Notification Sources

- Terminal bell.
- Regex match.
- Agent approval prompt.
- Command exit.
- Pane idle after activity.
- Pane output after background.
- Process error.
- User-defined rule.
- Build/test complete.
- Long-running agent stopped.

## 18.2 Notification UI

- Pane border glow.
- Sidebar ring.
- Tab badge.
- macOS notification.
- Command palette list.
- “Needs attention” filter.

## 18.3 Notification Rules

User-defined rules:

```json
{
  "name": "Claude approval",
  "match": "Do you want to proceed?",
  "scope": "pane_output",
  "action": "notify"
}
```

## 18.4 AI Agent Presets

Built-in patterns for:

- Claude Code approval prompts.
- Codex approval prompts.
- Test failure summaries.
- Build completion.
- Git conflict messages.

---

# 19. Security

## 19.1 Remote Agent Exposure

`sterm-cli` must listen on a Unix socket by default:

```text
~/.sterm/sterm.sock
```

Socket permissions:

```text
0600
```

Parent directory permissions:

```text
0700
```

No public TCP listener by default.

## 19.2 Agent Authentication

Even over an SSH tunnel, the client should authenticate to `sterm-cli`.

Use a per-install auth token:

```text
~/.sterm/state/auth_token
```

Permissions:

```text
0600
```

The desktop stores the corresponding token in macOS Keychain.

## 19.3 Binary Verification

The desktop app must verify uploaded `sterm-cli` binaries.

Required:

- SHA-256 checksum.
- Version check.
- Protocol compatibility.
- Optional signature verification.

## 19.4 Update Safety

Agent update process:

```text
1. Upload new binary to ~/.sterm/bin/sterm-cli.new
2. Verify checksum/signature.
3. Ask agent to prepare for restart.
4. Move current binary to sterm-cli.old
5. Move new binary to sterm-cli
6. Restart daemon.
7. Verify health.
8. Roll back if failed.
```

## 19.5 Least Privilege

- Install into user home directory.
- Do not require root.
- Do not modify shell startup files without approval.
- Do not expose network ports.
- Do not run privileged services.
- Do not enable lingering without explicit approval.

---

# 20. Monorepo Architecture

## 20.1 Proposed Layout

```text
sterm/
  apps/
    desktop/
      src-tauri/
        Cargo.toml
        src/
          main.rs
          ssh/
          tunnel/
          bootstrap/
          keychain/
          protocol/
      web/
        package.json
        vite.config.ts
        src/
          app/
          components/
          renderer/
          workspaces/
          panes/
          settings/
          command-palette/
          notifications/

  cli/
    sterm-cli/
      build.zig
      src/
        main.zig
        daemon.zig
        protocol.zig
        workspace.zig
        tab.zig
        pane.zig
        split.zig
        pty.zig
        process.zig
        vt/
          mod.zig
          ghostty_adapter.zig
          snapshot.zig
          diff.zig
          scrollback.zig
        storage/
          sqlite.zig
          migrations.zig
          journal.zig
        notify.zig
        auth.zig
        socket.zig
        upload.zig
        doctor.zig
      tests/

  crates/
    sterm-protocol/
    sterm-ssh/
    sterm-keychain/
    sterm-tunnel/
    sterm-bootstrap/
    sterm-shared/

  packages/
    renderer/
      src/
        core/
        canvas2d/
        webgpu/
        react/
    protocol-client/
    ui/
    theme/

  proto/
    sterm.capnp
    sterm.proto

  docs/
    architecture.md
    protocol.md
    security.md
    rendering.md
    agent.md

  scripts/
    build-agent.sh
    package-desktop.sh
    release.sh

  .github/
    workflows/
      ci.yml
      release.yml
```

## 20.2 Build System

Desktop:

```text
bun
vite
tauri
cargo
```

Agent:

```text
zig build
```

Release:

```text
macOS app bundle
sterm-cli-linux-x86_64
sterm-cli-linux-aarch64
checksums
signatures
```

## 20.3 CI Requirements

CI must:

- Build Tauri app.
- Build `sterm-cli` for supported Linux targets.
- Run Rust tests.
- Run Zig tests.
- Run TypeScript tests.
- Run renderer tests.
- Run protocol compatibility tests.
- Run SSH bootstrap integration tests.
- Run agent upgrade/downgrade tests.
- Run snapshot/diff golden tests.
- Run security checks.

---

# 21. User Experience

## 21.1 First Launch

User sees:

```text
Welcome to sterm
Connect your first VM
```

Options:

- Use SSH config.
- Add host manually.
- Import from `~/.ssh/config`.

## 21.2 Connect to VM

Flow:

```text
Select VM
  ↓
Authenticate
  ↓
Verify host key
  ↓
Install/update sterm-cli
  ↓
Start daemon
  ↓
Open workspace picker
```

## 21.3 Workspace Screen

Main UI:

```text
┌───────────────────────────────────────────────┐
│ VM: AI GPU VM                    Connected    │
├──────────────┬────────────────────────────────┤
│ Workspaces   │ Tab: Agents                    │
│              │ ┌─────────────┬──────────────┐ │
│ ● Refactor   │ │ Claude      │ Tests        │ │
│ ○ Logs       │ │             │              │ │
│ ○ Deploy     │ ├─────────────┴──────────────┤ │
│              │ │ Shell                      │ │
│ Needs input  │ │                            │ │
└──────────────┴────────────────────────────────┘
```

## 21.4 Pane Interaction

User can:

- Split right.
- Split down.
- Create tab.
- Rename pane.
- Move pane.
- Detach pane.
- Reattach pane.
- Close pane.
- Restart command.
- Send command.
- Copy selection.
- Paste text.
- Paste file.
- Search scrollback.
- Mark as agent pane.
- Mute notifications.

---

# 22. Performance Requirements

## 22.1 Input

- Input should feel as close to raw SSH as possible.
- Avoid React re-rendering on every keypress.
- Avoid per-key command invocation through Tauri.
- Use persistent streaming channel.

## 22.2 Output

- Batch render diffs.
- Render at animation-frame cadence.
- Use dirty-region drawing.
- Apply backpressure during high-output streams.
- Avoid full-screen snapshots except on attach/reconnect.
- Compress large scrollback responses.

## 22.3 Multi-Pane Stress Target

Production target:

```text
8 panes open
4 panes actively streaming logs
2 panes running full-screen TUIs
2 panes idle
100k scrollback lines per pane
UI remains responsive
```

## 22.4 Memory Limits

Per pane:

- Configurable scrollback limit.
- Bounded output journal.
- Bounded in-memory render state.
- Compression for persisted chunks.

---

# 23. Reliability Requirements

## 23.1 Network Loss

If the network drops:

- Client shows reconnecting state.
- `sterm-cli` continues running.
- Processes continue running.
- Output continues feeding into `libghostty-vt`.
- On reconnect, client restores state.

## 23.2 Client Crash

If the macOS app crashes:

- Remote processes continue.
- User can reopen app.
- App reconnects and restores workspace.

## 23.3 Agent Crash

If `sterm-cli` crashes:

- User service should restart it when configured.
- Agent should recover workspace metadata.
- Agent should mark unrecoverable panes clearly.
- Output journal should allow partial reconstruction.

## 23.4 VM Reboot

If the VM reboots:

- `sterm-cli` can restart as user service if configured.
- Old processes are gone.
- Workspaces remain.
- Panes show exited/rebooted state.
- User can restart templates.

---

# 24. Observability

## 24.1 Local Logs

Desktop logs:

```text
~/Library/Logs/sterm/
```

Include:

- SSH connection events.
- Bootstrap events.
- Tunnel state.
- Protocol errors.
- Renderer performance warnings.

Do not log secrets.

## 24.2 Remote Logs

Remote logs:

```text
~/.sterm/logs/sterm-cli.log
```

Include:

- Agent startup.
- Pane creation.
- Process exit.
- Protocol errors.
- VT errors.
- Storage errors.
- Notification events.

Do not log sensitive terminal contents by default.

## 24.3 Doctor Command

```bash
sterm-cli doctor
```

Checks:

- Version.
- Socket path.
- Permissions.
- SQLite health.
- PTY support.
- `libghostty-vt` integration.
- Disk space.
- systemd user service status.
- Active panes.
- Recent errors.

Desktop should expose “Run Remote Doctor.”

---

# 25. Configuration

## 25.1 Local Config

Stored on macOS:

```text
~/Library/Application Support/sterm/config.json
```

## 25.2 Remote Config

Stored on VM:

```text
~/.sterm/config.toml
```

Example:

```toml
[agent]
socket = "~/.sterm/sterm.sock"
state_dir = "~/.sterm/state"
log_file = "~/.sterm/logs/sterm-cli.log"

[scrollback]
default_lines = 100000
max_lines_per_pane = 500000
persist = true
compress = true

[notifications]
enable_bell = true
enable_agent_detection = true

[security]
require_auth_token = true
allow_tcp_listener = false
```

---

# 26. Keyboard Shortcuts

Default shortcuts should include:

```text
Cmd+T             New tab
Cmd+D             Split right
Cmd+Shift+D       Split down
Cmd+W             Close pane/tab
Cmd+K             Clear visible screen
Cmd+F             Search pane
Cmd+Shift+F       Search workspace
Cmd+P             Command palette
Cmd+1..9          Switch workspace/tab
Cmd+Option+Arrow  Move focus between panes
Cmd+Shift+Enter   Toggle maximize pane
```

All shortcuts should be user configurable.

---

# 27. Open Questions

## 27.1 libghostty-vt API Stability

Because `libghostty-vt` may evolve, sterm needs:

- Adapter isolation.
- Golden tests.
- Version pinning.
- Vendored dependency strategy.
- Clear upgrade policy.
- Fallback plan.

## 27.2 Multi-Client Support

Should two desktop clients attach to the same workspace at once?

Recommended production stance:

- Support read/write attach from one active client by default.
- Allow read-only observers later.
- Add conflict controls before multi-writer mode.

## 27.3 Agent Process Resilience

How strongly should child processes survive `sterm-cli` crash?

Options:

- Good: daemon restart recovers metadata but panes may exit.
- Better: per-pane supervisor.
- Best: systemd scopes or separate supervisor process.

Production should at least design for future supervisor separation.

## 27.4 Transport Evolution

Should sterm later implement a Mosh-like UDP transport?

Recommendation:

- Not required initially.
- Keep protocol transport-agnostic.
- Design stream layer so SSH tunnel can be replaced later.

---

# 28. Success Criteria

sterm is successful when:

- A user can connect to a new VM and install `sterm-cli` automatically.
- A user can create a workspace with multiple tabs and split panes.
- A user can run AI agents in panes.
- Closing the Mac app does not kill remote processes.
- Reconnecting restores layout, terminal state, and scrollback.
- Input latency feels comparable to SSH.
- Multiple active panes remain responsive.
- Agent notifications reliably indicate when user attention is needed.
- SSH credentials are stored securely.
- The remote daemon is not publicly exposed.
- The monorepo can build, test, and release desktop and agent binaries reliably.

---

# 29. Production Architecture Summary

```text
macOS
  └─ sterm desktop app
      ├─ Tauri Rust backend
      │   ├─ SSH auth
      │   ├─ Keychain
      │   ├─ bootstrap
      │   ├─ tunnels
      │   └─ protocol bridge
      │
      └─ Vite + React frontend
          ├─ workspace UI
          ├─ split panes
          ├─ notifications
          ├─ command palette
          └─ custom Canvas/WebGPU-ready terminal renderer

SSH tunnel

Remote VM
  └─ sterm-cli
      ├─ Zig daemon
      ├─ Unix socket API
      ├─ workspace manager
      ├─ tab/split/pane manager
      ├─ PTY manager
      ├─ process supervisor
      ├─ libghostty-vt terminal state
      ├─ render snapshot/diff engine
      ├─ scrollback persistence
      ├─ notification engine
      ├─ SQLite state store
      └─ output journal
```

---

# 30. Final Product Definition

sterm is a remote-first, persistent, AI-agent-aware terminal workspace.

It uses:

```text
Tauri + Rust for the desktop shell and SSH control
Vite + React for the frontend
Custom frontend render loop for terminal drawing
Zig for the remote sterm-cli agent
libghostty-vt server-side for terminal state
SQLite for remote persistence
SSH for secure bootstrap and tunneling
```

The defining architectural decision is:

> `sterm-cli` owns the terminal reality.  
> The macOS app renders and controls it.

That is what enables persistent panes, reconnectable workspaces, server-side scrollback, AI-agent monitoring, and a production-grade remote terminal experience.


## URLs

https://github.com/manaflow-ai/cmux/issues
https://cmux.dev
https://ghostty.org/docs/vt
https://github.com/ghostty-org/ghostty
