pub const default_socket_path = "~/.sterm/sterm.sock";
pub const socket_mode: u16 = 0o600;
pub const parent_dir_mode: u16 = 0o700;

pub fn isPublicTcpAllowedByDefault() bool {
    return false;
}

pub fn acceptsPublicTcpByDefault() bool {
    return isPublicTcpAllowedByDefault();
}

test "socket defaults are private" {
    try @import("std").testing.expect(!isPublicTcpAllowedByDefault());
    try @import("std").testing.expectEqual(@as(u16, 0o600), socket_mode);
    try @import("std").testing.expectEqual(@as(u16, 0o700), parent_dir_mode);
}
