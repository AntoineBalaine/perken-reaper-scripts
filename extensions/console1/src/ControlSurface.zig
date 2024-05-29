const std = @import("std");
const reaper = @import("reaper.zig");

var void_ = anyopaque;

const MediaTrack = extern struct {}; // Replace with actual MediaTrack definition

// Declare the opaque type for IReaperControlSurface
const IReaperControlSurface = extern struct {
    GetTypeString: *fn (self: *IReaperControlSurface) callconv(.C) [*:0]const u8,
    GetDescString: *fn (self: *IReaperControlSurface) callconv(.C) [*:0]const u8,
    GetConfigString: *fn (self: *IReaperControlSurface) callconv(.C) [*:0]const u8,
    CloseNoReset: fn (self: *IReaperControlSurface) callconv(.C) void,
    Run: fn (self: *IReaperControlSurface) callconv(.C) void,
    SetTrackListChange: fn (self: *IReaperControlSurface) callconv(.C) void,
    SetSurfaceVolume: fn (self: *IReaperControlSurface, trackid: *MediaTrack, volume: f64) callconv(.C) void,
    SetSurfacePan: fn (self: *IReaperControlSurface, trackid: *MediaTrack, pan: f64) callconv(.C) void,
    SetSurfaceMute: fn (self: *IReaperControlSurface, trackid: *MediaTrack, mute: bool) callconv(.C) void,
    SetSurfaceSelected: fn (self: *IReaperControlSurface, trackid: *MediaTrack, selected: bool) callconv(.C) void,
    SetSurfaceSolo: fn (self: *IReaperControlSurface, trackid: *MediaTrack, solo: bool) callconv(.C) void,
    SetSurfaceRecArm: fn (self: *IReaperControlSurface, trackid: *MediaTrack, recarm: bool) callconv(.C) void,
    SetPlayState: fn (self: *IReaperControlSurface, play: bool, pause: bool, rec: bool) callconv(.C) void,
    SetRepeatState: fn (self: *IReaperControlSurface, rep: bool) callconv(.C) void,
    SetTrackTitle: fn (self: *IReaperControlSurface, trackid: *MediaTrack, title: [*:0]const u8) callconv(.C) void,
    GetTouchState: fn (self: *IReaperControlSurface, trackid: *MediaTrack, isPan: c_int) callconv(.C) bool,
    SetAutoMode: fn (self: *IReaperControlSurface, mode: c_int) callconv(.C) void,
    ResetCachedVolPanStates: fn (self: *IReaperControlSurface) callconv(.C) void,
    OnTrackSelection: fn (self: *IReaperControlSurface, trackid: *MediaTrack) callconv(.C) void,
    IsKeyDown: fn (self: *IReaperControlSurface, key: c_int) callconv(.C) bool,
    Extended: fn (self: *IReaperControlSurface, call: c_int, parm1: ?*void_, parm2: ?*void_, parm3: ?*void_) callconv(.C) c_int,
};
