const std = @import("std");
const reaper = @import("reaper").reaper;
const fs_helpers = @import("fs_helpers");
const FileSystemOps = fs_helpers.FileSystemOps;
const joinStrings = fs_helpers.joinStrings;
const ensureDir = fs_helpers.ensureDir;
const ensureFile = fs_helpers.ensureFile;

const default_preferences = @embedFile("resources/preferences.ini");
const default_mappings = struct {
    const comp_reacomp = @embedFile("resources/maps/factory/COMP/reacomp/default.ini");
    const eq_reaeq = @embedFile("resources/maps/factory/EQ/reaeq/default.ini");
    const gate_reagate = @embedFile("resources/maps/factory/GATE/reagate/default.ini");
    const rbj_filters = @embedFile("resources/maps/factory/INPUT/rbj_filters/default.ini");
    const vol_adj = @embedFile("resources/maps/factory/INPUT/vol_adj/default.ini");
    const vol_pan = @embedFile("resources/maps/factory/INPUT/vol_pan/default.ini");
    const reaanalog = @embedFile("resources/maps/factory/OUTPT/reaanalog/default.ini");
    const saturation = @embedFile("resources/maps/factory/OUTPT/saturation/default.ini");
};

/// Check for existence of config files, create them if necessary.
pub fn ensureConfigPath(fs_ops: FileSystemOps) !void {
    const reaper_path = reaper.GetResourcePath();
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;

    // First ensure Perken directory exists
    const perken_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
    });
    try ensureDir(fs_ops, perken_path);

    // Then ensure Console1 directory exists
    const resource_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
    });
    try ensureDir(fs_ops, resource_path);

    // Create preferences file
    const pref_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
        std.fs.path.sep_str,
        "preferences.ini",
    });
    try ensureFile(fs_ops, pref_path, default_preferences);

    // create maps directory
    const maps_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
        std.fs.path.sep_str,
        "maps",
    });
    try ensureDir(fs_ops, maps_path);

    // Create defaults directory inside maps
    const defaults_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "factory",
    });
    try ensureDir(fs_ops, defaults_path);

    // Create STRIP directory for channel strip mappings
    const strip_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "STRIP",
    });
    try ensureDir(fs_ops, strip_path);

    // Write default mapping files into maps/defaults/{name}/default.ini
    // Because each mapping needs a unique filename (the filename becomes the
    // mapping name), and all defaults use "default" as the mapping name, we
    // put each in its own subdirectory.
    const structure = .{
        .{ "COMP", "reacomp", default_mappings.comp_reacomp },
        .{ "EQ", "reaeq", default_mappings.eq_reaeq },
        .{ "GATE", "reagate", default_mappings.gate_reagate },
        .{ "INPUT", "rbj_filters", default_mappings.rbj_filters },
        .{ "INPUT", "vol_adj", default_mappings.vol_adj },
        .{ "INPUT", "vol_pan", default_mappings.vol_pan },
        .{ "OUTPT", "reaanalog", default_mappings.reaanalog },
        .{ "OUTPT", "saturation", default_mappings.saturation },
    };

    var buf2: [std.fs.max_path_bytes]u8 = undefined;
    var buf3: [std.fs.max_path_bytes]u8 = undefined;
    inline for (structure) |item| {
        const module_dir = joinStrings(&path_buffer, &.{
            std.mem.sliceTo(reaper_path, 0),
            std.fs.path.sep_str,
            "Data",
            std.fs.path.sep_str,
            "Perken",
            std.fs.path.sep_str,
            "Console1",
            std.fs.path.sep_str,
            "maps",
            std.fs.path.sep_str,
            "factory",
            std.fs.path.sep_str,
            item[0],
        });
        try ensureDir(fs_ops, module_dir);

        const fx_dir = joinStrings(&buf2, &.{
            module_dir,
            std.fs.path.sep_str,
            item[1],
        });
        try ensureDir(fs_ops, fx_dir);

        const file_path = joinStrings(&buf3, &.{
            fx_dir,
            std.fs.path.sep_str,
            "default.ini",
        });
        try ensureFile(fs_ops, file_path, item[2]);
    }
}

/// Copy embedded default files to a target directory for testing.
/// Tests need actual mapping files in the temp directory.
pub fn copyEmbeddedFilesToDir(fs_ops: FileSystemOps, target_path: []const u8) !void {
    var buf1: [std.fs.max_path_bytes]u8 = undefined;
    var buf2: [std.fs.max_path_bytes]u8 = undefined;
    var buf3: [std.fs.max_path_bytes]u8 = undefined;
    const console1_path = joinStrings(&buf1, &.{
        target_path, std.fs.path.sep_str, "Data",     std.fs.path.sep_str,
        "Perken",    std.fs.path.sep_str, "Console1",
    });

    // Create directory hierarchy
    try ensureDir(fs_ops, target_path);
    const data_path = joinStrings(&buf2, &.{ target_path, std.fs.path.sep_str, "Data" });
    try ensureDir(fs_ops, data_path);
    const perken_path = joinStrings(&buf3, &.{ data_path, std.fs.path.sep_str, "Perken" });
    try ensureDir(fs_ops, perken_path);
    try ensureDir(fs_ops, console1_path);

    // Write preferences
    const pref_path = joinStrings(&buf2, &.{ console1_path, std.fs.path.sep_str, "preferences.ini" });
    try ensureFile(fs_ops, pref_path, default_preferences);

    // Create maps directory and all default mappings
    const maps_path = joinStrings(&buf2, &.{ console1_path, std.fs.path.sep_str, "maps" });
    try ensureDir(fs_ops, maps_path);

    // Because older versions named FX folders with characters that Windows
    // forbids (such as "JS: ReaComp"), and saving now uses the Windows-safe
    // name, we rename existing folders once so that an edited map is not left
    // next to a newer copy of itself.
    fs_helpers.migrateFolderNamesRecursive(maps_path) catch |err| {
        std.log.err("Failed to rename legacy map folders in {s}: {s}", .{ maps_path, @errorName(err) });
    };

    // Create defaults directory
    const defaults_path = joinStrings(&buf3, &.{ maps_path, std.fs.path.sep_str, "factory" });
    try ensureDir(fs_ops, defaults_path);

    const structure = .{
        .{ "COMP", "reacomp", default_mappings.comp_reacomp },
        .{ "EQ", "reaeq", default_mappings.eq_reaeq },
        .{ "GATE", "reagate", default_mappings.gate_reagate },
        .{ "INPUT", "rbj_filters", default_mappings.rbj_filters },
        .{ "INPUT", "vol_adj", default_mappings.vol_adj },
        .{ "INPUT", "vol_pan", default_mappings.vol_pan },
        .{ "OUTPT", "reaanalog", default_mappings.reaanalog },
        .{ "OUTPT", "saturation", default_mappings.saturation },
    };

    var buf4: [std.fs.max_path_bytes]u8 = undefined;
    var buf5: [std.fs.max_path_bytes]u8 = undefined;
    inline for (structure) |item| {
        const module_dir = joinStrings(&buf2, &.{ defaults_path, std.fs.path.sep_str, item[0] });
        try ensureDir(fs_ops, module_dir);
        const fx_dir = joinStrings(&buf4, &.{ module_dir, std.fs.path.sep_str, item[1] });
        try ensureDir(fs_ops, fx_dir);
        const file_path = joinStrings(&buf5, &.{ fx_dir, std.fs.path.sep_str, "default.ini" });
        try ensureFile(fs_ops, file_path, item[2]);
    }
}
