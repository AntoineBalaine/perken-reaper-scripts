const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ini = b.dependency("ini", .{ .target = target, .optimize = optimize });

    // Leaf modules (no dependencies on other shared modules)
    const reaper_mod = b.addModule("reaper", .{
        .root_source_file = b.path("src/reaper.zig"),
    });

    const reaper_imgui_mod = b.addModule("reaper_imgui", .{
        .root_source_file = b.path("src/reaper_imgui.zig"),
    });

    const string_pool_mod = b.addModule("string_pool", .{
        .root_source_file = b.path("src/string_pool.zig"),
    });

    const fx_parser_types_mod = b.addModule("fx_parser_types", .{
        .root_source_file = b.path("src/fx_parser_types.zig"),
    });

    // utils depends on reaper
    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
    });
    utils_mod.addImport("reaper", reaper_mod);

    // fs_helpers depends on reaper
    const fs_helpers_mod = b.addModule("fs_helpers", .{
        .root_source_file = b.path("src/fs_helpers.zig"),
    });
    fs_helpers_mod.addImport("reaper", reaper_mod);

    // Translator depends on fs_helpers, ini
    const translator_mod = b.addModule("Translator", .{
        .root_source_file = b.path("src/Translator.zig"),
    });
    translator_mod.addImport("fs_helpers", fs_helpers_mod);
    translator_mod.addImport("ini", ini.module("ini"));

    // fx_parser depends on reaper, fx_parser_types, fs_helpers, ini
    const fx_parser_mod = b.addModule("fx_parser", .{
        .root_source_file = b.path("src/fx_parser.zig"),
    });
    fx_parser_mod.addImport("reaper", reaper_mod);
    fx_parser_mod.addImport("fx_parser_types", fx_parser_types_mod);
    fx_parser_mod.addImport("fs_helpers", fs_helpers_mod);
    fx_parser_mod.addImport("ini", ini.module("ini"));

    // colorHelpers depends on reaper_imgui
    const color_helpers_mod = b.addModule("colorHelpers", .{
        .root_source_file = b.path("src/theme/colorHelpers.zig"),
    });
    color_helpers_mod.addImport("reaper_imgui", reaper_imgui_mod);

    // preset_file_reader depends on string_pool, ini
    const preset_file_reader_mod = b.addModule("preset_file_reader", .{
        .root_source_file = b.path("src/preset_file_reader.zig"),
    });
    preset_file_reader_mod.addImport("string_pool", string_pool_mod);
    preset_file_reader_mod.addImport("ini", ini.module("ini"));

    // knob depends on reaper_imgui
    const knob_mod = b.addModule("knob", .{
        .root_source_file = b.path("src/components/knob.zig"),
    });
    knob_mod.addImport("reaper_imgui", reaper_imgui_mod);

    // mock_imgui depends on reaper_imgui
    const mock_imgui_mod = b.addModule("mock_imgui", .{
        .root_source_file = b.path("src/models/mock_imgui.zig"),
    });
    mock_imgui_mod.addImport("reaper_imgui", reaper_imgui_mod);

    // automation_mode (no deps)
    const automation_mode_mod = b.addModule("automation_mode", .{
        .root_source_file = b.path("src/models/automation_mode.zig"),
    });

    // fx_model depends on utils
    const fx_model_mod = b.addModule("fx_model", .{
        .root_source_file = b.path("src/models/fx_model.zig"),
    });
    fx_model_mod.addImport("utils", utils_mod);

    // track_model depends on utils, fx_model, automation_mode
    const track_model_mod = b.addModule("track_model", .{
        .root_source_file = b.path("src/models/track_model.zig"),
    });
    track_model_mod.addImport("utils", utils_mod);
    track_model_mod.addImport("fx_model", fx_model_mod);
    track_model_mod.addImport("automation_mode", automation_mode_mod);

    // session depends on track_model, utils, automation_mode
    const session_mod = b.addModule("session", .{
        .root_source_file = b.path("src/models/session.zig"),
    });
    session_mod.addImport("track_model", track_model_mod);
    session_mod.addImport("utils", utils_mod);
    session_mod.addImport("automation_mode", automation_mode_mod);
    session_mod.addImport("fx_model", fx_model_mod);

    // reaper_mock depends on reaper, utils, fx_model, track_model, session
    const reaper_mock_mod = b.addModule("reaper_mock", .{
        .root_source_file = b.path("src/models/reaper_mock.zig"),
    });
    reaper_mock_mod.addImport("reaper", reaper_mod);
    reaper_mock_mod.addImport("utils", utils_mod);
    reaper_mock_mod.addImport("fx_model", fx_model_mod);
    reaper_mock_mod.addImport("track_model", track_model_mod);
    reaper_mock_mod.addImport("session", session_mod);

    // slotted_buffer (no deps)
    _ = b.addModule("slotted_buffer", .{
        .root_source_file = b.path("src/slotted_buffer.zig"),
    });

    // reaper_helpers depends on reaper
    const reaper_helpers_mod = b.addModule("reaper_helpers", .{
        .root_source_file = b.path("src/reaper_helpers.zig"),
    });
    reaper_helpers_mod.addImport("reaper", reaper_mod);

    // swell (depends on reaper)
    const swell_mod = b.addModule("swell", .{
        .root_source_file = b.path("src/swell.zig"),
    });
    swell_mod.addImport("reaper", reaper_mod);

    // reaper_theme depends on reaper, reaper_imgui
    const reaper_theme_mod = b.addModule("reaper_theme", .{
        .root_source_file = b.path("src/reaper_theme/ReaperTheme.zig"),
    });
    reaper_theme_mod.addImport("reaper", reaper_mod);
    reaper_theme_mod.addImport("reaper_imgui", reaper_imgui_mod);

    // csurf: the Zig side of the control surface shim. Its C++ side must be
    // compiled with REAPER's toolchain, which a module can not express, so
    // extensions opt in with addCsurf, which adds both.
    const csurf_mod = b.addModule("csurf", .{
        .root_source_file = b.path("src/csurf/csurf.zig"),
    });
    csurf_mod.addImport("reaper", reaper_mod);

    // The modules above are consumed as source by the extensions, so their
    // test blocks never run in the extensions' own test steps. Because of
    // that, each file that carries tests gets its own test binary here, with
    // the imports those files use.
    const test_step = b.step("test", "Run reaziglib unit tests");
    const test_files = [_][]const u8{
        "src/utils.zig",
        "src/slotted_buffer.zig",
        "src/preset_file_reader.zig",
        "src/fs_helpers.zig",
        "src/swell.zig",
        "src/models/reaper_mock.zig",
        "src/reaper_helpers.zig",
    };
    const test_imports = [_]struct { name: []const u8, mod: *std.Build.Module }{
        .{ .name = "reaper", .mod = reaper_mod },
        .{ .name = "utils", .mod = utils_mod },
        .{ .name = "string_pool", .mod = string_pool_mod },
        .{ .name = "ini", .mod = ini.module("ini") },
        .{ .name = "fx_model", .mod = fx_model_mod },
        .{ .name = "track_model", .mod = track_model_mod },
        .{ .name = "session", .mod = session_mod },
        .{ .name = "automation_mode", .mod = automation_mode_mod },
    };
    for (test_files) |file| {
        const t = b.addTest(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
        });
        t.linkLibC();
        for (test_imports) |imp| t.root_module.addImport(imp.name, imp.mod);
        test_step.dependOn(&b.addRunArtifact(t).step);
    }

    // The csurf test also compiles csurf_shim_test.cpp, which calls the
    // surface through IReaperControlSurface's virtual table as REAPER would.
    // That C++ is compiled with REAPER's toolchain, which only exists for the
    // host OS. This build function also runs when an extension that does not
    // use the shim (reavim-ext) cross-compiles reaziglib for another OS, so
    // the test is only set up when building for the host.
    if (target.result.os.tag == builtin.os.tag) {
        const csurf_test = b.addTest(.{
            .root_source_file = b.path("src/csurf/csurf.zig"),
            .target = target,
            .optimize = optimize,
        });
        csurf_test.linkLibC();
        csurf_test.root_module.addImport("reaper", reaper_mod);
        const csurf_dir = b.path("src/csurf");
        const tt = csurf_test.rootModuleTarget();
        csurf_test.addObjectFile(reaperCxxObject(b, tt, b.path("src/csurf/csurf_shim.cpp"), &.{csurf_dir}, csurf_cxx_flags, "csurf_shim"));
        csurf_test.addObjectFile(reaperCxxObject(b, tt, b.path("src/csurf/csurf_shim_test.cpp"), &.{csurf_dir}, csurf_cxx_flags, "csurf_shim_test"));
        test_step.dependOn(&b.addRunArtifact(csurf_test).step);
    }
}

/// Compiler flags for a C++ file, per compiler family.
pub const CxxFlags = struct {
    /// clang (macOS) and gcc (Linux).
    gnu: []const []const u8 = &.{},
    /// MSVC's cl (Windows).
    msvc: []const []const u8 = &.{},
};

/// The shim uses no C++ standard library, exceptions or RTTI, so consumers do
/// not need to link a C++ runtime; hidden visibility keeps its symbols from
/// interposing on the host's.
const csurf_cxx_flags = CxxFlags{
    .gnu = &.{ "-fno-exceptions", "-fno-rtti", "-fvisibility=hidden" },
    .msvc = &.{ "/GR-", "/GS-" },
};

/// Compiles one C++ file with REAPER's own toolchain and returns the object
/// file, to add to an artifact with addObjectFile. C++ that REAPER calls
/// through virtual methods (control surfaces, MIDI devices) must use that
/// toolchain: MSVC's cl on Windows, Apple clang on macOS, gcc on Linux (see
/// extensions/README.md). This is Console1's pattern: the compiler runs as a
/// system command, so the build runs on the target's own OS; there is no
/// cross-compiling such C++.
pub fn reaperCxxObject(
    b: *std.Build,
    target: std.Target,
    file: std.Build.LazyPath,
    include_dirs: []const std.Build.LazyPath,
    flags: CxxFlags,
    out_basename: []const u8,
) std.Build.LazyPath {
    if (target.os.tag != builtin.os.tag) {
        std.debug.panic(
            "C++ that REAPER calls must be compiled with REAPER's toolchain on the target OS; " ++
                "building for {s} on {s} is not possible (see extensions/README.md)",
            .{ @tagName(target.os.tag), @tagName(builtin.os.tag) },
        );
    }
    switch (target.os.tag) {
        .windows => {
            const cmd = b.addSystemCommand(&.{ "cl", "/nologo", "/c", "/O2", "/std:c++14", "/DNOMINMAX" });
            for (include_dirs) |dir| cmd.addPrefixedDirectoryArg("/I", dir);
            cmd.addArgs(flags.msvc);
            const obj = cmd.addPrefixedOutputFileArg("/Fo", b.fmt("{s}.obj", .{out_basename}));
            cmd.addFileArg(file);
            return obj;
        },
        else => {
            const cmd = b.addSystemCommand(&.{ if (target.os.tag == .macos) "clang" else "gcc", "-c", "-fPIC", "-O2", "-std=c++14" });
            if (target.os.tag == .macos) {
                // Build for the requested architecture and macOS version,
                // which may differ from the host's defaults.
                const min = target.os.version_range.semver.min;
                cmd.addArgs(&.{
                    "-arch",
                    if (target.cpu.arch == .aarch64) "arm64" else "x86_64",
                    b.fmt("-mmacosx-version-min={d}.{d}", .{ min.major, min.minor }),
                });
            }
            for (include_dirs) |dir| cmd.addPrefixedDirectoryArg("-I", dir);
            cmd.addArgs(flags.gnu);
            cmd.addArg("-o");
            const obj = cmd.addOutputFileArg(b.fmt("{s}.o", .{out_basename}));
            cmd.addFileArg(file);
            return obj;
        },
    }
}

/// Adds the control surface shim to an extension: the "csurf" module (Zig
/// side) and csurf_shim.cpp compiled with REAPER's toolchain (C++ side).
/// It is opt-in because it compiles C++.
pub fn addCsurf(b: *std.Build, dep: *std.Build.Dependency, compile: *std.Build.Step.Compile) void {
    compile.root_module.addImport("csurf", dep.module("csurf"));
    compile.addObjectFile(reaperCxxObject(
        b,
        compile.rootModuleTarget(),
        dep.path("src/csurf/csurf_shim.cpp"),
        &.{dep.path("src/csurf")},
        csurf_cxx_flags,
        "csurf_shim",
    ));
}

pub fn addSharedModules(dep: *std.Build.Dependency, consumer: *std.Build.Module) void {
    const module_names = [_][]const u8{
        "reaper",
        "reaper_imgui",
        "string_pool",
        "fx_parser_types",
        "utils",
        "fs_helpers",
        "fx_parser",
        "colorHelpers",
        "preset_file_reader",
        "knob",
        "mock_imgui",
        "reaper_mock",
        "automation_mode",
        "fx_model",
        "track_model",
        "session",
        "Translator",
        "slotted_buffer",
        "swell",
        "reaper_theme",
        "reaper_helpers",
    };
    for (module_names) |name| {
        consumer.addImport(name, dep.module(name));
    }
}
