const std = @import("std");
const cli = @import("cli.zig");
const daemon = @import("daemon.zig");
const notify = @import("notify.zig");
const process = @import("process.zig");
const protocol = @import("protocol.zig");
const pty = @import("pty.zig");
const runtime = @import("runtime.zig");
const security = @import("security.zig");
const session = @import("session.zig");
const socket = @import("socket.zig");
const storage = @import("storage.zig");
const transport = @import("transport.zig");
const transport_mode = @import("transport_mode.zig");
const vt = @import("vt.zig");

test "protocol fixtures validate against shared fixture contracts" {
    try protocol.validateAllFixtures(std.testing.allocator);
}

test "transport header validates production frame contract" {
    var header: [transport.header_len]u8 = undefined;
    try transport.encodeHeader(&header, 256);
    const decoded = try transport.decodeHeader(&header);
    try std.testing.expectEqual(@as(u16, transport.wire_version), decoded.wire);
    try std.testing.expectEqual(@as(u16, transport.protocol_wire_version), decoded.protocol_version);
    try std.testing.expectEqual(@as(u32, 256), decoded.payload_len);
    try transport.negotiate(transport.protocol_wire_version, transport.protocol_wire_version);
    try std.testing.expectError(transport.TransportError.UnsupportedProtocolVersion, transport.negotiate(99, transport.protocol_wire_version));
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
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "daemon: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "listener: unix-socket") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{"status"}, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "runtime: configured") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "multi-client:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "agent-detection:") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{"doctor"}, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "\"socket_mode\":\"0600\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "\"roaming_transport\"") != null);

    output.clearRetainingCapacity();
    try cli.runArgs(&.{ "workspace", "list" }, &output.writer, &errors.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "state store configured") != null);

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

test "runtime, daemon, storage, process, and pty foundations are production-shaped" {
    var paths = try runtime.RuntimePaths.init(std.testing.allocator, "/home/alice");
    defer paths.deinit();
    try paths.validate();
    try std.testing.expectEqualStrings("/home/alice/.sterm/sterm.sock", paths.socket_path);

    try (daemon.DaemonPlan{}).validate();
    try (storage.StateStorePlan{}).validate();
    try (process.ProcessPlan{ .command = "bash" }).validate();
    try (pty.PtyPlan{ .cwd = "/home/alice/project", .rows = 40, .cols = 120 }).validate();
    try std.testing.expect((process.SupervisorPlan{}).isProductionBoundary());
}

test "VT adapter boundary validates sizes and gates missing libghostty honestly" {
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
    try std.testing.expectEqualStrings("contract-local", title);

    try adapter.destroy(pane_id);
    try std.testing.expect(mock.destroyed);

    try std.testing.expectError(vt.AdapterError.InvalidSize, adapter.resize(pane_id, .{ .rows = 0, .cols = 120 }));
    try std.testing.expectError(vt.AdapterError.Unsupported, adapter.write("pane_missing", "x"));
    try std.testing.expectEqualStrings("libghostty-vt-unavailable", vt.productionVtStatus());
    try std.testing.expectError(vt.ghostty_adapter.GhosttyError.LibghosttyUnavailable, vt.requireProductionVt());
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
        "output_journals",
        "agent_templates",
        "client_sessions",
        "protocol_version",
        "migration_state",
    }) |entity| {
        try std.testing.expect(storage.hasInitialSchemaEntity(entity));
    }
    try std.testing.expect(!(storage.StateStorePlan{}).sqlite_available);
}

test "multi-client, roaming transport, and agent detection contracts are explicit" {
    const first = session.decideAttach(.{ .client_id = "client_a", .workspace_id = "ws_01" });
    try std.testing.expect(first.accepted);

    const conflict = session.decideAttach(.{ .client_id = "client_b", .workspace_id = "ws_01", .existing_writer = "client_a" });
    try std.testing.expect(!conflict.accepted);

    const observer = session.decideAttach(.{
        .client_id = "client_b",
        .workspace_id = "ws_01",
        .requested_mode = .read_only_observer,
        .conflict_policy = .read_only_observers,
        .existing_writer = "client_a",
    });
    try std.testing.expect(observer.accepted);

    try transport_mode.TransportOffer.roaming(60000).validate();
    try std.testing.expectError(transport_mode.TransportModeError.MissingSshControl, (transport_mode.TransportOffer{
        .stream = .roaming_udp,
        .encryption = .noise_xk,
        .requires_ssh_control = false,
        .udp_port = 60000,
    }).validate());

    const detection = notify.detect(.{
        .pane_id = "pane_01",
        .process_command = "claude",
        .output_tail = "Do you want to proceed?",
    });
    try std.testing.expectEqual(notify.AgentKind.claude, detection.kind);
    try std.testing.expectEqual(notify.AgentStatus.needs_approval, detection.status);
    try std.testing.expectEqual(notify.DetectionConfidence.high, detection.confidence);
}
