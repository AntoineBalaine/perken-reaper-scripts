// Type definitions for the FX parser, extracted so that UI-side code can
// reference these types without pulling in fx_parser.zig (which imports
// reaper.zig for REAPER API calls).

const std = @import("std");

pub const FxType = enum {
    VST,
    VSTi,
    VST3,
    VST3i,
    JS,
    AU,
    AUi,
    CLAP,
    CLAPi,
    LV2,
    LV2i,
    Container,
    VideoProcessor,
};

pub const FxList = std.StringArrayHashMapUnmanaged(void);
pub const TagList = std.StringArrayHashMapUnmanaged(FxList);
pub const FxByType = std.EnumArray(FxType, FxList);
pub const DirectoryList = std.AutoArrayHashMapUnmanaged(c_int, Directory);

pub const FxTags = struct {
    category: TagList,
    developer: TagList,
};

pub const Directory = struct {
    path: [:0]const u8,
    name: [:0]const u8,
    subdirs: ?DirectoryList,
    files: ?std.StringArrayHashMapUnmanaged(void),
};
