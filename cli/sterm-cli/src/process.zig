pub const ProcessStatus = enum {
    starting,
    running,
    exited,
    detached,
    unrecoverable,
    unknown,
};

pub const ProcessPlan = struct {
    command: []const u8,
    own_process_group: bool = true,
    create_session: bool = true,
    graceful_shutdown_ms: u32 = 2000,

    pub fn validate(plan: ProcessPlan) !void {
        if (plan.command.len == 0) return error.EmptyCommand;
        if (!plan.own_process_group) return error.ProcessGroupRequired;
        if (!plan.create_session) return error.SessionRequired;
    }
};

pub const SupervisorPlan = struct {
    per_pane_supervision: bool = true,
    reap_zombies: bool = true,
    preserve_metadata_on_crash: bool = true,
    recover_unowned_children: bool = false,

    pub fn isProductionBoundary(plan: SupervisorPlan) bool {
        return plan.per_pane_supervision and plan.reap_zombies and plan.preserve_metadata_on_crash;
    }
};

test "process plan owns process groups and supervisor boundary" {
    try (ProcessPlan{ .command = "bash" }).validate();
    try @import("std").testing.expect((SupervisorPlan{}).isProductionBoundary());
    try @import("std").testing.expectError(error.ProcessGroupRequired, (ProcessPlan{ .command = "bash", .own_process_group = false }).validate());
}
