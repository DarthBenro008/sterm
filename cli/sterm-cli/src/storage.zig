const std = @import("std");
const schema = @import("storage/migrations.zig");
pub const sqlite = @import("storage/sqlite.zig");
pub const journal = @import("storage/journal.zig");

pub const default_state_dir = "~/.sterm/state";
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

pub const StateStorePlan = struct {
    state_dir: []const u8 = default_state_dir,
    database_path: []const u8 = sqlite.database_path,
    current_version: u32 = current_schema_version,
    journal_template: []const u8 = journal.journal_path_template,
    sqlite_available: bool = sqlite.compiled,

    pub fn validate(plan: StateStorePlan) !void {
        if (plan.state_dir.len == 0) return error.EmptyStateDir;
        if (plan.database_path.len == 0) return error.EmptyDatabasePath;
        if (plan.current_version != current_schema_version) return error.SchemaVersionMismatch;
    }

    pub fn writeManifest(plan: StateStorePlan, writer: anytype) !void {
        try writer.print(
            \\state_dir={s}
            \\database_path={s}
            \\schema_version={d}
            \\sqlite={s}
            \\journal_template={s}
            \\
        , .{
            plan.state_dir,
            plan.database_path,
            plan.current_version,
            if (plan.sqlite_available) "linked" else sqlite.integration_status,
            plan.journal_template,
        });
    }
};

test "state store plan records honest sqlite availability" {
    const plan = StateStorePlan{};
    try plan.validate();
    try std.testing.expect(!plan.sqlite_available);
    try std.testing.expectError(sqlite.SqliteError.SqliteUnavailable, sqlite.requireAvailable());

    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    try plan.writeManifest(&output.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "sqlite=sqlite3-unlinked") != null);
}
