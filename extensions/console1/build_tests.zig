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

    test_exe.addIncludePath(b.path("./src/"));
    test_exe.addIncludePath(dependencies.wdl.path("")); // Root of WDL
    test_exe.addIncludePath(dependencies.reaper_sdk.path("")); // Root of reaper-sdk

    // Add the config options module
    const options = b.addOptions();
    options.addOption(bool, "test", true);
    test_exe.root_module.addOptions("config", options);

    const php_script = dependencies.wdl.path("WDL/swell/swell_resgen.php");
    const resource_rc = b.path("src/csurf/resource.rc");

    const php_cmd = b.addSystemCommand(&[_][]const u8{"php"});
    php_cmd.addFileArg(php_script);
    php_cmd.addFileArg(resource_rc);
    test_exe.step.dependOn(&php_cmd.step);

    const modstub = if (target.result.isDarwin())
        dependencies.wdl.path("WDL/swell/swell-modstub.mm")
    else
        dependencies.wdl.path("WDL/swell/swell-modstub-generic.cpp");

    const cpp_flags = [_][]const u8{
        if (target.result.isDarwin()) "clang" else "gcc",
        "-c",
        "-fPIC",
        "-O2",
        "-std=c++14",
        b.fmt("-I{s}", .{dependencies.wdl.path("").getPath(b)}),
        "-DSWELL_PROVIDED_BY_APP",
        "-o",
    };

    const cppfiles = [_]std.Build.LazyPath{
        b.path("src/csurf/control_surface.cpp"),
        b.path("src/csurf/control_surface_wrapper.cpp"),
        b.path("src/csurf/midi_wrapper.cpp"),
        modstub,
    };

    inline for (comptime cppfiles) |cppfile| {
        const filearg = std.fmt.allocPrint(
            b.allocator,
            "{s}.o",
            .{std.fs.path.basename(cppfile.getPath(b))},
        ) catch unreachable;
        const cxx = b.addSystemCommand(&cpp_flags);
        test_exe.addObjectFile(cxx.addOutputFileArg(filearg));
        cxx.addFileArg(cppfile);
        cxx.step.dependOn(&php_cmd.step);
    }

    // Add dependencies
    test_exe.root_module.addImport("ini", dependencies.ini.module("ini"));

    // Link required libraries
    test_exe.linkLibC();
    test_exe.linkLibCpp();
    if (target.result.isDarwin()) {
        test_exe.root_module.linkFramework("AppKit", .{});
    }

    const install_test = b.addInstallArtifact(test_exe, .{});

    // Create and configure the test step
    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&install_test.step);
    test_step.dependOn(&run_test.step);
}
