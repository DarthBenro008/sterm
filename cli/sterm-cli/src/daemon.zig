const socket = @import("socket.zig");
const runtime = @import("runtime.zig");
const storage = @import("storage.zig");
const auth = @import("auth.zig");
const process = @import("process.zig");
const vt = @import("vt.zig");
const session = @import("session.zig");
const transport_mode = @import("transport_mode.zig");
const notify = @import("notify.zig");

pub const DaemonPlan = struct {
    socket_plan: socket.UnixSocketPlan = .{},
    runtime_config: runtime.RuntimeConfig = .{},
    state_store: storage.StateStorePlan = .{},
    token_plan: auth.TokenPlan = .{},
    supervisor: process.SupervisorPlan = .{},
    vt_status: []const u8 = vt.productionVtStatus(),

    pub fn validate(plan: DaemonPlan) !void {
        try plan.socket_plan.validate();
        try plan.runtime_config.validate();
        try plan.state_store.validate();
        try plan.token_plan.validate();
        if (!plan.supervisor.isProductionBoundary()) return error.InvalidSupervisorBoundary;
    }
};

pub fn run(writer: anytype) !void {
    const plan = DaemonPlan{};
    try plan.validate();
    try writer.print(
        "{{\"daemon\":\"ready\",\"socket\":\"{s}\",\"socket_mode\":\"0600\",\"parent_dir_mode\":\"0700\",\"state_dir\":\"{s}\",\"auth_token\":\"{s}\",\"public_tcp\":false,\"supervisor\":\"per-pane\",\"vt\":\"{s}\",\"multi_client\":\"{s}\",\"roaming_transport\":\"{s}\",\"agent_detection\":\"{s}\"}}\n",
        .{ plan.socket_plan.path, plan.state_store.state_dir, plan.token_plan.path, plan.vt_status, session.status(), transport_mode.status(), notify.status() },
    );
}

test "daemon plan validates production-safe foundations" {
    const plan = DaemonPlan{};
    try plan.validate();
    try @import("std").testing.expectEqualStrings(vt.productionVtStatus(), plan.vt_status);
}
