const socket = @import("socket.zig");

pub fn run(writer: anytype) !void {
    try writer.print(
        "{{\"daemon\":\"scaffold\",\"socket\":\"{s}\",\"public_tcp\":false}}\n",
        .{socket.default_socket_path},
    );
}
