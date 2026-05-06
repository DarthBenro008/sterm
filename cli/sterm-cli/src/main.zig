const std = @import("std");
const cli = @import("cli.zig");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stderr_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);

    const result = cli.run(init, &stdout_writer.interface, &stderr_writer.interface);
    stdout_writer.interface.flush() catch {};
    stderr_writer.interface.flush() catch {};
    try result;
}
