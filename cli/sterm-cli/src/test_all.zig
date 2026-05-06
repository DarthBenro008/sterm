const std = @import("std");
const cli = @import("cli.zig");
const protocol = @import("protocol.zig");
const security = @import("security.zig");
const socket = @import("socket.zig");
const storage = @import("storage.zig");
const vt = @import("vt.zig");

test "protocol fixtures validate against shared fixture contracts" {
    try protocol.validateAllFixtures(std.testing.allocator);
}

test "CLI exposes required command surface" {
    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    var errors = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer errors.deinit();

    try cli.runArgs(&.{"version"}, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "sterm 0.1.0") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{"daemon"}, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "unix-only") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{"status"}, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "offline (scaffold)") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{"doctor"}, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "doctor: ok") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "workspace", "list" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "workspace list") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "workspace", "create", "agents", "/tmp/project" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "name=agents") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "pane", "create", "ws_01", "bash" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "workspace_id=ws_01") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "pane", "write", "pane_01", "hello" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "bytes=5") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "pane", "resize", "pane_01", "40", "120" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "rows=40 cols=120") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "logs", "pane_01" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "logs: pane pane_01") != null);
}

test "security and socket defaults are remote-safe" {
    try std.testing.expect(security.isPrivateDirMode(0o700));
    try std.testing.expect(security.isSecretFileMode(0o600));
    try std.testing.expect(!socket.acceptsPublicTcpByDefault());
    try std.testing.expect(!security.allow_plaintext_password_storage);
    try std.testing.expect(!security.allow_root_service_default);
    try std.testing.expect(security.redact_secrets_in_logs);
}

test "VT adapter boundary is mock-only and validates sizes" {
    var mock = vt.MockAdapter{};
    const adapter = mock.adapter();

    const pane_id = try adapter.createPane(.{ .rows = 24, .cols = 80 });
    try std.testing.expectEqualStrings("pane_mock_01", pane_id);

    const feed = try adapter.feed(pane_id, "remote output");
    try std.testing.expectEqual(@as(usize, 13), feed.bytes_written);

    const write = try adapter.write(pane_id, "hello");
    try std.testing.expectEqual(@as(usize, 5), write.bytes_written);

    const input = try adapter.input(pane_id, "bun test\n");
    try std.testing.expectEqual(@as(usize, 9), input.bytes_written);

    try adapter.resize(pane_id, .{ .rows = 40, .cols = 120 });
    const snapshot = try adapter.snapshot(pane_id);
    try std.testing.expectEqual(@as(u16, 40), snapshot.rows);
    try std.testing.expectEqual(@as(u16, 120), snapshot.cols);
    try std.testing.expectEqualStrings("mock-cell-grid:v1", snapshot.cells);

    const dirty_regions = try adapter.dirtyRegions(pane_id);
    try std.testing.expectEqual(@as(usize, 1), dirty_regions.len);
    try std.testing.expectEqual(@as(u16, 120), dirty_regions[0].col_end);

    const chunk = try adapter.scrollback(pane_id, .{ .start_line = 31800, .max_lines = 2 });
    try std.testing.expectEqual(@as(u64, 31800), chunk.start_line);
    try std.testing.expectEqual(@as(usize, 2), chunk.lines.len);

    const cursor = try adapter.cursor(pane_id);
    try std.testing.expect(cursor.visible);

    const title = try adapter.title(pane_id);
    try std.testing.expectEqualStrings("mock-local", title);

    try adapter.destroy(pane_id);
    try std.testing.expect(mock.destroyed);

    try std.testing.expectError(vt.AdapterError.InvalidSize, adapter.resize(pane_id, .{ .rows = 0, .cols = 120 }));
    try std.testing.expectError(vt.AdapterError.Unsupported, adapter.write("pane_missing", "x"));
}

test "storage migrations define initial schema honestly" {
    try std.testing.expectEqual(@as(u32, 1), storage.current_schema_version);
    try std.testing.expectEqual(@as(usize, 1), storage.migrations.len);
    try std.testing.expect(storage.isCurrent(1));
    for ([_][]const u8{
        "workspaces",
        "tabs",
        "split_trees",
        "panes",
        "process_metadata",
        "notification_history",
        "scrollback_chunks",
        "client_sessions",
        "protocol_version",
        "migration_state",
    }) |entity| {
        try std.testing.expect(storage.hasInitialSchemaEntity(entity));
    }
}
