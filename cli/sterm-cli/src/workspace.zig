const std = @import("std");

pub const Workspace = struct {
    id: []const u8,
    name: []const u8,
    root_dir: []const u8,
    active_tab_id: []const u8,
};

pub fn dispatch(args: anytype, writer: anytype) !void {
    const sub = args.next() orelse "list";
    if (std.mem.eql(u8, sub, "list")) {
        try writer.writeAll("{\"workspaces\":[]}\n");
    } else if (std.mem.eql(u8, sub, "create")) {
        try writer.writeAll("{\"workspace\":{\"id\":\"ws_mock\",\"name\":\"mock-local\"}}\n");
    } else {
        try writer.writeAll("usage: sterm-cli workspace <list|create>\n");
    }
}

test "workspace model carries layout root" {
    const ws = Workspace{
        .id = "ws_01",
        .name = "agent-runner",
        .root_dir = "/home/ubuntu/projects/app",
        .active_tab_id = "tab_01",
    };
    try std.testing.expectEqualStrings("tab_01", ws.active_tab_id);
}
