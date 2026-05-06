const std = @import("std");

pub const auth_token_path = "~/.sterm/state/auth_token";
pub const auth_token_mode: u16 = 0o600;

pub fn redact(value: []const u8) []const u8 {
    if (std.mem.indexOf(u8, value, "token") != null or
        std.mem.indexOf(u8, value, "password") != null or
        std.mem.indexOf(u8, value, "secret") != null)
    {
        return "[REDACTED]";
    }
    return value;
}

test "auth token is private and redacted" {
    try std.testing.expectEqual(@as(u16, 0o600), auth_token_mode);
    try std.testing.expectEqualStrings("[REDACTED]", redact("token=abc"));
}
