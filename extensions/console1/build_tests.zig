const std = @import("std");
const Dependencies = @import("build.zig").Dependencies;

pub fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, dependencies: Dependencies) void {
    const entry_point_path = b.path("./src/console1_extension.zig");

    const test_filters: []const []const u8 = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any of the specified filters",
    ) orelse &.{};
    const test_exe = b.addTest(.{
        .name = "reaper_zig_tests",
        .target = target,
        .optimize = .Debug,
        .root_source_file = entry_point_path,
        .filters = test_filters, // Add this line
    });

    test_exe.addIncludePath(b.path("./src/"));
    test_exe.addIncludePath(dependencies.wdl.path("")); // Root of WDL
    test_exe.addIncludePath(dependencies.reaper_sdk.path("")); // Root of reaper-sdk

    // Add the config options module
    const options = b.addOptions();
    options.addOption(bool, "test", true);
    test_exe.root_module.addOptions("config", options);

    const is_windows = target.result.os.tag == .windows;
    const is_macos = target.result.isDarwinLibC();

    // On macOS/Linux, SWELL requires PHP to generate dialog/menu resources from .rc files.
    // On Windows, resources are compiled natively, so PHP is not needed.
    if (!is_windows) {
        const php_script = dependencies.wdl.path("WDL/swell/swell_resgen.php");
        const resource_rc = b.path("src/csurf/resource.rc");

        const php_cmd = b.addSystemCommand(&[_][]const u8{"php"});
        php_cmd.addFileArg(php_script);
        php_cmd.addFileArg(resource_rc);
        test_exe.step.dependOn(&php_cmd.step);
    }

    // Exclude midi_wrapper.cpp since we are using our mock implementation.
    // On Windows, the SWELL modstub is not needed.
    const cppfiles: []const std.Build.LazyPath = if (is_windows)
        &.{
            b.path("src/csurf/control_surface.cpp"),
        }
    else
        &.{
            b.path("src/csurf/control_surface.cpp"),
            if (is_macos)
                dependencies.wdl.path("WDL/swell/swell-modstub.mm")
            else
                dependencies.wdl.path("WDL/swell/swell-modstub-generic.cpp"),
        };

    const cpp_flags: []const []const u8 = if (is_windows)
        &.{
            "cl",
            "/c",
            "/O2",
            "/std:c++14",
            b.fmt("/I{s}", .{dependencies.wdl.path("").getPath(b)}),
            "/DNOMINMAX",
            "/D_CRT_SECURE_NO_WARNINGS",
            "/D_CRT_NONSTDC_NO_DEPRECATE",
            "/Fo",
        }
    else
        &.{
            if (is_macos) "clang" else "gcc",
            "-c",
            "-fPIC",
            "-O2",
            "-std=c++14",
            b.fmt("-I{s}", .{dependencies.wdl.path("").getPath(b)}),
            "-DSWELL_PROVIDED_BY_APP",
            "-o",
        };

    for (cppfiles) |cppfile| {
        const filearg = std.fmt.allocPrint(
            b.allocator,
            "{s}.o",
            .{std.fs.path.basename(cppfile.getPath(b))},
        ) catch unreachable;
        const cxx = b.addSystemCommand(cpp_flags);
        test_exe.addObjectFile(cxx.addOutputFileArg(filearg));
        cxx.addFileArg(cppfile);
    }

    // Add dependencies
    test_exe.root_module.addImport("ini", dependencies.ini.module("ini"));
    test_exe.root_module.addImport("zlowcheck", dependencies.zlowcheck.module("zlowcheck"));
    test_exe.root_module.addImport("reaper_imgui", dependencies.imgui_mod);

    // Link required libraries
    test_exe.linkLibC();
    test_exe.linkLibCpp();
    if (target.result.isDarwinLibC()) {
        test_exe.root_module.linkFramework("AppKit", .{});
    }

    const install_test = b.addInstallArtifact(test_exe, .{});

    // Create and configure the test step
    const run_test = b.addRunArtifact(test_exe);

    // Add a no-run option to build tests without running them
    const no_run = b.option(bool, "no-run", "Build tests without running them") orelse false;

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&install_test.step);

    if (!no_run) {
        // Only run tests if no-run is not specified
        test_step.dependOn(&run_test.step);
    } else {
        // When no-run is specified, add a step to print the test executable path
        const print_path = b.addSystemCommand(&[_][]const u8{
            "echo",
            b.fmt("Test executable path: {s}", .{b.getInstallPath(.bin, test_exe.name)}),
        });
        test_step.dependOn(&print_path.step);
    }
}
