const std = @import("std");
const socket = @import("socket.zig");
const storage = @import("storage.zig");
const auth = @import("auth.zig");

pub const default_home = "~";
pub const default_config_file = "~/.sterm/config.toml";
pub const default_bin_dir = "~/.sterm/bin";
pub const default_log_file = "~/.sterm/logs/sterm-cli.log";

pub const RuntimePathError = error{
    EmptyHome,
    EmptySocketPath,
};

pub const RuntimePaths = struct {
    allocator: std.mem.Allocator,
    home: []const u8,
    base_dir: []const u8,
    bin_dir: []const u8,
    state_dir: []const u8,
    log_dir: []const u8,
    journal_dir: []const u8,
    upload_dir: []const u8,
    config_path: []const u8,
    socket_path: []const u8,
    auth_token_path: []const u8,
    db_path: []const u8,
    log_file: []const u8,

    pub fn init(allocator: std.mem.Allocator, home: []const u8) !RuntimePaths {
        if (home.len == 0) return RuntimePathError.EmptyHome;

        const owned_home = try allocator.dupe(u8, home);
        errdefer allocator.free(owned_home);

        const base_dir = try std.fs.path.join(allocator, &.{ owned_home, ".sterm" });
        errdefer allocator.free(base_dir);
        const bin_dir = try std.fs.path.join(allocator, &.{ base_dir, "bin" });
        errdefer allocator.free(bin_dir);
        const state_dir = try std.fs.path.join(allocator, &.{ base_dir, "state" });
        errdefer allocator.free(state_dir);
        const log_dir = try std.fs.path.join(allocator, &.{ base_dir, "logs" });
        errdefer allocator.free(log_dir);
        const journal_dir = try std.fs.path.join(allocator, &.{ state_dir, "journal" });
        errdefer allocator.free(journal_dir);
        const upload_dir = try std.fs.path.join(allocator, &.{ base_dir, "uploads" });
        errdefer allocator.free(upload_dir);
        const config_path = try std.fs.path.join(allocator, &.{ base_dir, "config.toml" });
        errdefer allocator.free(config_path);
        const socket_path = try std.fs.path.join(allocator, &.{ base_dir, "sterm.sock" });
        errdefer allocator.free(socket_path);
        const auth_token_path = try std.fs.path.join(allocator, &.{ state_dir, "auth_token" });
        errdefer allocator.free(auth_token_path);
        const db_path = try std.fs.path.join(allocator, &.{ state_dir, "sterm.db" });
        errdefer allocator.free(db_path);
        const log_file = try std.fs.path.join(allocator, &.{ log_dir, "sterm-cli.log" });
        errdefer allocator.free(log_file);

        return .{
            .allocator = allocator,
            .home = owned_home,
            .base_dir = base_dir,
            .bin_dir = bin_dir,
            .state_dir = state_dir,
            .log_dir = log_dir,
            .journal_dir = journal_dir,
            .upload_dir = upload_dir,
            .config_path = config_path,
            .socket_path = socket_path,
            .auth_token_path = auth_token_path,
            .db_path = db_path,
            .log_file = log_file,
        };
    }

    pub fn deinit(self: *RuntimePaths) void {
        self.allocator.free(self.log_file);
        self.allocator.free(self.db_path);
        self.allocator.free(self.auth_token_path);
        self.allocator.free(self.socket_path);
        self.allocator.free(self.config_path);
        self.allocator.free(self.upload_dir);
        self.allocator.free(self.journal_dir);
        self.allocator.free(self.log_dir);
        self.allocator.free(self.state_dir);
        self.allocator.free(self.bin_dir);
        self.allocator.free(self.base_dir);
        self.allocator.free(self.home);
    }

    pub fn validate(self: RuntimePaths) RuntimePathError!void {
        if (self.home.len == 0) return RuntimePathError.EmptyHome;
        if (self.socket_path.len == 0) return RuntimePathError.EmptySocketPath;
    }
};

pub const RuntimeConfig = struct {
    socket_path: []const u8 = socket.default_socket_path,
    state_dir: []const u8 = storage.default_state_dir,
    log_file: []const u8 = default_log_file,
    auth_token_path: []const u8 = auth.auth_token_path,
    require_auth_token: bool = true,
    allow_tcp_listener: bool = false,
    schema_version: u32 = storage.current_schema_version,

    pub fn validate(config: RuntimeConfig) RuntimePathError!void {
        if (config.socket_path.len == 0) return RuntimePathError.EmptySocketPath;
    }

    pub fn writeToml(config: RuntimeConfig, writer: anytype) !void {
        try writer.print(
            \\[agent]
            \\socket = "{s}"
            \\state_dir = "{s}"
            \\log_file = "{s}"
            \\
            \\[storage]
            \\schema_version = {d}
            \\
            \\[security]
            \\require_auth_token = {any}
            \\allow_tcp_listener = {any}
            \\auth_token_path = "{s}"
            \\
        , .{
            config.socket_path,
            config.state_dir,
            config.log_file,
            config.schema_version,
            config.require_auth_token,
            config.allow_tcp_listener,
            config.auth_token_path,
        });
    }
};

test "runtime paths map PRD remote layout" {
    var paths = try RuntimePaths.init(std.testing.allocator, "/home/alice");
    defer paths.deinit();

    try paths.validate();
    try std.testing.expectEqualStrings("/home/alice/.sterm", paths.base_dir);
    try std.testing.expectEqualStrings("/home/alice/.sterm/bin", paths.bin_dir);
    try std.testing.expectEqualStrings("/home/alice/.sterm/state/sterm.db", paths.db_path);
    try std.testing.expectEqualStrings("/home/alice/.sterm/state/auth_token", paths.auth_token_path);
    try std.testing.expectEqualStrings("/home/alice/.sterm/sterm.sock", paths.socket_path);
    try std.testing.expectEqualStrings("/home/alice/.sterm/logs/sterm-cli.log", paths.log_file);
}

test "runtime config emits remote config without secrets" {
    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();

    try (RuntimeConfig{}).writeToml(&output.writer);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "require_auth_token = true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "allow_tcp_listener = false") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "token=") == null);
}
