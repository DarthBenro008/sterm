pub const ProcessStatus = enum {
    running,
    exited,
    unknown,
};

pub const ProcessPlan = struct {
    command: []const u8,
    own_process_group: bool = true,
};
