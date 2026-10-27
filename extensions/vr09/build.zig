const std = @import("std");
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });
    const clap_dep = b.dependency("clap", .{});

    const strip = b.option(bool, "strip", "strip debug info") orelse (optimize != .Debug);
    // The release version, baked into the binary so that it knows which
    // release it came from. CI passes it from the <name>-v<version> tag.
    const version = b.option([]const u8, "version", "Version string baked into the binary") orelse "dev";
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);

    const lib = b.addSharedLibrary(.{
        .name = "vr09",
        .root_source_file = b.path("src/clap_entry.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    lib.linkLibC();
    lib.addIncludePath(clap_dep.path("include"));
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
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = .Debug,
    });
    test_exe.linkLibC();
    test_exe.addIncludePath(clap_dep.path("include"));
    reaziglib.addSharedModules(reazig_dep, test_exe.root_module);
    test_exe.root_module.addOptions("build_options", build_options);
    // The sources that the API-list test scans.
    const test_paths = b.addOptions();
    test_paths.addOption([]const []const u8, "sources", &.{b.pathFromRoot("src")});
    test_exe.root_module.addOptions("test_paths", test_paths);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
