const std = @import("std");
const reaper = @import("reaper").reaper;
const fs_helpers = @import("fs_helpers");
const FileSystemOps = fs_helpers.FileSystemOps;
const joinStrings = fs_helpers.joinStrings;
const ensureDir = fs_helpers.ensureDir;

pub fn ensureConfigPath(fs_ops: FileSystemOps) !void {
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
}
