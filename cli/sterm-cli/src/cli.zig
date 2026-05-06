const std = @import("std");
const protocol = @import("protocol.zig");
const security = @import("security.zig");
const socket = @import("socket.zig");
const storage = @import("storage.zig");
const vt = @import("vt.zig");

pub const version = "0.1.0";

pub const CliError = error{
    UnknownCommand,
    MissingArgument,
    InvalidArgument,
};

const CommandSpec = struct {
    usage: []const u8,
    summary: []const u8,
};

const commands = [_]CommandSpec{
    .{ .usage = "sterm daemon", .summary = "print remote daemon launch scaffold" },
    .{ .usage = "sterm status", .summary = "print local remote-agent status scaffold" },
    .{ .usage = "sterm version", .summary = "print CLI and protocol versions" },
    .{ .usage = "sterm doctor", .summary = "validate static CLI, security, storage, VT, and protocol contracts" },
    .{ .usage = "sterm workspace list", .summary = "list workspaces through the remote protocol" },
    .{ .usage = "sterm workspace create <name> [root_dir]", .summary = "create a remote workspace" },
    .{ .usage = "sterm pane create <workspace_id> [command]", .summary = "create a pane in a workspace" },
    .{ .usage = "sterm pane write <pane_id> <text>", .summary = "write text to a pane" },
    .{ .usage = "sterm pane resize <pane_id> <rows> <cols>", .summary = "resize a pane" },
    .{ .usage = "sterm logs [pane_id]", .summary = "read daemon or pane logs" },
};

pub fn run(init: std.process.Init, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
    var iterator = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer iterator.deinit();
    _ = iterator.next();

    var args_buffer: [64][]const u8 = undefined;
    var args_len: usize = 0;
    while (iterator.next()) |arg| {
        if (args_len == args_buffer.len) return CliError.InvalidArgument;
        args_buffer[args_len] = arg;
        args_len += 1;
    }

    try runArgs(args_buffer[0..args_len], stdout, stderr);
}

pub fn runArgs(args: []const []const u8, stdout: *std.Io.Writer, stderr: *std.Io.Writer) !void {
    if (args.len == 0 or eql(args[0], "help") or eql(args[0], "--help") or eql(args[0], "-h")) {
        try printHelp(stdout);
        return;
    }

    if (eql(args[0], "version") or eql(args[0], "--version") or eql(args[0], "-V")) {
        try stdout.print("sterm {s}\nprotocol {d}\n", .{ version, protocol.version });
        return;
    }

    if (eql(args[0], "daemon")) {
        try requireExact(args, 1);
        try stdout.print(
            \\daemon: scaffold
            \\socket: {s}
            \\auth: token-file mode {s}
            \\listener: unix-only by default
            \\
        , .{ socket.default_socket_path, security.secret_file_mode_octal });
        return;
    }

    if (eql(args[0], "status")) {
        try requireExact(args, 1);
        try stdout.print(
            \\status: offline (scaffold)
            \\socket: {s}
            \\workspace-dir: {s}
            \\
        , .{ socket.default_socket_path, storage.default_state_dir });
        return;
    }

    if (eql(args[0], "doctor")) {
        try requireExact(args, 1);
        try doctor(stdout);
        return;
    }

    if (eql(args[0], "workspace")) {
        try workspace(args[1..], stdout);
        return;
    }

    if (eql(args[0], "pane")) {
        try pane(args[1..], stdout);
        return;
    }

    if (eql(args[0], "logs")) {
        if (args.len > 2) return CliError.InvalidArgument;
        if (args.len == 2) {
            try stdout.print("logs: pane {s} (scaffold)\n", .{args[1]});
        } else {
            try stdout.writeAll("logs: daemon (scaffold)\n");
        }
        return;
    }

    try stderr.print("unknown command: {s}\n\n", .{args[0]});
    try printHelp(stderr);
    return CliError.UnknownCommand;
}

fn workspace(args: []const []const u8, stdout: *std.Io.Writer) !void {
    if (args.len == 1 and eql(args[0], "list")) {
        try stdout.writeAll("workspace list: [] (scaffold)\n");
        return;
    }

    if (args.len >= 1 and args.len <= 3 and eql(args[0], "create")) {
        const name = if (args.len >= 2) args[1] else "mock-local";
        const root_dir = if (args.len == 3) args[2] else ".";
        try stdout.print("workspace create: name={s} root_dir={s} (scaffold)\n", .{ name, root_dir });
        return;
    }

    return CliError.InvalidArgument;
}

fn pane(args: []const []const u8, stdout: *std.Io.Writer) !void {
    if (args.len >= 1 and args.len <= 3 and eql(args[0], "create")) {
        const workspace_id = if (args.len >= 2) args[1] else "ws_mock";
        const command = if (args.len == 3) args[2] else "";
        try stdout.print("pane create: workspace_id={s} command={s} (scaffold)\n", .{ workspace_id, command });
        return;
    }

    if (args.len >= 1 and args.len <= 3 and eql(args[0], "write")) {
        const pane_id = if (args.len >= 2) args[1] else "pane_mock";
        const text = if (args.len == 3) args[2] else "";
        try stdout.print("pane write: pane_id={s} bytes={d} (scaffold)\n", .{ pane_id, text.len });
        return;
    }

    if (args.len >= 1 and args.len <= 4 and eql(args[0], "resize")) {
        const pane_id = if (args.len >= 2) args[1] else "pane_mock";
        const rows = if (args.len >= 3) try parsePositiveInt(args[2]) else 40;
        const cols = if (args.len == 4) try parsePositiveInt(args[3]) else 120;
        try stdout.print("pane resize: pane_id={s} rows={d} cols={d} (scaffold)\n", .{ pane_id, rows, cols });
        return;
    }

    return CliError.InvalidArgument;
}

fn doctor(stdout: *std.Io.Writer) !void {
    try stdout.print(
        \\doctor: ok
        \\cli-version: {s}
        \\protocol-version: {d}
        \\socket-default: {s}
        \\state-dir: {s}
        \\security-dir-mode: {s}
        \\security-secret-mode: {s}
        \\vt-adapter: {s}
        \\storage-migrations: {d}
        \\
    , .{
        version,
        protocol.version,
        socket.default_socket_path,
        storage.default_state_dir,
        security.private_dir_mode_octal,
        security.secret_file_mode_octal,
        vt.MockAdapter.name,
        storage.migrations.len,
    });
}

fn printHelp(writer: *std.Io.Writer) !void {
    try writer.writeAll("sterm remote CLI scaffold\n\nCommands:\n");
    for (commands) |command| {
        try writer.print("  {s}\n      {s}\n", .{ command.usage, command.summary });
    }
}

fn requireExact(args: []const []const u8, expected: usize) CliError!void {
    if (args.len != expected) return CliError.InvalidArgument;
}

fn parsePositiveInt(raw: []const u8) CliError!u16 {
    const parsed = std.fmt.parseUnsigned(u16, raw, 10) catch return CliError.InvalidArgument;
    if (parsed == 0) return CliError.InvalidArgument;
    return parsed;
}

fn eql(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}
