const std = @import("std");

pub const ClientMode = enum {
    read_write,
    read_only_observer,
};

pub const ConflictPolicy = enum {
    single_writer,
    read_only_observers,
};

pub const AttachRequest = struct {
    client_id: []const u8,
    workspace_id: []const u8,
    requested_mode: ClientMode = .read_write,
    conflict_policy: ConflictPolicy = .single_writer,
    existing_writer: ?[]const u8 = null,
};

pub const AttachDecision = struct {
    accepted: bool,
    granted_mode: ?ClientMode,
    reason: []const u8,
    lease_owner: ?[]const u8,
};

pub fn decideAttach(request: AttachRequest) AttachDecision {
    if (request.client_id.len == 0 or request.workspace_id.len == 0) {
        return reject("missing client or workspace id", request.existing_writer);
    }

    if (request.requested_mode == .read_only_observer) {
        if (request.conflict_policy == .read_only_observers) {
            return .{
                .accepted = true,
                .granted_mode = .read_only_observer,
                .reason = "read-only observer accepted",
                .lease_owner = request.existing_writer,
            };
        }
        return reject("read-only observers are disabled by policy", request.existing_writer);
    }

    if (request.existing_writer) |writer| {
        if (std.mem.eql(u8, writer, request.client_id)) {
            return .{
                .accepted = true,
                .granted_mode = .read_write,
                .reason = "existing writer lease renewed",
                .lease_owner = writer,
            };
        }
        return reject("write lease already held by another client", writer);
    }

    return .{
        .accepted = true,
        .granted_mode = .read_write,
        .reason = "write lease granted",
        .lease_owner = request.client_id,
    };
}

pub fn status() []const u8 {
    return "single-writer with explicit read-only observer policy";
}

fn reject(reason: []const u8, lease_owner: ?[]const u8) AttachDecision {
    return .{
        .accepted = false,
        .granted_mode = null,
        .reason = reason,
        .lease_owner = lease_owner,
    };
}

test "multi-client attach keeps one writer and allows explicit observers" {
    const first = decideAttach(.{ .client_id = "client_a", .workspace_id = "ws_01" });
    try std.testing.expect(first.accepted);
    try std.testing.expectEqual(ClientMode.read_write, first.granted_mode.?);
    try std.testing.expectEqualStrings("client_a", first.lease_owner.?);

    const conflict = decideAttach(.{ .client_id = "client_b", .workspace_id = "ws_01", .existing_writer = "client_a" });
    try std.testing.expect(!conflict.accepted);
    try std.testing.expectEqualStrings("write lease already held by another client", conflict.reason);

    const observer = decideAttach(.{
        .client_id = "client_b",
        .workspace_id = "ws_01",
        .requested_mode = .read_only_observer,
        .conflict_policy = .read_only_observers,
        .existing_writer = "client_a",
    });
    try std.testing.expect(observer.accepted);
    try std.testing.expectEqual(ClientMode.read_only_observer, observer.granted_mode.?);
}
