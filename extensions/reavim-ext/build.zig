const std = @import("std");
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });
    const ini_dep = b.dependency("ini", .{ .target = target, .optimize = optimize });
    const wdl_dep = b.dependency("WDL", .{ .target = target, .optimize = optimize });

    const strip = b.option(bool, "strip", "strip debug info") orelse (optimize != .debug);
    // The release version, baked into the binary so that it knows which
    // release it came from. CI passes it from the <name>-v<version> tag.
    const version = b.option([]const u8, "version", "Version string baked into the binary") orelse "dev";
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "reaper_reavim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .link_libc = true,
        }),
    });
    reaziglib.addSharedModules(reazig_dep, lib.root_module);
    lib.root_module.addImport("ini", ini_dep.module("ini"));
    lib.root_module.addOptions("build_options", build_options);

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
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .debug,
            .link_libc = true,
        }),
    });
    reaziglib.addSharedModules(reazig_dep, test_exe.root_module);
    test_exe.root_module.addImport("ini", ini_dep.module("ini"));
    test_exe.root_module.addOptions("build_options", build_options);
    // The sources that the API-list test scans: this extension's own, and
    // the shared reaper_helpers module it compiles in from reaziglib.
    // Because the build script no longer resolves paths itself since Zig
    // 0.17, the options receive them as tracked paths.
    const test_paths = b.addOptions();
    test_paths.addOptionPathDirectory("src_dir", b.path("src"));
    test_paths.addOptionPath("reaper_helpers", reazig_dep.path("src/reaper_helpers.zig"));
    test_exe.root_module.addOptions("test_paths", test_paths);

    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
