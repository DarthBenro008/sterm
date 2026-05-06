//! Shared security and configuration primitives for the sterm Rust backend.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::path::{Path, PathBuf};

pub const DEFAULT_STERM_HOME: &str = "~/.sterm";
pub const DEFAULT_SOCKET_PATH: &str = "~/.sterm/sterm.sock";
pub const DEFAULT_STATE_PATH: &str = "~/.sterm/state/sterm.db";
pub const DEFAULT_LOG_PATH: &str = "~/.sterm/logs/sterm-cli.log";
pub const SECURE_DIR_MODE: u32 = 0o700;
pub const SECURE_FILE_MODE: u32 = 0o600;
pub const DEFAULT_CONFIG_DIR_MODE: u32 = SECURE_DIR_MODE;
pub const DEFAULT_SECRET_FILE_MODE: u32 = SECURE_FILE_MODE;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppConfig {
    pub config_dir: PathBuf,
    pub transport: TransportConfig,
    pub log_policy: LogPolicy,
}

impl AppConfig {
    pub fn new(config_dir: impl Into<PathBuf>) -> Self {
        Self {
            config_dir: config_dir.into(),
            transport: TransportConfig::default(),
            log_policy: LogPolicy::default(),
        }
    }

    pub fn validate(&self) -> Result<(), ConfigError> {
        self.transport.validate()?;
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TransportConfig {
    pub local_ipc: LocalIpcConfig,
    pub public_tcp_enabled: bool,
}

impl Default for TransportConfig {
    fn default() -> Self {
        Self {
            local_ipc: LocalIpcConfig::default(),
            public_tcp_enabled: false,
        }
    }
}

impl TransportConfig {
    pub fn validate(&self) -> Result<(), ConfigError> {
        if self.public_tcp_enabled {
            return Err(ConfigError::PublicTcpDisabledByDefault);
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalIpcConfig {
    pub socket_path: PathBuf,
    pub socket_mode: u32,
}

impl Default for LocalIpcConfig {
    fn default() -> Self {
        Self {
            socket_path: PathBuf::from(DEFAULT_SOCKET_PATH),
            socket_mode: SECURE_FILE_MODE,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LogPolicy {
    pub redact_secrets: bool,
    pub include_terminal_contents: bool,
}

impl Default for LogPolicy {
    fn default() -> Self {
        Self {
            redact_secrets: true,
            include_terminal_contents: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ConfigError {
    PublicTcpDisabledByDefault,
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::PublicTcpDisabledByDefault => {
                write!(f, "public TCP listeners require explicit approved override")
            }
        }
    }
}

impl std::error::Error for ConfigError {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PermissionIssue {
    MissingPath(PathBuf),
    TooPermissive {
        path: PathBuf,
        actual: u32,
        expected: u32,
    },
}

pub fn validate_mode(
    path: impl AsRef<Path>,
    actual_mode: u32,
    expected_mode: u32,
) -> Result<(), PermissionIssue> {
    let path = path.as_ref().to_path_buf();
    if actual_mode & 0o777 != expected_mode {
        return Err(PermissionIssue::TooPermissive {
            path,
            actual: actual_mode & 0o777,
            expected: expected_mode,
        });
    }
    Ok(())
}

#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SecretString(String);

impl SecretString {
    pub fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }
    pub fn expose_for_test(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for SecretString {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("SecretString([REDACTED])")
    }
}

impl fmt::Display for SecretString {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("[REDACTED]")
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Redacted<T>(pub T);

impl<T> fmt::Display for Redacted<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("[REDACTED]")
    }
}

pub fn redact(input: &str) -> String {
    let mut output = String::with_capacity(input.len());
    for token in input.split_whitespace() {
        let lower = token.to_ascii_lowercase();
        let redacted = lower.contains("token=")
            || lower.contains("password=")
            || lower.contains("passphrase=")
            || lower.contains("private_key=")
            || lower.contains("secret=");
        if !output.is_empty() {
            output.push(' ');
        }
        output.push_str(if redacted { "[REDACTED]" } else { token });
    }
    output
}

pub fn redact_secret(input: &str) -> String {
    if input.split_whitespace().count() <= 1 && redact(input) == "[REDACTED]" {
        "[REDACTED]".to_string()
    } else {
        redact(input)
    }
}

pub fn is_secure_dir_mode(mode: u32) -> bool {
    mode & 0o777 == SECURE_DIR_MODE
}
pub fn is_secure_file_mode(mode: u32) -> bool {
    mode & 0o777 == SECURE_FILE_MODE
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_safe() {
        let cfg = AppConfig::new("/tmp/sterm-test");
        assert!(!cfg.transport.public_tcp_enabled);
        assert!(cfg.log_policy.redact_secrets);
        assert!(!cfg.log_policy.include_terminal_contents);
        cfg.validate().unwrap();
    }

    #[test]
    fn rejects_public_tcp_without_override() {
        let mut cfg = AppConfig::new("/tmp/sterm-test");
        cfg.transport.public_tcp_enabled = true;
        assert_eq!(cfg.validate(), Err(ConfigError::PublicTcpDisabledByDefault));
    }

    #[test]
    fn redacts_secret_like_values() {
        assert_eq!(redact_secret("auth_token=<fixture>"), "[REDACTED]");
        assert_eq!(
            redact("connect token=<fixture> ok password=<fixture>"),
            "connect [REDACTED] ok [REDACTED]"
        );
        assert_eq!(
            format!("{:?}", SecretString::new("abc")),
            "SecretString([REDACTED])"
        );
    }

    #[test]
    fn checks_secure_modes() {
        assert!(is_secure_dir_mode(0o700));
        assert!(is_secure_file_mode(0o600));
        assert!(!is_secure_dir_mode(0o755));
        assert!(!is_secure_file_mode(0o644));
    }

    #[test]
    fn validates_exact_modes() {
        assert!(validate_mode("/tmp/a", 0o700, 0o700).is_ok());
        assert!(matches!(
            validate_mode("/tmp/a", 0o755, 0o700),
            Err(PermissionIssue::TooPermissive { .. })
        ));
    }
}
