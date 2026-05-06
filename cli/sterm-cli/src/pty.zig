pub const PtyPlan = struct {
    shell: []const u8 = "/bin/bash",
    cwd: []const u8,
    rows: u16,
    cols: u16,

    pub fn validate(plan: PtyPlan) !void {
        if (plan.shell.len == 0) return error.EmptyShell;
        if (plan.cwd.len == 0) return error.EmptyWorkingDirectory;
        if (plan.rows == 0 or plan.cols == 0) return error.InvalidTerminalSize;
    }
};

pub const PtyLifecycle = struct {
    owns_fd: bool = true,
    resize_signal: []const u8 = "SIGWINCH",
    close_behavior: []const u8 = "prompt-or-detach",

    pub fn validatesProcessOwnership(lifecycle: PtyLifecycle) bool {
        return lifecycle.owns_fd and lifecycle.resize_signal.len > 0 and lifecycle.close_behavior.len > 0;
    }
};

test "pty plans require process-safe terminal metadata" {
    const plan = PtyPlan{ .cwd = "/home/alice/project", .rows = 40, .cols = 120 };
    try plan.validate();
    try @import("std").testing.expect((PtyLifecycle{}).validatesProcessOwnership());
}
