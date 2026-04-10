const std = @import("std");

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

    // swell (depends on reaper)
    const swell_mod = b.addModule("swell", .{
        .root_source_file = b.path("src/swell.zig"),
    });
    swell_mod.addImport("reaper", reaper_mod);
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
    };
    for (module_names) |name| {
        consumer.addImport(name, dep.module(name));
    }
}
