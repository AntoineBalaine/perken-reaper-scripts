//! Run with
//! zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_c1.so hello_world.zig -lc
//! or use
//! zig build -Dtest=true --prefix "$HOME/.config/REAPER/UserPlugins" && zig build ui --prefix "$HOME/.config/REAPER/UserPlugins"
//! or on MacOS:
//! zig build -Dtest=true --prefix "$HOME/Library/Application Support/REAPER/UserPlugins" && zig build ui --prefix "$HOME/Library/Application Support/REAPER/UserPlugins" && /Applications/REAPER.app/Contents/MacOS/REAPER new
const std = @import("std");
const tests = @import("build_tests.zig");
pub const Dependencies = struct {
    ini: *std.Build.Dependency,
    wdl: *std.Build.Dependency,
    reaper_sdk: *std.Build.Dependency,
    zlowcheck: *std.Build.Dependency,
    imgui_mod: *std.Build.Module,
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
        .optimize = optimize,
    });

    // include path for c header files
    lib.addIncludePath(b.path("./src/"));
    lib.addIncludePath(wdl_dep.path("")); // Root of WDL

    lib.addIncludePath(reaper_sdk_dep.path("")); // Root of reaper-sdk

    var client_install: *std.Build.Step.InstallArtifact = undefined;
    lib.linkLibC();

    const is_windows = target.result.os.tag == .windows;
    const is_macos = target.result.os.tag == .macos;

    if (is_macos) {
        lib.root_module.linkFramework("AppKit", .{});
        lib.linkLibCpp();
        client_install = b.addInstallArtifact(lib, .{
            .dest_sub_path = "reaper_c1.dylib",
            .dest_dir = .{ .override = .{
                .custom = "",
            } },
        });
    } else if (is_windows) {
        lib.linkLibCpp();
        client_install = b.addInstallArtifact(lib, .{
            .dest_sub_path = "reaper_c1.dll",
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
    options.addOption(bool, "headless", b.option(bool, "headless", "Headless mode: register csurf directly without REAPER preferences") orelse false);
    lib.root_module.addOptions("config", options);

    // On macOS/Linux, SWELL requires PHP to generate dialog/menu resources from .rc files.
    // On Windows, resources are compiled natively by the resource compiler, so PHP is not needed.
    if (!is_windows) {
        const php_script = wdl_dep.path("WDL/swell/swell_resgen.php");
        const resource_rc = b.path("src/csurf/resource.rc");

        const php_cmd = b.addSystemCommand(&[_][]const u8{"php"});
        php_cmd.addFileArg(php_script);
        php_cmd.addFileArg(resource_rc);
        lib.step.dependOn(&php_cmd.step);
    }

    // On Windows, the SWELL modstub is not needed because REAPER uses native Win32 directly.
    const cppfiles: []const std.Build.LazyPath = if (is_windows)
        &.{
            b.path("src/csurf/control_surface.cpp"),
            b.path("src/csurf/control_surface_wrapper.cpp"),
            b.path("src/csurf/midi_wrapper.cpp"),
        }
    else
        &.{
            b.path("src/csurf/control_surface.cpp"),
            b.path("src/csurf/control_surface_wrapper.cpp"),
            b.path("src/csurf/midi_wrapper.cpp"),
            if (is_macos)
                wdl_dep.path("WDL/swell/swell-modstub.mm")
            else
                wdl_dep.path("WDL/swell/swell-modstub-generic.cpp"),
        };

    const cpp_flags: []const []const u8 = if (is_windows)
        &.{
            "cl",
            "/c",
            "/O2",
            "/std:c++14",
            b.fmt("/I{s}", .{wdl_dep.path("").getPath(b)}),
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
            b.fmt("-I{s}", .{wdl_dep.path("").getPath(b)}),
            "-DSWELL_PROVIDED_BY_APP",
            "-fsigned-char",
            "-o",
        };

    for (cppfiles) |cppfile| {
        const filearg = try std.fmt.allocPrint(
            b.allocator,
            "{s}.o",
            .{std.fs.path.basename(cppfile.getPath(b))},
        );
        const cxx = b.addSystemCommand(cpp_flags);
        lib.addObjectFile(cxx.addOutputFileArg(filearg));
        cxx.addFileArg(cppfile);
    }

    // On Windows, compile the .rc resource file with the native resource compiler.
    if (is_windows) {
        const rc_cmd = b.addSystemCommand(&.{ "rc", "/fo" });
        lib.addObjectFile(rc_cmd.addOutputFileArg("resource.res"));
        rc_cmd.addFileArg(b.path("src/csurf/resource.rc"));
    }

    b.getInstallStep().dependOn(&client_install.step);

    // Because reaper_imgui.zig is 7000+ lines and dominates compile time,
    // we expose it as a module so Zig can cache its compilation separately.
    const imgui_mod = b.addModule("reaper_imgui", .{
        .root_source_file = b.path("src/reaper_imgui.zig"),
    });
    lib.root_module.addImport("reaper_imgui", imgui_mod);

    // add dependencies: ini parser, etc.
    const ini = b.dependency("ini", .{ .target = target, .optimize = optimize });
    lib.root_module.addImport("ini", ini.module("ini"));

    const zlowcheck = b.dependency("zlowcheck", .{ .target = target, .optimize = optimize });
    lib.root_module.addImport("zlowcheck", zlowcheck.module("zlowcheck"));

    // Shared modules: reusable modules that external consumers can import as
    // a Zig package dependency. Each module's cross-references use module
    // names (not file paths), so they resolve correctly in any consumer.
    const reaper_mod = b.addModule("reaper", .{
        .root_source_file = b.path("src/reaper.zig"),
    });

    const string_pool_mod = b.addModule("string_pool", .{
        .root_source_file = b.path("src/string_pool.zig"),
    });
    const fx_parser_types_mod = b.addModule("fx_parser_types", .{
        .root_source_file = b.path("src/fx_parser_types.zig"),
    });

    const fs_helpers_mod = b.addModule("fs_helpers", .{
        .root_source_file = b.path("src/fs_helpers.zig"),
    });
    fs_helpers_mod.addImport("reaper", reaper_mod);

    const translator_mod = b.addModule("Translator", .{
        .root_source_file = b.path("src/Translator.zig"),
    });
    translator_mod.addImport("ini", ini.module("ini"));
    translator_mod.addImport("fs_helpers", fs_helpers_mod);

    const fx_parser_mod = b.addModule("fx_parser", .{
        .root_source_file = b.path("src/fx_parser.zig"),
    });
    fx_parser_mod.addImport("reaper", reaper_mod);
    fx_parser_mod.addImport("ini", ini.module("ini"));
    fx_parser_mod.addImport("fx_parser_types", fx_parser_types_mod);
    fx_parser_mod.addImport("fs_helpers", fs_helpers_mod);

    const color_helpers_mod = b.addModule("colorHelpers", .{
        .root_source_file = b.path("src/theme/colorHelpers.zig"),
    });
    color_helpers_mod.addImport("reaper_imgui", imgui_mod);

    // Note: c1_theme and reaperThemeTypes live under src/theme/ which uses
    // @embedFile("../assets/...") to reference assets outside its directory.
    // Because a module's package root is derived from its root_source_file,
    // those embed paths would escape the package boundary.  These files are
    // therefore kept as file-path imports within the root module rather
    // than being registered as standalone modules.

    const preset_file_reader_mod = b.addModule("preset_file_reader", .{
        .root_source_file = b.path("src/preset_file_reader.zig"),
    });
    preset_file_reader_mod.addImport("string_pool", string_pool_mod);
    preset_file_reader_mod.addImport("ini", ini.module("ini"));

    const knob_mod = b.addModule("knob", .{
        .root_source_file = b.path("src/components/knob.zig"),
    });
    knob_mod.addImport("reaper_imgui", imgui_mod);

    const mock_imgui_mod = b.addModule("mock_imgui", .{
        .root_source_file = b.path("src/models/mock_imgui.zig"),
    });
    mock_imgui_mod.addImport("reaper_imgui", imgui_mod);

    const reaper_mock_mod = b.addModule("reaper_mock", .{
        .root_source_file = b.path("src/models/reaper_mock.zig"),
    });
    reaper_mock_mod.addImport("reaper", reaper_mod);

    // Register shared modules on the host extension so that files within the
    // root module that use module-name imports can resolve them.
    addSharedModules(b, lib.root_module);

    _ = tests.addTests(b, target, Dependencies{
        .ini = ini,
        .wdl = wdl_dep,
        .reaper_sdk = reaper_sdk_dep,
        .zlowcheck = zlowcheck,
        .imgui_mod = imgui_mod,
    });

    // Default step for building
    const step = b.step("default", "Build reaper_c1.so");
    step.dependOn(&lib.step);

    // UI lib target: built as a shared library for hot-reloading.
    // Build with: zig build ui
    const ui_lib = b.addSharedLibrary(.{
        .name = "reaper_c1_ui",
        .root_source_file = b.path("src/ui_lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    ui_lib.linkLibC();
    ui_lib.root_module.addImport("ini", ini.module("ini"));
    ui_lib.root_module.addImport("reaper_imgui", imgui_mod);
    // The UI library transitively imports shared files (e.g. fx_sel_panel
    // uses fx_parser_types and string_pool), so it needs the shared modules.
    addSharedModules(b, ui_lib.root_module);

    const ui_dest = if (is_macos)
        "reaper_c1_ui.dylib"
    else if (is_windows)
        "reaper_c1_ui.dll"
    else
        "reaper_c1_ui.so";

    const ui_install = b.addInstallArtifact(ui_lib, .{
        .dest_sub_path = ui_dest,
        .dest_dir = .{ .override = .{ .custom = "" } },
    });

    const ui_step = b.step("ui", "Build hot-reloadable UI library");
    ui_step.dependOn(&ui_install.step);
}

/// Registers all shared modules as imports on `consumer` so that any file
/// compiled within that module can resolve `@import("reaper")`,
/// `@import("string_pool")`, etc.  External packages that depend on the C1
/// repo call this from their own `build.zig` after adding C1 as a
/// dependency.
pub fn addSharedModules(b: *std.Build, consumer: *std.Build.Module) void {
    const module_names = [_][]const u8{
        "reaper",
        "string_pool",
        "fx_parser_types",
        "fs_helpers",
        "fx_parser",
        "colorHelpers",
        "preset_file_reader",
        "knob",
        "mock_imgui",
        "reaper_mock",
        "reaper_imgui",
        "Translator",
    };
    for (module_names) |name| {
        // b.modules already contains every module created with addModule
        // during the build() call, so we can look them up by name.
        if (b.modules.get(name)) |mod| {
            consumer.addImport(name, mod);
        }
    }
}
