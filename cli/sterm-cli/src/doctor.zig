const socket = @import("socket.zig");
const auth = @import("auth.zig");
const storage = @import("storage.zig");
const process = @import("process.zig");
const vt = @import("vt.zig");
const session = @import("session.zig");
const transport_mode = @import("transport_mode.zig");
const notify = @import("notify.zig");

pub fn run(writer: anytype) !void {
    const state_plan = storage.StateStorePlan{};
    try writer.print(
        "{{\"version\":\"0.1.0\",\"socket\":\"{s}\",\"socket_mode\":\"0600\",\"parent_dir_mode\":\"0700\",\"state_dir\":\"{s}\",\"sqlite\":\"{s}\",\"pty\":\"boundary-ready\",\"supervisor\":\"{s}\",\"vt\":\"{s}\",\"multi_client\":\"{s}\",\"roaming_transport\":\"{s}\",\"agent_detection\":\"{s}\",\"recent_errors\":[\"{s}\"]}}\n",
        .{
            socket.default_socket_path,
            state_plan.state_dir,
            storage.sqlite.integration_status,
            if ((process.SupervisorPlan{}).isProductionBoundary()) "per-pane" else "invalid",
            vt.productionVtStatus(),
            session.status(),
            transport_mode.status(),
            notify.status(),
            vt.ghostty_adapter.unavailableReason(),
        },
    );
}

test "doctor uses private socket and token modes" {
    try @import("std").testing.expectEqual(@as(u16, 0o600), socket.socket_mode);
    try @import("std").testing.expectEqual(@as(u16, 0o600), auth.auth_token_mode);
    try @import("std").testing.expect(!storage.sqlite.compiled);
}
