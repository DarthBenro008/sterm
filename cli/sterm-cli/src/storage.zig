const std = @import("std");
const schema = @import("storage/migrations.zig");

pub const default_state_dir = "~/.sterm";
pub const default_workspace_dir = "~/.sterm/workspaces";
pub const current_schema_version: u32 = 1;

pub const Migration = struct {
    version: u32,
    name: []const u8,
    description: []const u8,
};

pub const migrations = [_]Migration{
    .{
        .version = 1,
        .name = "001_initial_remote_cli_state",
        .description = "Create local metadata roots for remote daemon status, workspaces, panes, and log indexes.",
    },
};

pub fn latestMigrationVersion() u32 {
    return migrations[migrations.len - 1].version;
}

pub fn isCurrent(version: u32) bool {
    return version == current_schema_version and latestMigrationVersion() == current_schema_version;
}

pub fn hasInitialSchemaEntity(entity: []const u8) bool {
    for (schema.initial_schema) |candidate| {
        if (std.mem.eql(u8, candidate, entity)) return true;
    }
    return false;
}
