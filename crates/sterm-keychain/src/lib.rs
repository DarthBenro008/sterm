//! Keychain abstraction. Implementations return secrets at runtime but never persist them in app config.

use std::collections::HashMap;
use std::fmt;
use sterm_shared::SecretString;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct SecretRef {
    pub service: String,
    pub account: String,
}

impl SecretRef {
    pub fn new(service: impl Into<String>, account: impl Into<String>) -> Self {
        Self {
            service: service.into(),
            account: account.into(),
        }
    }

    pub fn validate(&self) -> Result<(), KeychainError> {
        if self.service.trim().is_empty() || self.account.trim().is_empty() {
            return Err(KeychainError::InvalidReference);
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SecretStorePolicy {
    pub require_user_approval: bool,
    pub allow_plaintext_export: bool,
}

impl Default for SecretStorePolicy {
    fn default() -> Self {
        Self {
            require_user_approval: true,
            allow_plaintext_export: false,
        }
    }
}

pub trait Keychain {
    fn get_secret(&self, reference: &SecretRef) -> Result<Option<SecretString>, KeychainError>;
}

#[derive(Default)]
pub struct MemoryKeychain {
    entries: HashMap<SecretRef, SecretString>,
}

impl MemoryKeychain {
    pub fn insert_for_test(&mut self, reference: SecretRef, secret: SecretString) {
        self.entries.insert(reference, secret);
    }
}

impl Keychain for MemoryKeychain {
    fn get_secret(&self, reference: &SecretRef) -> Result<Option<SecretString>, KeychainError> {
        Ok(self.entries.get(reference).cloned())
    }
}

impl fmt::Debug for MemoryKeychain {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("MemoryKeychain")
            .field("entries", &self.entries.len())
            .finish()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum KeychainError {
    BackendUnavailable,
    PermissionDenied,
    InvalidReference,
    PlaintextExportDisabled,
}
impl fmt::Display for KeychainError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}
impl std::error::Error for KeychainError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn debug_does_not_print_secret_values() {
        let mut keychain = MemoryKeychain::default();
        keychain.insert_for_test(
            SecretRef::new("sterm", "alice"),
            SecretString::new("<fixture-secret>"),
        );
        let debug = format!("{:?}", keychain);
        assert!(debug.contains("entries"));
        assert!(!debug.contains("<fixture-secret>"));
    }

    #[test]
    fn retrieves_secret_by_reference() {
        let mut keychain = MemoryKeychain::default();
        let reference = SecretRef::new("sterm", "alice");
        reference.validate().unwrap();
        keychain.insert_for_test(reference.clone(), SecretString::new("value"));
        assert_eq!(
            keychain
                .get_secret(&reference)
                .unwrap()
                .unwrap()
                .expose_for_test(),
            "value"
        );
    }

    #[test]
    fn secret_store_policy_blocks_plaintext_export_by_default() {
        let policy = SecretStorePolicy::default();
        assert!(policy.require_user_approval);
        assert!(!policy.allow_plaintext_export);
        assert_eq!(
            SecretRef::new("", "alice").validate(),
            Err(KeychainError::InvalidReference)
        );
    }
}
