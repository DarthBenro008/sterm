//! Remote bootstrap command planning. This crate only plans commands; it does not execute them.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BootstrapPlan {
    pub home_dir: PathBuf,
    pub install_dir: PathBuf,
    pub bin_dir: PathBuf,
    pub state_dir: PathBuf,
    pub log_dir: PathBuf,
    pub agent_binary: PathBuf,
    pub installed_binary: PathBuf,
    pub socket_path: PathBuf,
    pub commands: Vec<PlannedCommand>,
}

impl BootstrapPlan {
    pub fn for_user(home_dir: impl Into<PathBuf>, agent_binary: impl Into<PathBuf>) -> Self {
        let home_dir = home_dir.into();
        let base = home_dir.join(".sterm");
        let bin_dir = base.join("bin");
        let state_dir = base.join("state");
        let log_dir = base.join("logs");
        let socket_path = base.join("sterm.sock");
        let agent_binary = agent_binary.into();
        let installed_binary = bin_dir.join("sterm-cli");
        let commands = vec![
            PlannedCommand::new(
                "mkdir",
                vec![
                    "-p".into(),
                    bin_dir.display().to_string(),
                    state_dir.display().to_string(),
                    log_dir.display().to_string(),
                ],
            ),
            PlannedCommand::new("chmod", vec!["700".into(), base.display().to_string()]),
            PlannedCommand::new("chmod", vec!["700".into(), state_dir.display().to_string()]),
            PlannedCommand::new("chmod", vec!["700".into(), log_dir.display().to_string()]),
            PlannedCommand::new(
                "install",
                vec![
                    "-m".into(),
                    "755".into(),
                    agent_binary.display().to_string(),
                    installed_binary.display().to_string(),
                ],
            ),
            PlannedCommand::new(
                installed_binary.display().to_string(),
                vec!["version".into()],
            ),
            PlannedCommand::new(
                installed_binary.display().to_string(),
                vec![
                    "daemon".into(),
                    "--socket".into(),
                    socket_path.display().to_string(),
                ],
            ),
        ];
        Self {
            home_dir,
            install_dir: base,
            bin_dir,
            state_dir,
            log_dir,
            agent_binary,
            installed_binary,
            socket_path,
            commands,
        }
    }

    pub fn validate(&self) -> Result<(), BootstrapError> {
        for command in &self.commands {
            if command.program.trim().is_empty() {
                return Err(BootstrapError::EmptyProgram);
            }
            let joined =
                format!("{} {}", command.program, command.args.join(" ")).to_ascii_lowercase();
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
            if joined.contains("rm -rf") || joined.contains("curl | sh") {
                return Err(BootstrapError::DestructiveOperation);
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
    DestructiveOperation,
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
            PathBuf::from("/home/alice/.sterm/sterm.sock")
        );
        assert_eq!(
            plan.installed_binary,
            PathBuf::from("/home/alice/.sterm/bin/sterm-cli")
        );
        assert!(plan
            .commands
            .iter()
            .any(|cmd| cmd.program == "install" && cmd.args.contains(&"755".to_string())));
        plan.validate().unwrap();
    }

    #[test]
    fn bootstrap_plan_is_idempotent_and_checks_version_before_daemon() {
        let plan = BootstrapPlan::for_user("/home/alice", "/tmp/sterm-cli");
        assert_eq!(plan.commands[0].program, "mkdir");
        assert!(plan.commands[0].args.contains(&"-p".to_string()));
        let version_index = plan
            .commands
            .iter()
            .position(|cmd| cmd.args.len() == 1 && cmd.args[0] == "version")
            .unwrap();
        let daemon_index = plan
            .commands
            .iter()
            .position(|cmd| cmd.args.first().map(String::as_str) == Some("daemon"))
            .unwrap();
        assert!(version_index < daemon_index);
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

    #[test]
    fn rejects_destructive_bootstrap_commands() {
        let mut plan = BootstrapPlan::for_user("/home/alice", "/usr/local/bin/sterm-cli");
        plan.commands
            .push(PlannedCommand::new("rm", vec!["-rf".into(), "/".into()]));
        assert_eq!(plan.validate(), Err(BootstrapError::DestructiveOperation));
    }
}
