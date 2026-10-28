const std = @import("std");
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });
    const clap_dep = b.dependency("clap", .{});

    const strip = b.option(bool, "strip", "strip debug info") orelse (optimize != .debug);
    // The release version, baked into the binary so that it knows which
    // release it came from. CI passes it from the <name>-v<version> tag.
    const version = b.option([]const u8, "version", "Version string baked into the binary") orelse "dev";
    // The scripting API (`VR09_Command`), for development: a script can drive the plugin through it, and some of
    // its commands write and delete files. The releases are built without it, and the install script for development
    // (`build-install.sh`) builds with it.
    const debug_api = b.option(bool, "debug_api", "Build the VR09_Command scripting API (for development)") orelse false;
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);
    build_options.addOption(bool, "debug_api", debug_api);
    // The tests drive the plugin through that API, so they always have it.
    const test_build_options = b.addOptions();
    test_build_options.addOption([]const u8, "version", version);
    test_build_options.addOption(bool, "debug_api", true);

    // The CLAP headers, translated to Zig. Because @cImport is gone since
    // Zig 0.17, the build translates them and the sources import the result
    // as the "clap_c" module.
    const clap_c = b.addTranslateC(.{
        .root_source_file = clap_dep.path("include/clap/clap.h"),
        .target = target,
        .optimize = optimize,
    });
    clap_c.addIncludePath(clap_dep.path("include"));
    const clap_c_mod = clap_c.createModule();

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "vr09",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/clap_entry.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .link_libc = true,
        }),
    });
    lib.root_module.addImport("clap_c", clap_c_mod);
    reaziglib.addSharedModules(reazig_dep, lib.root_module);
    lib.root_module.addOptions("build_options", build_options);

    // A CLAP plugin is a shared library whose file name ends in .clap. On
    // macOS the host expects a bundle (a folder with Contents/MacOS and an
    // Info.plist), so the bundle is installed there and the plain file
    // elsewhere.
    if (target.result.os.tag == .macos) {
        const plist = b.addInstallFile(b.path("macos/Info.plist"), "vr09.clap/Contents/Info.plist");
        const bin = b.addInstallArtifact(lib, .{
            .dest_dir = .{ .override = .{ .custom = "vr09.clap/Contents/MacOS" } },
            .dest_sub_path = "vr09",
        });
        b.getInstallStep().dependOn(&plist.step);
        b.getInstallStep().dependOn(&bin.step);
    } else {
        const install = b.addInstallArtifact(lib, .{
            .dest_dir = .{ .override = .{ .custom = "" } },
            .dest_sub_path = "vr09.clap",
        });
        b.getInstallStep().dependOn(&install.step);
    }

    const test_exe = b.addTest(.{
        .name = "vr09_tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = .debug,
            .link_libc = true,
        }),
    });
    test_exe.root_module.addImport("clap_c", clap_c_mod);
    reaziglib.addSharedModules(reazig_dep, test_exe.root_module);
    test_exe.root_module.addOptions("build_options", test_build_options);
    // The sources that the API-list test scans. Because the build script no
    // longer resolves paths itself since Zig 0.17, the options receive the
    // folder as a tracked path.
    const test_paths = b.addOptions();
    test_paths.addOptionPathDirectory("src_dir", b.path("src"));
    test_exe.root_module.addOptions("test_paths", test_paths);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
