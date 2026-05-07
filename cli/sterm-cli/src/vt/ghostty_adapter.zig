const std = @import("std");
const build_options = @import("build_options");
const ghostty_vt = if (build_options.libghostty_vt) @import("ghostty-vt") else struct {};

pub const integration_status = if (build_options.libghostty_vt)
    "libghostty-vt-linked"
else
    "libghostty-vt-unavailable";
pub const compiled = build_options.libghostty_vt;

pub const GhosttyError = error{
    LibghosttyUnavailable,
};

pub fn adapterName() []const u8 {
    return "libghostty-vt-adapter-gate";
}

pub fn requireAvailable() GhosttyError!void {
    if (!compiled) return GhosttyError.LibghosttyUnavailable;
}

pub fn unavailableReason() []const u8 {
    if (compiled) {
        return "libghostty-vt is linked into this build and owns server-side VT state";
    }
    return "libghostty-vt is not linked into this build; build with -Dghostty-vt=true to enable the production server-side VT adapter";
}

pub fn smokePlainString(allocator: std.mem.Allocator) ![]const u8 {
    try requireAvailable();

    var terminal: ghostty_vt.Terminal = try .init(allocator, .{
        .cols = 16,
        .rows = 4,
    });
    defer terminal.deinit(allocator);

    try terminal.printString("ghostty-vt");
    return try terminal.plainString(allocator);
}
