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
    PasswordKeychain { service: String, account: String },
    PassphraseKeychain { service: String, account: String },
    IdentityFile { path: PathBuf },
    KeyboardInteractive,
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum HostKeyEvidenceSource {
    KnownHosts { path: PathBuf },
    UserApprovedTofu,
    PinnedConfig,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostKeyEvidence {
    pub fingerprint_sha256: String,
    pub source: HostKeyEvidenceSource,
}

impl HostKeyEvidence {
    pub fn validate_for(&self, policy: &HostKeyPolicy) -> Result<(), SshConfigError> {
        if !self.fingerprint_sha256.starts_with("SHA256:") {
            return Err(SshConfigError::InvalidFingerprint);
        }
        match (policy, &self.source) {
            (HostKeyPolicy::Strict, HostKeyEvidenceSource::KnownHosts { path }) => {
                if path.as_os_str().is_empty() {
                    return Err(SshConfigError::MissingHostKeyEvidence);
                }
            }
            (
                HostKeyPolicy::TrustOnFirstUse { persist },
                HostKeyEvidenceSource::UserApprovedTofu,
            ) => {
                if !persist {
                    return Err(SshConfigError::UnpersistedTrustOnFirstUse);
                }
            }
            (HostKeyPolicy::PinnedSha256 { fingerprint }, HostKeyEvidenceSource::PinnedConfig) => {
                if fingerprint != &self.fingerprint_sha256 {
                    return Err(SshConfigError::HostKeyEvidenceMismatch);
                }
            }
            _ => return Err(SshConfigError::HostKeyEvidenceMismatch),
        }
        Ok(())
    }
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
        match &self.credential {
            CredentialRef::Agent | CredentialRef::KeyboardInteractive => {}
            CredentialRef::IdentityFile { path } => {
                if path.as_os_str().is_empty() {
                    return Err(SshConfigError::EmptyCredentialRef);
                }
            }
            CredentialRef::Keychain { service, account }
            | CredentialRef::PasswordKeychain { service, account }
            | CredentialRef::PassphraseKeychain { service, account } => {
                if service.trim().is_empty() || account.trim().is_empty() {
                    return Err(SshConfigError::EmptyCredentialRef);
                }
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
    EmptyCredentialRef,
    MissingHostKeyEvidence,
    UnpersistedTrustOnFirstUse,
    HostKeyEvidenceMismatch,
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
    fn validates_strict_host_key_evidence() {
        let evidence = HostKeyEvidence {
            fingerprint_sha256: "SHA256:abcdef".into(),
            source: HostKeyEvidenceSource::KnownHosts {
                path: PathBuf::from("/home/alice/.ssh/known_hosts"),
            },
        };
        evidence.validate_for(&HostKeyPolicy::Strict).unwrap();
    }

    #[test]
    fn rejects_unpersisted_tofu_and_mismatched_pins() {
        let tofu = HostKeyEvidence {
            fingerprint_sha256: "SHA256:abcdef".into(),
            source: HostKeyEvidenceSource::UserApprovedTofu,
        };
        assert_eq!(
            tofu.validate_for(&HostKeyPolicy::TrustOnFirstUse { persist: false }),
            Err(SshConfigError::UnpersistedTrustOnFirstUse)
        );

        let pinned = HostKeyEvidence {
            fingerprint_sha256: "SHA256:abcdef".into(),
            source: HostKeyEvidenceSource::PinnedConfig,
        };
        assert_eq!(
            pinned.validate_for(&HostKeyPolicy::PinnedSha256 {
                fingerprint: "SHA256:other".into()
            }),
            Err(SshConfigError::HostKeyEvidenceMismatch)
        );
    }

    #[test]
    fn rejects_empty_credential_references() {
        let mut cfg = valid();
        cfg.credential = CredentialRef::Keychain {
            service: "".into(),
            account: "alice".into(),
        };
        assert_eq!(cfg.validate(), Err(SshConfigError::EmptyCredentialRef));
    }

    #[test]
    fn runtime_secret_debug_is_redacted() {
        let secret = RuntimeSecret(SecretString::new("<fixture-secret>"));
        assert_eq!(format!("{:?}", secret), "RuntimeSecret([REDACTED])");
    }
}
