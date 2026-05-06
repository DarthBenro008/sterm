const socket = @import("socket.zig");
const auth = @import("auth.zig");

pub fn run(writer: anytype) !void {
    try writer.print(
        "{{\"version\":\"0.1.0\",\"socket\":\"{s}\",\"socket_mode\":\"0600\",\"parent_dir_mode\":\"0700\",\"sqlite\":\"scaffold\",\"pty\":\"scaffold\",\"vt\":\"mock\",\"recent_errors\":[]}}\n",
        .{socket.default_socket_path},
    );
}

test "doctor uses private socket and token modes" {
    try @import("std").testing.expectEqual(@as(u16, 0o600), socket.socket_mode);
    try @import("std").testing.expectEqual(@as(u16, 0o600), auth.auth_token_mode);
}
