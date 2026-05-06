pub const default_retention_days: u16 = 7;
pub const journal_path_template = "~/.sterm/state/journal/<pane_id>.log.zst";

pub const JournalPlan = struct {
    pane_id: []const u8,
    retention_days: u16 = default_retention_days,
    compress: bool = true,

    pub fn validate(plan: JournalPlan) !void {
        if (plan.pane_id.len == 0) return error.EmptyPaneId;
        if (plan.retention_days == 0) return error.InvalidRetention;
    }
};
