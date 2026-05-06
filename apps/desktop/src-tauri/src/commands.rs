use std::path::PathBuf;
use sterm_bootstrap::BootstrapPlan;
use sterm_protocol::{parse_frame, Frame};
use sterm_shared::AppConfig;
use sterm_ssh::SshConfig;
use sterm_tunnel::{RemoteEndpoint, TunnelPlan};

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
}
