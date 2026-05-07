//! Tunnel planning with Unix-socket-first defaults and no public TCP listener by default.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use sterm_ssh::SshConfig;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum LocalEndpoint {
    UnixSocket(PathBuf),
    LoopbackTcp { port: u16 },
}

impl Default for LocalEndpoint {
    fn default() -> Self {
        Self::UnixSocket(PathBuf::from("~/.sterm/tunnel.sock"))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RemoteEndpoint {
    UnixSocket(PathBuf),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TunnelPlan {
    pub ssh: SshConfig,
    pub local: LocalEndpoint,
    pub remote: RemoteEndpoint,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TunnelPolicy {
    pub allow_loopback_tcp: bool,
    pub allow_public_tcp: bool,
}

impl Default for TunnelPolicy {
    fn default() -> Self {
        Self {
            allow_loopback_tcp: true,
            allow_public_tcp: false,
        }
    }
}

impl TunnelPlan {
    pub fn validate(&self) -> Result<(), TunnelError> {
        self.ssh
            .validate()
            .map_err(|_| TunnelError::InvalidSshConfig)?;
        match &self.local {
            LocalEndpoint::UnixSocket(path) => {
                if path.as_os_str().is_empty() {
                    return Err(TunnelError::MissingLocalSocket);
                }
            }
            LocalEndpoint::LoopbackTcp { port } => {
                if *port == 0 {
                    return Err(TunnelError::InvalidLocalPort);
                }
            }
        }
        Ok(())
    }

    pub fn validate_policy(&self, policy: &TunnelPolicy) -> Result<(), TunnelError> {
        self.validate()?;
        match &self.local {
            LocalEndpoint::UnixSocket(_) => Ok(()),
            LocalEndpoint::LoopbackTcp { .. } if policy.allow_loopback_tcp => Ok(()),
            LocalEndpoint::LoopbackTcp { .. } => Err(TunnelError::LoopbackTcpDisabled),
        }
    }

    pub fn local_loopback_addr(port: u16) -> SocketAddr {
        SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), port)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TunnelError {
    InvalidSshConfig,
    MissingLocalSocket,
    InvalidLocalPort,
    LoopbackTcpDisabled,
}
impl fmt::Display for TunnelError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}
impl std::error::Error for TunnelError {}

#[cfg(test)]
mod tests {
    use super::*;
    use sterm_ssh::{CredentialRef, HostKeyPolicy, SshTarget};

    fn plan() -> TunnelPlan {
        TunnelPlan {
            ssh: SshConfig {
                target: SshTarget::new("example.com", "alice"),
                credential: CredentialRef::Agent,
                host_key_policy: HostKeyPolicy::Strict,
                connect_timeout_ms: 10_000,
            },
            local: LocalEndpoint::default(),
            remote: RemoteEndpoint::UnixSocket(PathBuf::from("/run/user/1000/sterm.sock")),
        }
    }

    #[test]
    fn default_local_endpoint_is_not_public_tcp() {
        assert!(matches!(
            LocalEndpoint::default(),
            LocalEndpoint::UnixSocket(_)
        ));
        assert!(plan().validate().is_ok());
        assert!(plan().validate_policy(&TunnelPolicy::default()).is_ok());
    }

    #[test]
    fn loopback_helper_never_binds_public_ip() {
        assert_eq!(
            TunnelPlan::local_loopback_addr(49152).ip(),
            IpAddr::V4(Ipv4Addr::LOCALHOST)
        );
    }

    #[test]
    fn tunnel_policy_requires_explicit_loopback_tcp_allowance() {
        let mut plan = plan();
        plan.local = LocalEndpoint::LoopbackTcp { port: 49200 };
        assert!(plan.validate_policy(&TunnelPolicy::default()).is_ok());
        assert_eq!(
            plan.validate_policy(&TunnelPolicy {
                allow_loopback_tcp: false,
                allow_public_tcp: false,
            }),
            Err(TunnelError::LoopbackTcpDisabled)
        );
    }
}
