const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const ghostty_vt = b.option(
        bool,
        "ghostty-vt",
        "Build the production VT adapter with the Ghostty libghostty-vt Zig dependency",
    ) orelse false;
    const ghostty_vt_simd = b.option(
        bool,
        "ghostty-vt-simd",
        "Enable Ghostty SIMD dependencies for the VT adapter",
    ) orelse false;

    const module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    configureGhosttyVt(b, module, ghostty_vt, ghostty_vt_simd);

    const exe = b.addExecutable(.{
        .name = "sterm-cli",
        .root_module = module,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run sterm-cli");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = test_module: {
            const test_module = b.createModule(.{
                .root_source_file = b.path("src/test_all.zig"),
                .target = target,
                .optimize = optimize,
            });
            configureGhosttyVt(b, test_module, ghostty_vt, ghostty_vt_simd);
            break :test_module test_module;
        },
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run sterm-cli tests");
    test_step.dependOn(&run_tests.step);
}

fn configureGhosttyVt(
    b: *std.Build,
    module: *std.Build.Module,
    ghostty_vt: bool,
    ghostty_vt_simd: bool,
) void {
    const options = b.addOptions();
    options.addOption(bool, "libghostty_vt", ghostty_vt);
    module.addOptions("build_options", options);

    if (!ghostty_vt) return;

    const dep = b.dependency("ghostty", .{
        .simd = ghostty_vt_simd,
    });
    module.addImport("ghostty-vt", dep.module("ghostty-vt"));
}
