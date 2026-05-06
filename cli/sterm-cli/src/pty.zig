pub const PtyPlan = struct {
    shell: []const u8 = "/bin/bash",
    cwd: []const u8,
    rows: u16,
    cols: u16,
};
