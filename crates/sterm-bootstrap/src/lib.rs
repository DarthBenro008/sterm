//! Remote bootstrap command planning. This crate only plans commands; it does not execute them.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BootstrapPlan {
    pub home_dir: PathBuf,
    pub agent_binary: PathBuf,
    pub socket_path: PathBuf,
    pub commands: Vec<PlannedCommand>,
}

impl BootstrapPlan {
    pub fn for_user(home_dir: impl Into<PathBuf>, agent_binary: impl Into<PathBuf>) -> Self {
        let home_dir = home_dir.into();
        let base = home_dir.join(".sterm");
        let socket_path = base.join("agent.sock");
        let agent_binary = agent_binary.into();
        let commands = vec![
            PlannedCommand::new("mkdir", vec!["-p".into(), base.display().to_string()]),
            PlannedCommand::new("chmod", vec!["700".into(), base.display().to_string()]),
            PlannedCommand::new(
                agent_binary.display().to_string(),
                vec![
                    "daemon".into(),
                    "--socket".into(),
                    socket_path.display().to_string(),
                ],
            ),
        ];
        Self {
            home_dir,
            agent_binary,
            socket_path,
            commands,
        }
    }

    pub fn validate(&self) -> Result<(), BootstrapError> {
        for command in &self.commands {
            if command.program.trim().is_empty() {
                return Err(BootstrapError::EmptyProgram);
            }
            let joined = command.args.join(" ").to_ascii_lowercase();
            if joined.contains("password")
                || joined.contains("passphrase")
                || joined.contains("private_key")
                || joined.contains("token")
            {
                return Err(BootstrapError::SecretInCommand);
            }
            if joined.contains("loginctl enable-linger")
                || joined.contains("systemctl enable")
                || joined.contains("sudo ")
            {
                return Err(BootstrapError::PrivilegedOperation);
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlannedCommand {
    pub program: String,
    pub args: Vec<String>,
}

impl PlannedCommand {
    pub fn new(program: impl Into<String>, args: Vec<String>) -> Self {
        Self {
            program: program.into(),
            args,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BootstrapError {
    EmptyProgram,
    SecretInCommand,
    PrivilegedOperation,
}
impl fmt::Display for BootstrapError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}
impl std::error::Error for BootstrapError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plans_unix_socket_bootstrap_without_privileged_operations() {
        let plan = BootstrapPlan::for_user("/home/alice", "/usr/local/bin/sterm-cli");
        assert_eq!(
            plan.socket_path,
            PathBuf::from("/home/alice/.sterm/agent.sock")
        );
        assert!(plan
            .commands
            .iter()
            .any(|cmd| cmd.program == "chmod" && cmd.args == ["700", "/home/alice/.sterm"]));
        plan.validate().unwrap();
    }

    #[test]
    fn rejects_secret_bearing_commands() {
        let mut plan = BootstrapPlan::for_user("/home/alice", "/usr/local/bin/sterm-cli");
        plan.commands
            .push(PlannedCommand::new("echo", vec!["token=<fixture>".into()]));
        assert_eq!(plan.validate(), Err(BootstrapError::SecretInCommand));
    }

    #[test]
    fn rejects_privileged_operations() {
        let mut plan = BootstrapPlan::for_user("/home/alice", "/usr/local/bin/sterm-cli");
        plan.commands.push(PlannedCommand::new(
            "sudo",
            vec!["systemctl enable sterm".into()],
        ));
        assert_eq!(plan.validate(), Err(BootstrapError::PrivilegedOperation));
    }
}
