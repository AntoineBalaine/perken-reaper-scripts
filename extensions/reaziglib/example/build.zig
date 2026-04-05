const std = @import("std");
const reaziglib = @import("reaziglib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const reazig_dep = b.dependency("reaziglib", .{ .target = target, .optimize = optimize });

    const lib = b.addSharedLibrary(.{
        .name = "reaper_hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    reaziglib.addSharedModules(reazig_dep, lib.root_module);

    const is_macos = target.result.os.tag == .macos;
    const dest = if (is_macos) "reaper_hello.dylib" else "reaper_hello.so";
    const install = b.addInstallArtifact(lib, .{ .dest_sub_path = dest });
    b.getInstallStep().dependOn(&install.step);
}
