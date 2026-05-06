pub const private_dir_mode: u16 = 0o700;
pub const secret_file_mode: u16 = 0o600;
pub const private_dir_mode_octal = "0700";
pub const secret_file_mode_octal = "0600";

pub const public_tcp_listener_default = false;
pub const allow_plaintext_password_storage = false;
pub const allow_root_service_default = false;
pub const redact_secrets_in_logs = true;

pub fn isPrivateDirMode(mode: u16) bool {
    return (mode & 0o777) == private_dir_mode;
}

pub fn isSecretFileMode(mode: u16) bool {
    return (mode & 0o777) == secret_file_mode;
}
