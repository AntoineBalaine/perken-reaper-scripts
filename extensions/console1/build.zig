//! Run with
//! zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_c1.so hello_world.zig -lc
//! or use
//! zig build -Dtest=true --prefix "~/.config/REAPER/UserPlugins" && reaper new
//! or on MacOS:
//! zig build -Dtest=true --prefix "/Users/a266836/Library/Application Support/REAPER/UserPlugins" && /Applications/REAPER.app/Contents/MacOS/REAPER new
const std = @import("std");
const builtin = @import("builtin");
const tests = @import("build_tests.zig");
pub const Dependencies = struct {
    ini: *std.Build.Dependency,
};

pub fn build(b: *std.Build) !void {
    // Create a library target
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wdl_dep = b.dependency("WDL", .{ .target = target, .optimize = optimize });
    const reaper_sdk_dep = b.dependency("reaper-sdk", .{ .target = target, .optimize = optimize });

    const lib = b.addSharedLibrary(.{
        .name = "reaper_c1",
        .root_source_file = b.path("src/console1_extension.zig"),
        .target = target,
        .optimize = .Debug,
    });

    // include path for c header files
    lib.addIncludePath(b.path("./src/"));
    lib.addIncludePath(wdl_dep.path("")); // Root of WDL

    lib.addIncludePath(reaper_sdk_dep.path("")); // Root of reaper-sdk

    var client_install: *std.Build.Step.InstallArtifact = undefined;
    lib.linkLibC();

    if (target.result.isDarwin()) {
        lib.root_module.linkFramework("AppKit", .{});
        lib.linkLibCpp();
        client_install = b.addInstallArtifact(lib, .{
            .dest_sub_path = "reaper_c1.dylib",
            .dest_dir = .{ .override = .{
                .custom = "",
            } },
        });
    } else {
        client_install = b.addInstallArtifact(lib, .{
            .dest_sub_path = "reaper_c1.so",
            .dest_dir = .{ .override = .{
                .custom = "",
            } },
        });
    }

    // allow passing testing flags
    const options = b.addOptions();
    options.addOption(bool, "test", b.option(bool, "test", "Create actions to test inside reaper") orelse false);
    lib.root_module.addOptions("config", options);

    const php_script = wdl_dep.path("WDL/swell/swell_resgen.php");
    const resource_rc = b.path("src/csurf/resource.rc");

    std.debug.print("WDL include path: {s}\n", .{wdl_dep.path("").getPath(b)});

    // Add system command to run PHP script
    const php_cmd = b.addSystemCommand(&[_][]const u8{"php"});
    php_cmd.addFileArg(php_script); // Convert LazyPath to string
    php_cmd.addFileArg(resource_rc); // Convert LazyPath to string
    lib.step.dependOn(&php_cmd.step);

    const modstub = if (target.result.isDarwin())
        wdl_dep.path("WDL/swell/swell-modstub.mm")
    else
        wdl_dep.path("WDL/swell/swell-modstub-generic.cpp");

    // Define compiler flags similar to flatbufferz
    const cpp_flags = [_][]const u8{
        if (target.result.isDarwin()) "clang" else "gcc",
        "-c",
        "-fPIC",
        "-O2",
        "-std=c++14",
        b.fmt("-I{s}", .{wdl_dep.path("").getPath(b)}),
        "-DSWELL_PROVIDED_BY_APP",
        "-o",
    };
    // Define cpp files using dependency paths
    const cppfiles = [_]std.Build.LazyPath{
        b.path("src/csurf/control_surface.cpp"),
        b.path("src/csurf/control_surface_wrapper.cpp"),
        b.path("src/csurf/midi_wrapper.cpp"),
        modstub,
    };

    // Add the C++ source files to the library
    inline for (comptime cppfiles) |cppfile| {
        const filearg = try std.fmt.allocPrint(
            b.allocator,
            "{s}.o",
            .{std.fs.path.basename(cppfile.getPath(b))},
        );
        const cxx = b.addSystemCommand(&cpp_flags);
        lib.addObjectFile(cxx.addOutputFileArg(filearg));
        cxx.addFileArg(cppfile);
        cxx.step.dependOn(&php_cmd.step);
    }

    b.getInstallStep().dependOn(&client_install.step);

    // add dependencies: ini parser, etc.
    const ini = b.dependency("ini", .{ .target = target, .optimize = .Debug });
    lib.root_module.addImport("ini", ini.module("ini"));

    _ = tests.addTests(b, target, Dependencies{ .ini = ini });
    // Default step for building
    const step = b.step("default", "Build reaper_c1.so");
    step.dependOn(&lib.step);
}
