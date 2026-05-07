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

pub fn shouldRedact(value: []const u8) bool {
    return containsInsensitive(value, "token") or
        containsInsensitive(value, "password") or
        containsInsensitive(value, "passphrase") or
        containsInsensitive(value, "private_key") or
        containsInsensitive(value, "secret");
}

pub fn redactedOrOriginal(value: []const u8) []const u8 {
    return if (shouldRedact(value)) "[REDACTED]" else value;
}

fn containsInsensitive(value: []const u8, needle: []const u8) bool {
    var index: usize = 0;
    while (index + needle.len <= value.len) : (index += 1) {
        var matched = true;
        for (needle, 0..) |expected, offset| {
            const actual = value[index + offset];
            if (toLower(actual) != expected) {
                matched = false;
                break;
            }
        }
        if (matched) return true;
    }
    return false;
}

fn toLower(value: u8) u8 {
    if (value >= 'A' and value <= 'Z') return value + 32;
    return value;
}

test "security redacts secret-like values" {
    try @import("std").testing.expectEqualStrings("[REDACTED]", redactedOrOriginal("auth_token=abc"));
    try @import("std").testing.expectEqualStrings("[REDACTED]", redactedOrOriginal("PASSWORD: abc"));
    try @import("std").testing.expectEqualStrings("protocol_version=1", redactedOrOriginal("protocol_version=1"));
}
