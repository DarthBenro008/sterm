use std::fmt;
use std::path::PathBuf;
use sterm_bootstrap::BootstrapPlan;
use sterm_protocol::{parse_frame, Frame};
use sterm_shared::AppConfig;
use sterm_ssh::SshConfig;
use sterm_tunnel::{RemoteEndpoint, TunnelPlan};

#[derive(Debug, Clone)]
pub struct Backend {
    config: AppConfig,
}

impl Backend {
    pub fn new(config_dir: impl Into<PathBuf>) -> Result<Self, BackendError> {
        let config = AppConfig::new(config_dir);
        config
            .validate()
            .map_err(|err| BackendError::InvalidConfig(err.to_string()))?;
        Ok(Self { config })
    }

    pub fn config(&self) -> &AppConfig {
        &self.config
    }

    pub fn parse_frame(&self, json: &str) -> Result<Frame, BackendError> {
        parse_frame(json).map_err(|err| BackendError::Protocol(err.to_string()))
    }

    pub fn plan_tunnel(
        &self,
        ssh: SshConfig,
        remote_socket: impl Into<PathBuf>,
    ) -> Result<TunnelPlan, BackendError> {
        let plan = TunnelPlan {
            ssh,
            local: Default::default(),
            remote: RemoteEndpoint::UnixSocket(remote_socket.into()),
        };
        plan.validate()
            .map_err(|err| BackendError::Tunnel(err.to_string()))?;
        Ok(plan)
    }

    pub fn plan_bootstrap(
        &self,
        home_dir: impl Into<PathBuf>,
        agent_binary: impl Into<PathBuf>,
    ) -> Result<BootstrapPlan, BackendError> {
        let plan = BootstrapPlan::for_user(home_dir, agent_binary);
        plan.validate()
            .map_err(|err| BackendError::Bootstrap(err.to_string()))?;
        Ok(plan)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BackendError {
    InvalidConfig(String),
    Protocol(String),
    Tunnel(String),
    Bootstrap(String),
}

impl fmt::Display for BackendError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidConfig(message) => write!(f, "invalid config: {message}"),
            Self::Protocol(message) => write!(f, "protocol error: {message}"),
            Self::Tunnel(message) => write!(f, "tunnel error: {message}"),
            Self::Bootstrap(message) => write!(f, "bootstrap error: {message}"),
        }
    }
}

impl std::error::Error for BackendError {}

#[cfg(test)]
mod tests {
    use super::*;
    use sterm_ssh::{CredentialRef, HostKeyPolicy, SshTarget};

    #[test]
    fn backend_defaults_to_safe_config() {
        let backend = Backend::new("/tmp/sterm").unwrap();
        assert!(!backend.config().transport.public_tcp_enabled);
        assert!(backend.config().log_policy.redact_secrets);
    }

    #[test]
    fn backend_plans_unix_socket_tunnel() {
        let backend = Backend::new("/tmp/sterm").unwrap();
        let ssh = SshConfig {
            target: SshTarget::new("example.com", "alice"),
            credential: CredentialRef::Agent,
            host_key_policy: HostKeyPolicy::Strict,
            connect_timeout_ms: 10_000,
        };
        let plan = backend
            .plan_tunnel(ssh, "/run/user/1000/sterm.sock")
            .unwrap();
        assert!(matches!(
            plan.local,
            sterm_tunnel::LocalEndpoint::UnixSocket(_)
        ));
    }
}
