const std = @import("std");
const cli = @import("cli.zig");

pub fn main() !void {
    var stdout = std.fs.File.stdout().deprecatedWriter();
    var stderr = std.fs.File.stderr().deprecatedWriter();
    try cli.run(&stdout, &stderr);
}
