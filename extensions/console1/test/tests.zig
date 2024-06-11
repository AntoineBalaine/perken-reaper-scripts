const std = @import("std");
const Dependencies = @import("../build.zig").Dependencies;

pub fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, dependencies: Dependencies) void {
    const entry_point_path = b.path("src/hello_world.zig");
    const test_exe = b.addTest(.{ .name = "reaper_zig_tests", .target = target, .optimize = .Debug, .root_source_file = entry_point_path });

    const sourcefileOpts = std.Build.Module.AddCSourceFilesOptions{ .files = &.{ "./src/csurf/control_surface.cpp", "./src/csurf/control_surface_wrapper.cpp" }, .flags = &.{ "-fPIC", "-O2", "-std=c++14", "-IWDL/WDL" } };
    test_exe.addCSourceFiles(sourcefileOpts);
    test_exe.linkLibC();
    test_exe.linkLibCpp();
    test_exe.root_module.addImport("ini", dependencies.ini.module("ini"));
    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_test.step);
}
