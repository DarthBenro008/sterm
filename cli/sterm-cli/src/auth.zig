const std = @import("std");

pub const auth_token_path = "~/.sterm/state/auth_token";
pub const auth_token_mode: u16 = 0o600;
pub const token_bytes: usize = 32;
pub const token_hex_len: usize = token_bytes * 2;

pub const TokenPlan = struct {
    path: []const u8 = auth_token_path,
    mode: u16 = auth_token_mode,
    bytes: usize = token_bytes,

    pub fn validate(plan: TokenPlan) !void {
        if (plan.path.len == 0) return error.EmptyTokenPath;
        if (plan.mode != auth_token_mode) return error.InsecureTokenMode;
        if (plan.bytes < token_bytes) return error.WeakToken;
    }
};

pub fn fillTokenHex(random: std.Random, out: *[token_hex_len]u8) void {
    var raw: [token_bytes]u8 = undefined;
    random.bytes(&raw);
    out.* = std.fmt.bytesToHex(raw, .lower);
}

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
    try (TokenPlan{}).validate();
}

test "auth token generator produces fixed-length hex tokens" {
    var token: [token_hex_len]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x515445524d);
    fillTokenHex(prng.random(), &token);
    try std.testing.expectEqual(@as(usize, token_hex_len), token.len);
    for (token) |char| {
        try std.testing.expect(std.ascii.isHex(char));
    }
}
