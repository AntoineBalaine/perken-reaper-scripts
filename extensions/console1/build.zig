// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig -lc
// or use
// zig build --verbose && mv zig-out/lib/reaper_zig.so ~/.config/REAPER/UserPlugins/ && reaper
// sudo zig build --verbose && mv zig-out/lib/reaper_zig.dylib ~/Library/Application\ Support/REAPER/UserPlugins
const std = @import("std");
const builtin = @import("builtin");
const tests = @import("build_tests.zig");
pub const Dependencies = struct {
    ini: *std.Build.Dependency,
};

pub fn build(b: *std.Build) !void {
    // Create a library target
    const target = b.standardTargetOptions(.{});

    const lib = b.addSharedLibrary(.{ .name = "reaper_zig", .root_source_file = b.path("src/console1_extension.zig"), .target = target, .optimize = .Debug });

    const root = b.path("./src/");
    lib.addIncludePath(root);

    var client_install: *std.Build.Step.InstallArtifact = undefined;

    // create the file, call the resgen shell script, and then proceed with the rest
    // WDL/snwell/swell_resgen.php resource.rc generates resource.rc_mac_dlg and .rc_mac_menu
    // which must be compiled and linked into the executable
    // touch src/csurf/resource.rc && ./WDL/swell/swell_resgen.sh src/csurf/resource.rc
    const php_cmd = b.addSystemCommand(&[_][]const u8{"php"});
    php_cmd.addFileArg(b.path("WDL/swell/swell_resgen.php"));
    php_cmd.addFileArg(b.path("src/csurf/resource.rc"));

    const cpp_cmd = b.addSystemCommand(&[_][]const u8{ "gcc", "-o" });
    cpp_cmd.addFileInput(b.path("src/csurf/resource.rc_mac_dlg"));
    cpp_cmd.addFileInput(b.path("src/csurf/resource.rc_mac_menu"));
    cpp_cmd.step.dependOn(&php_cmd.step); // FIXME: don't re-run every time...

    const cpp_lib = cpp_cmd.addOutputFileArg("control_surface.o");

    if (target.result.isDarwin()) {
        lib.root_module.linkFramework("AppKit", .{});
        cpp_cmd.addArgs(&.{"WDL/swell/swell-modstub.mm"});
        client_install = b.addInstallArtifact(lib, .{ .dest_sub_path = "reaper_zig.dylib" });
    } else {
        cpp_cmd.addArgs(&.{"WDL/swell/swell-modstub-generic.cpp"});
        client_install = b.addInstallArtifact(lib, .{ .dest_sub_path = "reaper_zig.so" });
    }

    const cpp_files = [_][]const u8{
        "src/csurf/control_surface.cpp",
        "src/csurf/control_surface_wrapper.cpp",
        "src/csurf/midi_wrapper.cpp",
    };
    inline for (cpp_files) |cpp|
        cpp_cmd.addFileArg(b.path(cpp));
    cpp_cmd.addArgs(&.{ "-fPIC", "-O2", "-std=c++14", "-shared", "-IWDL/WDL", "-DSWELL_PROVIDED_BY_APP" });
    lib.addObjectFile(cpp_lib);
    lib.linkLibC();

    b.getInstallStep().dependOn(&client_install.step);

    // add dependencies: ini parser, etc.
    const ini = b.dependency("ini", .{ .target = target, .optimize = .Debug });
    lib.root_module.addImport("ini", ini.module("ini"));

    _ = tests.addTests(b, target, Dependencies{ .ini = ini });
    // Default step for building
    const step = b.step("default", "Build reaper_zig.so");
    step.dependOn(&lib.step);
}
