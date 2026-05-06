pub const ghostty_adapter = @import("ghostty_adapter.zig");
pub const snapshot = @import("snapshot.zig");
pub const diff = @import("diff.zig");
pub const scrollback = @import("scrollback.zig");

pub const TerminalAdapter = struct {
    rows: u16,
    cols: u16,
    title_text: []const u8 = "mock-local",
    destroyed: bool = false,

    pub fn create(rows: u16, cols: u16) TerminalAdapter {
        return .{ .rows = rows, .cols = cols };
    }

    pub fn resize(self: *TerminalAdapter, rows: u16, cols: u16) void {
        self.rows = rows;
        self.cols = cols;
    }

    pub fn feed(_: *TerminalAdapter, bytes: []const u8) usize {
        return bytes.len;
    }

    pub fn input(_: *TerminalAdapter, bytes: []const u8) usize {
        return bytes.len;
    }

    pub fn snapshot(self: TerminalAdapter) snapshot.Snapshot {
        return snapshot.Snapshot{
            .pane_id = "pane_mock_01",
            .seq = 1,
            .rows = self.rows,
            .cols = self.cols,
            .cells = "mock-cell-grid:v1",
        };
    }

    pub fn dirtyRegions(_: TerminalAdapter) []const diff.DirtyRegion {
        return &.{.{ .row = 0, .col_start = 0, .col_end = 120 }};
    }

    pub fn scrollback(_: TerminalAdapter) scrollback.ScrollbackWindow {
        return .{ .available_lines = 3, .window_start = 0, .window_lines = 3 };
    }

    pub fn cursor(_: TerminalAdapter) snapshot.Cursor {
        return .{ .row = 0, .col = 0, .visible = true, .style = "block" };
    }

    pub fn title(self: TerminalAdapter) []const u8 {
        return self.title_text;
    }

    pub fn destroy(self: *TerminalAdapter) void {
        self.destroyed = true;
    }
};

test "vt adapter boundary is mock only in first wave" {
    var adapter = TerminalAdapter.create(40, 120);
    try @import("std").testing.expectEqual(@as(usize, 5), adapter.feed("hello"));
    try @import("std").testing.expectEqual(@as(usize, 5), adapter.input("input"));
    adapter.resize(50, 100);
    try @import("std").testing.expectEqual(@as(u16, 50), adapter.rows);
    try @import("std").testing.expectEqual(@as(u16, 50), adapter.snapshot().rows);
    try @import("std").testing.expectEqual(@as(usize, 1), adapter.dirtyRegions().len);
    try @import("std").testing.expectEqual(@as(u64, 3), adapter.scrollback().available_lines);
    try @import("std").testing.expect(adapter.cursor().visible);
    try @import("std").testing.expectEqualStrings("mock-local", adapter.title());
    adapter.destroy();
    try @import("std").testing.expect(adapter.destroyed);
}
