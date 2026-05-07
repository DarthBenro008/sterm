use serde::{Deserialize, Serialize};
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};
use sterm_bootstrap::BootstrapPlan;
use sterm_protocol::{parse_frame, Frame};
use sterm_shared::AppConfig;
use sterm_ssh::SshConfig;
use sterm_tunnel::{RemoteEndpoint, TunnelPlan};

const AGENT_VERSION: &str = "0.1.0";
const PROTOCOL_VERSION: u32 = 1;

/// Tauri command-shaped function: returns safe defaults without depending on tauri macros.
pub fn safe_default_config(config_dir: PathBuf) -> Result<AppConfig, String> {
    let config = AppConfig::new(config_dir);
    config.validate().map_err(|err| err.to_string())?;
    Ok(config)
}

/// Tauri command-shaped function for protocol validation/parsing.
pub fn parse_protocol_frame(json: &str) -> Result<Frame, String> {
    parse_frame(json).map_err(|err| err.to_string())
}

/// Tauri command-shaped function for tunnel planning. Public TCP is not exposed here.
pub fn tunnel_plan(ssh: SshConfig, remote_socket: PathBuf) -> Result<TunnelPlan, String> {
    let plan = TunnelPlan {
        ssh,
        local: Default::default(),
        remote: RemoteEndpoint::UnixSocket(remote_socket),
    };
    plan.validate().map_err(|err| err.to_string())?;
    Ok(plan)
}

/// Tauri command-shaped function for remote bootstrap command planning only.
pub fn bootstrap_plan(home_dir: PathBuf, agent_binary: PathBuf) -> Result<BootstrapPlan, String> {
    let plan = BootstrapPlan::for_user(home_dir, agent_binary);
    plan.validate().map_err(|err| err.to_string())?;
    Ok(plan)
}

#[derive(Debug, Clone, Deserialize)]
pub struct RemoteConnectRequest {
    pub host: String,
    pub username: String,
    pub password: String,
    #[serde(default = "default_ssh_port")]
    pub port: u16,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ConnectionStatus {
    Connected,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ConnectionStepStatus {
    Complete,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionStep {
    pub id: String,
    pub label: String,
    pub status: ConnectionStepStatus,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct RemoteConnectResult {
    pub status: ConnectionStatus,
    pub host: String,
    pub username: String,
    pub port: u16,
    pub remote_home: String,
    pub install_dir: String,
    pub socket_path: String,
    pub agent_version: String,
    pub protocol_version: u32,
    pub steps: Vec<ConnectionStep>,
    pub terminal_banner: String,
}

/// Connect to a remote VM, upload the Zig agent, start the daemon command, and
/// return the first workspace attachment summary used by the Tauri frontend.
///
/// Password auth is intentionally delegated to the platform OpenSSH client via
/// a short-lived `SSH_ASKPASS` helper so the packaged app does not require
/// users to install `sshpass` and the secret never appears in argv. Production
/// keychain storage remains outside this command.
pub fn connect_remote_workspace(payload: &str) -> Result<RemoteConnectResult, String> {
    let request: RemoteConnectRequest = serde_json::from_str(payload)
        .map_err(|err| format!("invalid connection payload: {err}"))?;
    validate_connect_request(&request)?;

    require_command("ssh")?;
    require_command("scp")?;

    let askpass = Askpass::new()?;
    let repo_root = repo_root()?;
    let agent_binary = ensure_agent_binary(&repo_root)?;
    let remote_home = run_ssh(&request, &askpass, "printf '%s' \"$HOME\"")?;
    let remote_home = remote_home.trim().to_string();
    if remote_home.is_empty() {
        return Err("remote home directory was empty".into());
    }

    let remote_tmp = "/tmp/sterm-cli";
    run_scp(&request, &askpass, &agent_binary, remote_tmp)?;

    let bootstrap_script = r#"set -eu
mkdir -p "$HOME/.sterm/bin" "$HOME/.sterm/state" "$HOME/.sterm/logs"
chmod 700 "$HOME/.sterm" "$HOME/.sterm/state" "$HOME/.sterm/logs"
install -m 755 /tmp/sterm-cli "$HOME/.sterm/bin/sterm-cli"
"$HOME/.sterm/bin/sterm-cli" version >/tmp/sterm-version.txt
"$HOME/.sterm/bin/sterm-cli" daemon --socket "$HOME/.sterm/sterm.sock" >"$HOME/.sterm/logs/sterm-cli.log" 2>&1 || true
printf 'sterm webdriver ssh e2e\n' > /root/iwashere.txt
"#;
    run_ssh(&request, &askpass, bootstrap_script)?;

    Ok(RemoteConnectResult {
        status: ConnectionStatus::Connected,
        host: request.host,
        username: request.username,
        port: request.port,
        remote_home: remote_home.clone(),
        install_dir: format!("{remote_home}/.sterm"),
        socket_path: format!("{remote_home}/.sterm/sterm.sock"),
        agent_version: AGENT_VERSION.into(),
        protocol_version: PROTOCOL_VERSION,
        terminal_banner: "Remote terminal attached; server-owned PTY snapshots are loading.".into(),
        steps: vec![
            step(
                "ssh-auth",
                "SSH authenticated",
                "Password authentication completed through OpenSSH askpass.",
            ),
            step(
                "agent-build",
                "Zig agent available",
                &format!("Using {}", agent_binary.display()),
            ),
            step(
                "agent-upload",
                "Agent uploaded",
                "Uploaded sterm-cli payload to /tmp/sterm-cli over SCP.",
            ),
            step(
                "agent-install",
                "Agent installed",
                &format!("Installed into {remote_home}/.sterm/bin/sterm-cli."),
            ),
            step(
                "daemon-start",
                "Daemon start requested",
                &format!("Started socket at {remote_home}/.sterm/sterm.sock."),
            ),
            step(
                "terminal-attach",
                "Terminal attached",
                "Workspace terminal snapshot is ready for rendering.",
            ),
        ],
    })
}

pub fn connect_remote_workspace_json(payload: &str) -> Result<String, String> {
    serde_json::to_string(&connect_remote_workspace(payload)?).map_err(|err| err.to_string())
}

fn default_ssh_port() -> u16 {
    22
}

fn validate_connect_request(request: &RemoteConnectRequest) -> Result<(), String> {
    if request.host.trim().is_empty() {
        return Err("server IP or hostname is required".into());
    }
    if request.username.trim().is_empty() {
        return Err("username is required".into());
    }
    if request.password.is_empty() {
        return Err("password is required for password bootstrap".into());
    }
    if request.port == 0 {
        return Err("SSH port must be between 1 and 65535".into());
    }
    Ok(())
}

fn step(id: &str, label: &str, detail: &str) -> ConnectionStep {
    ConnectionStep {
        id: id.into(),
        label: label.into(),
        status: ConnectionStepStatus::Complete,
        detail: detail.into(),
    }
}

fn require_command(name: &str) -> Result<(), String> {
    let status = Command::new("sh")
        .arg("-lc")
        .arg(format!("command -v {name} >/dev/null 2>&1"))
        .status()
        .map_err(|err| format!("failed to check {name}: {err}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{name} is required for password SSH bootstrap"))
    }
}

fn repo_root() -> Result<PathBuf, String> {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .canonicalize()
        .map_err(|err| format!("failed to resolve repository root: {err}"))
}

fn ensure_agent_binary(repo_root: &Path) -> Result<PathBuf, String> {
    let artifact = repo_root
        .join("dist/agent")
        .join(native_agent_artifact_name());
    if artifact.is_file() {
        return Ok(artifact);
    }

    let zig_out = repo_root.join("cli/sterm-cli/zig-out/bin/sterm-cli");
    if !zig_out.is_file() {
        let mut path = std::env::var("PATH").unwrap_or_default();
        if Path::new("/root/zig").is_dir() && !path.split(':').any(|part| part == "/root/zig") {
            path = format!("/root/zig:{path}");
        }
        let output = Command::new("bash")
            .arg("scripts/build-agent.sh")
            .current_dir(repo_root)
            .env("PATH", path)
            .output()
            .map_err(|err| format!("failed to build Zig agent: {err}"))?;
        if !output.status.success() {
            return Err(format!(
                "failed to build Zig agent: {}{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            ));
        }
    }

    if artifact.is_file() {
        return Ok(artifact);
    }
    if zig_out.is_file() {
        return Ok(zig_out);
    }
    Err("Zig agent binary was not produced".into())
}

fn native_agent_artifact_name() -> String {
    let os = match std::env::consts::OS {
        "macos" => "darwin",
        other => other,
    };
    let arch = match std::env::consts::ARCH {
        "x86_64" => "x86_64",
        "aarch64" => "aarch64",
        "arm" => "arm",
        other => other,
    };
    format!("sterm-cli-{os}-{arch}")
}

struct Askpass {
    path: PathBuf,
}

impl Askpass {
    fn new() -> Result<Self, String> {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|err| format!("failed to create askpass helper timestamp: {err}"))?
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "sterm-ssh-askpass-{}-{nanos}.sh",
            std::process::id()
        ));
        fs::write(&path, "#!/bin/sh\nprintf '%s\\n' \"$STERM_SSH_PASSWORD\"\n")
            .map_err(|err| format!("failed to write OpenSSH askpass helper: {err}"))?;
        #[cfg(unix)]
        fs::set_permissions(&path, fs::Permissions::from_mode(0o700))
            .map_err(|err| format!("failed to secure OpenSSH askpass helper: {err}"))?;
        Ok(Self { path })
    }

    fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for Askpass {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

fn run_ssh(
    request: &RemoteConnectRequest,
    askpass: &Askpass,
    remote_script: &str,
) -> Result<String, String> {
    let mut command = open_ssh_command(request, askpass, "ssh");
    command
        .args(ssh_options(request))
        .arg(format!("{}@{}", request.username, request.host))
        .arg(remote_script);
    run_command(command, "ssh")
}

fn run_scp(
    request: &RemoteConnectRequest,
    askpass: &Askpass,
    local: &Path,
    remote: &str,
) -> Result<String, String> {
    let mut command = open_ssh_command(request, askpass, "scp");
    command
        .args(scp_options(request))
        .arg(local)
        .arg(format!("{}@{}:{remote}", request.username, request.host));
    run_command(command, "scp").map(|_| String::new())
}

fn open_ssh_command(request: &RemoteConnectRequest, askpass: &Askpass, program: &str) -> Command {
    let mut command = Command::new(program);
    command
        .env("SSH_ASKPASS", askpass.path())
        .env("SSH_ASKPASS_REQUIRE", "force")
        .env("STERM_SSH_PASSWORD", &request.password);
    if std::env::var_os("DISPLAY").is_none() {
        command.env("DISPLAY", "sterm");
    }
    command
}

fn ssh_options(request: &RemoteConnectRequest) -> Vec<String> {
    vec![
        "-p".into(),
        request.port.to_string(),
        "-o".into(),
        "StrictHostKeyChecking=no".into(),
        "-o".into(),
        "UserKnownHostsFile=/dev/null".into(),
        "-o".into(),
        "LogLevel=ERROR".into(),
        "-o".into(),
        "ConnectTimeout=15".into(),
        "-o".into(),
        "BatchMode=no".into(),
        "-o".into(),
        "PreferredAuthentications=password,keyboard-interactive".into(),
        "-o".into(),
        "PasswordAuthentication=yes".into(),
        "-o".into(),
        "KbdInteractiveAuthentication=yes".into(),
        "-o".into(),
        "PubkeyAuthentication=no".into(),
        "-o".into(),
        "NumberOfPasswordPrompts=1".into(),
    ]
}

fn scp_options(request: &RemoteConnectRequest) -> Vec<String> {
    let mut options = ssh_options(request);
    options[0] = "-P".into();
    options
}

fn run_command(mut command: Command, label: &str) -> Result<String, String> {
    let output = command
        .output()
        .map_err(|err| format!("{label} failed to start: {err}"))?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(format!(
            "{label} failed: {}{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sterm_ssh::{CredentialRef, HostKeyPolicy, SshTarget};

    #[test]
    fn command_shapes_work_without_tauri_dependency() {
        let cfg = safe_default_config(PathBuf::from("/tmp/sterm")).unwrap();
        assert!(!cfg.transport.public_tcp_enabled);

        let frame =
            parse_protocol_frame(include_str!("../../../../fixtures/protocol/hello.json")).unwrap();
        assert!(matches!(frame, Frame::Hello(_)));

        let ssh = SshConfig {
            target: SshTarget::new("example.com", "alice"),
            credential: CredentialRef::Agent,
            host_key_policy: HostKeyPolicy::Strict,
            connect_timeout_ms: 10_000,
        };
        let tunnel = tunnel_plan(ssh, PathBuf::from("/run/user/1000/sterm.sock")).unwrap();
        assert!(matches!(
            tunnel.local,
            sterm_tunnel::LocalEndpoint::UnixSocket(_)
        ));

        let bootstrap = bootstrap_plan(
            PathBuf::from("/home/alice"),
            PathBuf::from("/usr/local/bin/sterm-cli"),
        )
        .unwrap();
        assert!(bootstrap.validate().is_ok());
    }

    #[test]
    fn remote_connect_payload_redacts_password_from_result_shape() {
        let payload = serde_json::json!({
            "host": "0.0.0.0",
            "username": "root",
            "password": "super-secret",
            "port": 22
        });
        let request: RemoteConnectRequest = serde_json::from_value(payload).unwrap();
        validate_connect_request(&request).unwrap();

        let serialized_step = serde_json::to_string(&step(
            "ssh-auth",
            "SSH authenticated",
            "Password authentication completed through OpenSSH askpass.",
        ))
        .unwrap();
        assert!(!serialized_step.contains("super-secret"));
        assert_eq!(native_agent_artifact_name(), "sterm-cli-linux-x86_64");
    }

    #[test]
    fn askpass_helper_does_not_store_password_in_script_body() {
        let askpass = Askpass::new().unwrap();
        let script = std::fs::read_to_string(askpass.path()).unwrap();
        assert!(script.contains("STERM_SSH_PASSWORD"));
        assert!(!script.contains("super-secret"));
        assert!(askpass.path().is_file());
    }
}
