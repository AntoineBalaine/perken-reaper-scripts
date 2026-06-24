const std = @import("std");
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });
    const ini_dep = b.dependency("ini", .{ .target = target, .optimize = optimize });
    const wdl_dep = b.dependency("WDL", .{ .target = target, .optimize = optimize });

    const strip = b.option(bool, "strip", "strip debug info") orelse (optimize != .Debug);

    const lib = b.addSharedLibrary(.{
        .name = "reaper_reavim",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    lib.linkLibC();
    reaziglib.addSharedModules(reazig_dep, lib.root_module);
    lib.root_module.addImport("ini", ini_dep.module("ini"));

    _ = wdl_dep; // kept as a dependency for SWELL header reference (src/swell_win.zig
    // implements a minimal pure-Zig modstub instead of compiling WDL's C++ one)

    const ext = switch (target.result.os.tag) {
        .macos => "dylib",
        .windows => "dll",
        else => "so",
    };
    const dest = b.fmt("reaper_reavim.{s}", .{ext});
    const install = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = "" } }, .dest_sub_path = dest });
    b.getInstallStep().dependOn(&install.step);

    // Install the default keybindings as bindings.ini at the prefix root. This
    // is a separate step (not part of the default install) so it can be invoked
    // with its own --prefix pointing at <resource>/Data/Perken, while the plugin
    // installs under <resource>/UserPlugins.
    const bindings_install = b.addInstallFile(b.path("src/default_bindings.ini"), "bindings.ini");
    const bindings_step = b.step("bindings", "Install default keybindings to the prefix");
    bindings_step.dependOn(&bindings_install.step);

    const test_exe = b.addTest(.{
        .name = "reavim_tests",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
    });
    test_exe.linkLibC();
    reaziglib.addSharedModules(reazig_dep, test_exe.root_module);
    test_exe.root_module.addImport("ini", ini_dep.module("ini"));

    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
