// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig -lc
// or use
// zig build --verbose && mv zig-out/lib/reaper_zig_fakecsurf.so /home/antoine/.config/REAPER/UserPlugins/
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // Create a library target
    const target = b.standardTargetOptions(.{});

    const lib = b.addSharedLibrary(.{ .name = "reaper_zig", .root_source_file = b.path("src/hello_world.zig"), .target = target, .optimize = .Debug });

    const root = b.path("./src/");
    lib.addIncludePath(root);

    // -shared reaper_barebone.cpp -o reaper_barebone.so
    const sourcefileOpts = std.Build.Module.AddCSourceFilesOptions{ .files = &.{ "./src/fakeCsurf.cpp", "src/fakeCsurfWrapper.cpp" }, .flags = &.{ "-fPIC", "-O2", "-std=c++14", "-IWDL/WDL" } };

    lib.addCSourceFiles(sourcefileOpts);
    lib.linkLibC();
    lib.linkLibCpp();
    const client_install = b.addInstallArtifact(lib, .{ .dest_sub_path = "reaper_zig_fakecsurf.so" });
    b.getInstallStep().dependOn(&client_install.step);

    // Default step for building
    const step = b.step("default", "Build reaper_zig.so");
    step.dependOn(&lib.step);
}
