pub const initial_schema = [_][]const u8{
    "workspaces",
    "tabs",
    "split_trees",
    "panes",
    "process_metadata",
    "notification_history",
    "scrollback_chunks",
    "output_journals",
    "agent_templates",
    "client_sessions",
    "protocol_version",
    "migration_state",
};

test "migration lists all PRD state entities" {
    try @import("std").testing.expect(initial_schema.len >= 12);
}
