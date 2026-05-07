const std = @import("std");

pub const protocol_version: u32 = 1;
pub const version = protocol_version;
pub const features = [_][]const u8{
    "pane-diff-v1",
    "scrollback-v1",
    "notifications-v1",
    "auth-token-ref-v1",
    "workspace-ops-v1",
    "health-logs-v1",
    "multi-client-v1",
    "roaming-transport-v1",
    "agent-detection-v1",
};

pub const FrameType = enum {
    hello,
    hello_ack,
    auth,
    workspace_open,
    workspace_close,
    workspace_snapshot,
    pane_create,
    pane_input,
    pane_resize,
    pane_snapshot,
    pane_diff,
    scrollback_chunk,
    notification,
    client_session,
    transport_offer,
    agent_detection,
    health,
    logs,
    error_frame,
};

pub const Fixture = struct {
    path: []const u8,
    message_type: []const u8,
    required_fields: []const []const u8,
};

const hello_fields = [_][]const u8{ "type", "client_version", "protocol_version", "supported_features" };
const hello_ack_fields = [_][]const u8{ "type", "agent_version", "protocol_version", "supported_features" };
const auth_fields = [_][]const u8{ "type", "request_id", "token_ref", "scopes" };
const error_fields = [_][]const u8{ "type", "code", "message", "retryable" };
const health_fields = [_][]const u8{ "type", "status", "protocol_version", "uptime_ms", "checks" };
const logs_fields = [_][]const u8{ "type", "scope", "entries" };
const notification_fields = [_][]const u8{ "type", "pane_id", "level", "reason" };
const client_session_fields = [_][]const u8{ "type", "session_id", "client_id", "workspace_id", "mode", "conflict_policy", "lease_owner", "lease_expires_at" };
const transport_offer_fields = [_][]const u8{ "type", "request_id", "control", "stream", "encryption", "requires_ssh_control", "udp_port", "fallback" };
const agent_detection_fields = [_][]const u8{ "type", "pane_id", "agent", "status", "confidence", "evidence" };
const pane_create_fields = [_][]const u8{ "type", "request_id", "workspace_id", "tab_id", "cwd", "command", "rows", "cols" };
const pane_diff_fields = [_][]const u8{ "type", "pane_id", "seq", "dirty_rows", "cursor" };
const pane_input_fields = [_][]const u8{ "type", "pane_id", "seq", "bytes_base64" };
const pane_resize_fields = [_][]const u8{ "type", "pane_id", "rows", "cols" };
const pane_snapshot_fields = [_][]const u8{ "type", "pane_id", "seq", "rows", "cols", "cursor", "cells", "scrollback" };
const scrollback_chunk_fields = [_][]const u8{ "type", "pane_id", "start_line", "lines", "has_more" };
const workspace_close_fields = [_][]const u8{ "type", "request_id", "workspace_id" };
const workspace_open_fields = [_][]const u8{ "type", "request_id", "name", "root_dir" };
const workspace_snapshot_fields = [_][]const u8{ "type", "machine", "workspace", "tabs", "panes" };

pub const fixtures = [_]Fixture{
    .{ .path = "../../fixtures/protocol/auth.json", .message_type = "auth", .required_fields = &auth_fields },
    .{ .path = "../../fixtures/protocol/error.json", .message_type = "error", .required_fields = &error_fields },
    .{ .path = "../../fixtures/protocol/health.json", .message_type = "health", .required_fields = &health_fields },
    .{ .path = "../../fixtures/protocol/hello.json", .message_type = "hello", .required_fields = &hello_fields },
    .{ .path = "../../fixtures/protocol/hello_ack.json", .message_type = "hello_ack", .required_fields = &hello_ack_fields },
    .{ .path = "../../fixtures/protocol/logs.json", .message_type = "logs", .required_fields = &logs_fields },
    .{ .path = "../../fixtures/protocol/notification.json", .message_type = "notification", .required_fields = &notification_fields },
    .{ .path = "../../fixtures/protocol/client_session.json", .message_type = "client_session", .required_fields = &client_session_fields },
    .{ .path = "../../fixtures/protocol/transport_offer.json", .message_type = "transport_offer", .required_fields = &transport_offer_fields },
    .{ .path = "../../fixtures/protocol/agent_detection.json", .message_type = "agent_detection", .required_fields = &agent_detection_fields },
    .{ .path = "../../fixtures/protocol/pane_create.json", .message_type = "pane_create", .required_fields = &pane_create_fields },
    .{ .path = "../../fixtures/protocol/pane_diff.json", .message_type = "pane_diff", .required_fields = &pane_diff_fields },
    .{ .path = "../../fixtures/protocol/pane_input.json", .message_type = "pane_input", .required_fields = &pane_input_fields },
    .{ .path = "../../fixtures/protocol/pane_resize.json", .message_type = "pane_resize", .required_fields = &pane_resize_fields },
    .{ .path = "../../fixtures/protocol/pane_snapshot.json", .message_type = "pane_snapshot", .required_fields = &pane_snapshot_fields },
    .{ .path = "../../fixtures/protocol/scrollback_chunk.json", .message_type = "scrollback_chunk", .required_fields = &scrollback_chunk_fields },
    .{ .path = "../../fixtures/protocol/workspace_open.json", .message_type = "workspace_open", .required_fields = &workspace_open_fields },
    .{ .path = "../../fixtures/protocol/workspace_close.json", .message_type = "workspace_close", .required_fields = &workspace_close_fields },
    .{ .path = "../../fixtures/protocol/workspace_snapshot.json", .message_type = "workspace_snapshot", .required_fields = &workspace_snapshot_fields },
};

pub const ValidationError = error{
    FixtureRootMustBeObject,
    FixtureTypeMissing,
    FixtureTypeMustBeString,
    FixtureTypeMismatch,
    RequiredFieldMissing,
};

pub fn validateFixture(allocator: std.mem.Allocator, fixture: Fixture) !void {
    const source = try readFixtureFile(allocator, fixture.path);
    defer allocator.free(source);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, source, .{});
    defer parsed.deinit();

    try validateValue(fixture, parsed.value);
}

fn readFixtureFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (comptime @hasDecl(std, "fs")) {
        if (comptime @hasDecl(std.fs, "cwd")) {
            return std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        }
    }

    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
}

pub fn validateValue(fixture: Fixture, value: std.json.Value) ValidationError!void {
    if (value != .object) return ValidationError.FixtureRootMustBeObject;
    const object = value.object;

    const type_value = object.get("type") orelse return ValidationError.FixtureTypeMissing;
    if (type_value != .string) return ValidationError.FixtureTypeMustBeString;
    if (!std.mem.eql(u8, type_value.string, fixture.message_type)) return ValidationError.FixtureTypeMismatch;

    for (fixture.required_fields) |field| {
        if (!object.contains(field)) return ValidationError.RequiredFieldMissing;
    }
}

pub fn validateAllFixtures(allocator: std.mem.Allocator) !void {
    for (fixtures) |fixture| {
        try validateFixture(allocator, fixture);
    }
}

test "shared protocol fixtures are consumed by Zig" {
    try validateAllFixtures(std.testing.allocator);
}
