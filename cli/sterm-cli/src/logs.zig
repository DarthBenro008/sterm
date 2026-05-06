const auth = @import("auth.zig");

pub fn run(writer: anytype) !void {
    try writer.print("{{\"log\":\"{s}\"}}\n", .{auth.redact("recent errors: none")});
}
