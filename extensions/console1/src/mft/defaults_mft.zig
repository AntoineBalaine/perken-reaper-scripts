const std = @import("std");
const reaper = @import("reaper").reaper;
const fs_helpers = @import("fs_helpers");
const FileSystemOps = fs_helpers.FileSystemOps;
const joinStrings = fs_helpers.joinStrings;
const ensureDir = fs_helpers.ensureDir;
const ensureFile = fs_helpers.ensureFile;
const MappableModule = @import("mft_mappings.zig").MappableModule;

// Factory default maps derived from the Console One factory maps. They are
// embedded in the binary and written to disk on first run so that the defaults
// can always be restored. Each entry pairs a module directory and the FX name
// (which becomes the on-disk directory after sanitizing) with its content.
const FactoryMap = struct {
    module_dir: []const u8,
    fx_name: []const u8,
    content: []const u8,
};

const factory_maps = [_]FactoryMap{
    .{ .module_dir = "EQ", .fx_name = "VST: ReaEQ (Cockos)", .content = @embedFile("resources/maps/factory/EQ/reaeq/default.ini") },
    .{ .module_dir = "COMP", .fx_name = "VST: ReaComp (Cockos)", .content = @embedFile("resources/maps/factory/COMP/reacomp/default.ini") },
    .{ .module_dir = "GATE", .fx_name = "VST: ReaGate (Cockos)", .content = @embedFile("resources/maps/factory/GATE/reagate/default.ini") },
    // The input plugins are on the page of the input and the output plugins on the page of the output, each on its own knobs.
    .{ .module_dir = "INPUT", .fx_name = "JS: RBJ Highpass/Lowpass Filters", .content = @embedFile("resources/maps/factory/INPUT/rbj_filters/default.ini") },
    .{ .module_dir = "INPUT", .fx_name = "JS: Volume/Pan Smoother v5", .content = @embedFile("resources/maps/factory/INPUT/vol_pan/default.ini") },
    .{ .module_dir = "INPUT", .fx_name = "JS: Volume Adjustment", .content = @embedFile("resources/maps/factory/INPUT/vol_adj/default.ini") },
    .{ .module_dir = "OUTPUT", .fx_name = "JS: ReaAnalog", .content = @embedFile("resources/maps/factory/OUTPUT/reaanalog/default.ini") },
    .{ .module_dir = "OUTPUT", .fx_name = "JS: Saturation", .content = @embedFile("resources/maps/factory/OUTPUT/saturation/default.ini") },
};

/// Writes a factory map. A factory map is the default that ships with the extension, so when the file on disk is not the shipped one it is
/// an older default, or a copy that someone edited. Because the shipped layout has to take effect, the file is replaced, and because the
/// edit must not be lost, the file that was there is kept next to it as `default.ini.old`, replacing an older `.old`.
fn refreshFactoryFile(io: std.Io, fs_ops: FileSystemOps, path: []const u8, contents: []const u8) !void {
    var existing_buf: [4096]u8 = undefined;
    if (std.Io.Dir.cwd().readFile(io, path, &existing_buf)) |existing| {
        if (std.mem.eql(u8, existing, contents)) return;
        var old_buf: [std.fs.max_path_bytes]u8 = undefined;
        const old_path = joinStrings(&old_buf, &.{ path, ".old" });
        try std.Io.Dir.renameAbsolute(path, old_path, io);
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    try ensureFile(fs_ops, path, contents);
}

pub fn ensureConfigPath(io: std.Io, fs_ops: FileSystemOps) !void {
    const reaper_path = reaper.GetResourcePath();
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;

    const perken_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0), std.fs.path.sep_str, "Data", std.fs.path.sep_str, "Perken",
    });
    try ensureDir(fs_ops, perken_path);

    const mft_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0), std.fs.path.sep_str, "Data", std.fs.path.sep_str, "Perken", std.fs.path.sep_str, "MFT",
    });
    try ensureDir(fs_ops, mft_path);

    const maps_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0), std.fs.path.sep_str, "Data", std.fs.path.sep_str, "Perken", std.fs.path.sep_str, "MFT", std.fs.path.sep_str, "maps",
    });
    try ensureDir(fs_ops, maps_path);

    const factory_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0), std.fs.path.sep_str, "Data", std.fs.path.sep_str, "Perken", std.fs.path.sep_str, "MFT", std.fs.path.sep_str, "maps", std.fs.path.sep_str, "factory",
    });
    try ensureDir(fs_ops, factory_path);

    // Because older versions named FX folders with characters that Windows
    // forbids (such as "JS: ReaAnalog"), and the store now looks them up by
    // their Windows-safe name, we rename existing folders before anything
    // looks them up or writes defaults next to them.
    var module_buf: [std.fs.max_path_bytes]u8 = undefined;
    inline for (comptime std.enums.values(MappableModule)) |module| {
        const module_dir = joinStrings(&module_buf, &.{ factory_path, std.fs.path.sep_str, module.dirName() });
        fs_helpers.migrateFolderNames(io, module_dir) catch |err| {
            std.log.scoped(.mft_maps).err("Failed to rename legacy map folders in {s}: {s}", .{ module_dir, @errorName(err) });
        };
    }

    // Because the map store reads maps/factory/<MODULE>/<sanitized fx_name>/default.ini,
    // we write each default map into the directory named after its FX so that
    // the on-disk layout matches what the store looks up at runtime.
    var name_buf: [512:0]u8 = undefined;
    var fx_buf: [std.fs.max_path_bytes]u8 = undefined;
    var file_buf: [std.fs.max_path_bytes]u8 = undefined;
    inline for (factory_maps) |m| {
        const module_dir = joinStrings(&module_buf, &.{ factory_path, std.fs.path.sep_str, m.module_dir });
        try ensureDir(fs_ops, module_dir);

        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, m.fx_name);
        const fx_dir = joinStrings(&fx_buf, &.{ module_dir, std.fs.path.sep_str, sanitized });
        try ensureDir(fs_ops, fx_dir);

        const file_path = joinStrings(&file_buf, &.{ fx_dir, std.fs.path.sep_str, "default.ini" });
        try refreshFactoryFile(io, fs_ops, file_path, m.content);
    }
}
