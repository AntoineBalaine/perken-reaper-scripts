const std = @import("std");
const root = @import("build.zig");
const reaziglib = @import("reaziglib");
const Dependencies = root.Dependencies;

pub fn addTests(b: *std.Build, target: std.Build.ResolvedTarget, dependencies: Dependencies) void {
    const entry_point_path = b.path("./src/console1_extension.zig");

    const test_filters: []const []const u8 = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any of the specified filters",
    ) orelse &.{};
    const test_exe = b.addTest(.{
        .name = "reaper_zig_tests",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = .debug,
            .root_source_file = entry_point_path,
            .link_libc = true,
        }),
        .filters = test_filters,
    });
    test_exe.root_module.addImport("c", root.cBindings(b, target, .debug, dependencies.wdl, dependencies.reaper_sdk));

    // Add the config options module
    const options = b.addOptions();
    options.addOption(bool, "test", true);
    options.addOption(bool, "headless", false);
    options.addOption([]const u8, "version", "test");
    test_exe.root_module.addOptions("config", options);

    const is_windows = target.result.os.tag == .windows;
    const is_macos = target.result.isDarwinLibC();

    // On macOS/Linux, SWELL requires PHP to generate dialog/menu resources from .rc files.
    // On Windows, resources are compiled natively, so PHP is not needed.
    if (!is_windows) {
        if (b.findProgram(.{ .names = &.{"php"} }) != null) {
            const php_script = dependencies.wdl.path("WDL/swell/swell_resgen.php");
            const resource_rc = b.path("src/csurf/resource.rc");

            const php_cmd = b.addSystemCommand(&[_][]const u8{"php"});
            php_cmd.addFileArg(php_script);
            php_cmd.addFileArg(resource_rc);
            test_exe.step.dependOn(&php_cmd.step);
        }
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

    // C++ that REAPER calls (the control surface, MIDI devices) is compiled
    // with REAPER's own toolchain for the requested target, including its
    // architecture and macOS version (see ../README.md).
    const cxx_flags = reaziglib.CxxFlags{
        .gnu = &.{"-DSWELL_PROVIDED_BY_APP"},
        .msvc = &.{ "/D_CRT_SECURE_NO_WARNINGS", "/D_CRT_NONSTDC_NO_DEPRECATE" },
    };
    for (cppfiles) |cppfile| {
        const name = b.fmt("{s}", .{std.fs.path.basename(reaziglib.lazyPathName(cppfile))});
        test_exe.root_module.addObjectFile(reaziglib.reaperCxxObject(b, test_exe.rootModuleTarget(), cppfile, &.{dependencies.wdl.path("")}, cxx_flags, name));
    }

    // Add dependencies
    test_exe.root_module.addImport("ini", dependencies.ini.module("ini"));
    test_exe.root_module.addImport("zlowcheck", dependencies.zlowcheck.module("zlowcheck"));

    // Register shared modules from reaziglib
    reaziglib.addSharedModules(dependencies.reaziglib, test_exe.root_module);

    // Because cl's objects need MSVC's C++ runtime, not Zig's libc++,
    // Windows links the runtime that matches them.
    if (is_windows) reaziglib.linkReaperCxxRuntime(b, test_exe) else test_exe.root_module.link_libcpp = true;
    if (target.result.isDarwinLibC()) {
        test_exe.root_module.linkFramework("AppKit", .{});
    }

    const install_test = b.addInstallArtifact(test_exe, .{});

    // Create and configure the test step
    const run_test = b.addRunArtifact(test_exe);

    // Add a no-run option to build tests without running them. Because the
    // test step always installs the test binary, it is then found at
    // <prefix>/bin/reaper_zig_tests (zig-out/bin by default).
    const no_run = b.option(bool, "no-run", "Build tests without running them; the binary is installed in <prefix>/bin") orelse false;

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&install_test.step);

    if (!no_run) {
        // Only run tests if no-run is not specified
        test_step.dependOn(&run_test.step);
    }
}
