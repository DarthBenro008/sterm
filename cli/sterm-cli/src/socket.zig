const std = @import("std");

pub const default_socket_path = "~/.sterm/sterm.sock";
pub const socket_mode: u16 = 0o600;
pub const parent_dir_mode: u16 = 0o700;

pub const SocketError = error{
    EmptySocketPath,
    PublicTcpDisabled,
    InvalidMode,
    PathTooLong,
};

pub const UnixSocketPlan = struct {
    path: []const u8 = default_socket_path,
    mode: u16 = socket_mode,
    parent_mode: u16 = parent_dir_mode,
    unlink_stale_socket: bool = true,
    public_tcp: bool = false,

    pub fn validate(plan: UnixSocketPlan) SocketError!void {
        if (plan.path.len == 0) return SocketError.EmptySocketPath;
        if (plan.path.len > 107) return SocketError.PathTooLong;
        if (plan.mode != socket_mode or plan.parent_mode != parent_dir_mode) return SocketError.InvalidMode;
        if (plan.public_tcp and !isPublicTcpAllowedByDefault()) return SocketError.PublicTcpDisabled;
    }
};

pub fn isPublicTcpAllowedByDefault() bool {
    return false;
}

pub fn acceptsPublicTcpByDefault() bool {
    return isPublicTcpAllowedByDefault();
}

test "socket defaults are private" {
    try std.testing.expect(!isPublicTcpAllowedByDefault());
    try std.testing.expectEqual(@as(u16, 0o600), socket_mode);
    try std.testing.expectEqual(@as(u16, 0o700), parent_dir_mode);
    try (UnixSocketPlan{}).validate();
    try std.testing.expectError(SocketError.PublicTcpDisabled, (UnixSocketPlan{ .public_tcp = true }).validate());
}
