pub const AgentStatus = enum {
    running,
    thinking,
    waiting_for_input,
    needs_approval,
    error_state,
    completed,
    idle,
    disconnected,
};

pub const Notification = struct {
    pane_id: []const u8,
    level: []const u8,
    reason: []const u8,
};
