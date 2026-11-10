const std = @import("std");
const reaper = @import("reaper").reaper;
const fs_helpers = @import("fs_helpers");
const FileSystemOps = fs_helpers.FileSystemOps;
const joinStrings = fs_helpers.joinStrings;
const ensureDir = fs_helpers.ensureDir;
const ensureFile = fs_helpers.ensureFile;
const MappableModule = @import("mft_mappings.zig").MappableModule;

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
    // looks them up. The maps themselves are installed by extensions/install-maps.sh, apart from the binary.
    var module_buf: [std.fs.max_path_bytes]u8 = undefined;
    inline for (comptime std.enums.values(MappableModule)) |module| {
        const module_dir = joinStrings(&module_buf, &.{ factory_path, std.fs.path.sep_str, module.dirName() });
        fs_helpers.migrateFolderNames(io, module_dir) catch |err| {
            std.log.scoped(.mft_maps).err("Failed to rename legacy map folders in {s}: {s}", .{ module_dir, @errorName(err) });
        };
    }
}
