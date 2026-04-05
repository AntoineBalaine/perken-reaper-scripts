const std = @import("std");
const AutomationMode = @import("automation_mode").AutomationMode;
const utils = @import("utils");
const fx_model = @import("fx_model");
const FX = fx_model.FX;
pub const TrackInfo = struct {
    phase: bool = false,
    num_channels: i32 = 2,
    volume: f64 = 1.0,
    pan: f64 = 0.0,
    mute: bool = false,
    solo: i32 = 0,
};

pub const PeakInfo = struct {
    left: f64 = 0.0,
    right: f64 = 0.0,
};

pub const Track = struct {
    /// owned by its parent session
    name: ?utils.StringPool.StringRef,
    fx_list: std.ArrayListUnmanaged(FX),
    automation_mode: AutomationMode,
    info: TrackInfo,
    /// only when playing
    peak_info: ?PeakInfo,

    pub const default: @This() = .{
        .name = null,
        .fx_list = std.ArrayListUnmanaged(FX).empty,
        .automation_mode = .read,
        .info = .{},
        .peak_info = null,
    };
};
