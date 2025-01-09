const std = @import("std");
const Dependencies = @import("build.zig").Dependencies;

pub fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, dependencies: Dependencies) void {
    const entry_point_path = b.path("./src/console1_extension.zig");
    const test_exe = b.addTest(.{
        .name = "reaper_zig_tests",
        .target = target,
        .optimize = .Debug,
        .root_source_file = entry_point_path,
    });

    const test_root = b.path("./src/");
    test_exe.addIncludePath(test_root);

    // Add the config options module
    const options = b.addOptions();
    options.addOption(bool, "test", true);
    test_exe.root_module.addOptions("config", options);

    // Add dependencies
    test_exe.root_module.addImport("ini", dependencies.ini.module("ini"));

    // C++ source files
    const sourcefileOpts = std.Build.Module.AddCSourceFilesOptions{
        .files = &.{
            "src/csurf/control_surface.cpp",
            "src/csurf/control_surface_wrapper.cpp",
        },
        .flags = &.{
            "-fPIC",
            "-O2",
            "-std=c++14",
            "-IWDL/WDL",
            "-DSWELL_PROVIDED_BY_APP",
        },
    };
    test_exe.addCSourceFiles(sourcefileOpts);

    // Link required libraries
    test_exe.linkLibC();
    test_exe.linkLibCpp();
    if (target.result.isDarwin()) {
        test_exe.root_module.linkFramework("AppKit", .{});
    }

    // Create and configure the test step
    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_test.step);
}
