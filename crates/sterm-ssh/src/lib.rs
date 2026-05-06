//! SSH connection planning primitives. This crate intentionally stores no plaintext credentials.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::path::PathBuf;
use sterm_shared::SecretString;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SshTarget {
    pub host: String,
    pub port: u16,
    pub username: String,
}

impl SshTarget {
    pub fn new(host: impl Into<String>, username: impl Into<String>) -> Self {
        Self {
            host: host.into(),
            port: 22,
            username: username.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum CredentialRef {
    Agent,
    Keychain { service: String, account: String },
    IdentityFile { path: PathBuf },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum HostKeyPolicy {
    Strict,
    TrustOnFirstUse { persist: bool },
    PinnedSha256 { fingerprint: String },
}

impl Default for HostKeyPolicy {
    fn default() -> Self {
        Self::Strict
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SshConfig {
    pub target: SshTarget,
    pub credential: CredentialRef,
    pub host_key_policy: HostKeyPolicy,
    pub connect_timeout_ms: u64,
}

impl SshConfig {
    pub fn validate(&self) -> Result<(), SshConfigError> {
        if self.target.host.trim().is_empty() {
            return Err(SshConfigError::MissingHost);
        }
        if self.target.username.trim().is_empty() {
            return Err(SshConfigError::MissingUsername);
        }
        if self.target.port == 0 {
            return Err(SshConfigError::InvalidPort);
        }
        if let HostKeyPolicy::PinnedSha256 { fingerprint } = &self.host_key_policy {
            if !fingerprint.starts_with("SHA256:") {
                return Err(SshConfigError::InvalidFingerprint);
            }
        }
        Ok(())
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct RuntimeSecret(pub SecretString);

impl fmt::Debug for RuntimeSecret {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("RuntimeSecret([REDACTED])")
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SshConfigError {
    MissingHost,
    MissingUsername,
    InvalidPort,
    InvalidFingerprint,
}

impl fmt::Display for SshConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}
impl std::error::Error for SshConfigError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid() -> SshConfig {
        SshConfig {
            target: SshTarget::new("example.com", "alice"),
            credential: CredentialRef::Agent,
            host_key_policy: HostKeyPolicy::default(),
            connect_timeout_ms: 10_000,
        }
    }

    #[test]
    fn strict_host_key_policy_is_default() {
        assert_eq!(HostKeyPolicy::default(), HostKeyPolicy::Strict);
        assert!(valid().validate().is_ok());
    }

    #[test]
    fn rejects_malformed_pinned_fingerprint() {
        let mut cfg = valid();
        cfg.host_key_policy = HostKeyPolicy::PinnedSha256 {
            fingerprint: "md5:bad".into(),
        };
        assert_eq!(cfg.validate(), Err(SshConfigError::InvalidFingerprint));
    }

    #[test]
    fn runtime_secret_debug_is_redacted() {
        let secret = RuntimeSecret(SecretString::new("<fixture-secret>"));
        assert_eq!(format!("{:?}", secret), "RuntimeSecret([REDACTED])");
    }
}
