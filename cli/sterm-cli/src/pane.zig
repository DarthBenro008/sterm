const std = @import("std");

pub const Pane = struct {
    id: []const u8,
    workspace_id: []const u8,
    tab_id: []const u8,
    pty_id: []const u8,
    vt_id: []const u8,
    rows: u16,
    cols: u16,
};

pub fn dispatch(args: anytype, writer: anytype) !void {
    const sub = args.next() orelse "help";
    if (std.mem.eql(u8, sub, "create")) {
        try writer.writeAll("{\"pane\":{\"id\":\"pane_mock\",\"status\":\"running\"}}\n");
    } else if (std.mem.eql(u8, sub, "write")) {
        try writer.writeAll("{\"pane_write\":\"accepted\"}\n");
    } else if (std.mem.eql(u8, sub, "resize")) {
        try writer.writeAll("{\"pane_resize\":\"accepted\"}\n");
    } else {
        try writer.writeAll("usage: sterm-cli pane <create|write|resize>\n");
    }
}

test "pane references pty and vt ownership" {
    const p = Pane{
        .id = "pane_01",
        .workspace_id = "ws_01",
        .tab_id = "tab_01",
        .pty_id = "pty_01",
        .vt_id = "vt_01",
        .rows = 40,
        .cols = 120,
    };
    try std.testing.expectEqualStrings("pty_01", p.pty_id);
}
