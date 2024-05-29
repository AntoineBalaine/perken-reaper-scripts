const std = @import("std");
const Reaper = @import("reaper.zig");
const ShowConsoleMsg = Reaper.ShowConsoleMsg;
const MediaTrack = Reaper.MediaTrack;
const c_void = anyopaque;

const c = @cImport({
    @cInclude("./fakeCSurfWrapper.h");
});

pub fn fakeCSurf() c.C_FakeCsurf {
    const surface = IReaperControlSurface{
        .GetTypeString = &GetTypeString,
        .GetDescString = &GetDescString,
        .GetConfigString = &GetConfigString,
    };
    // Create a new FakeCsurf instance
    const myCsurf: c.C_FakeCsurf = c.FakeCsurf_Create(@ptrCast(&surface));
    return myCsurf;
}

// const IReaperControlSurface = extern struct {
//     GetTypeString: fn (self: *IReaperControlSurface) callconv(.C) [*]const u8,
//     GetDescString: fn (self: *IReaperControlSurface) callconv(.C) [*]const u8,
//     GetConfigString: fn (self: *IReaperControlSurface) callconv(.C) [*]const u8,
//     CloseNoReset: fn (self: *IReaperControlSurface) callconv(.C) void,
//     Run: fn (self: *IReaperControlSurface) callconv(.C) void,
//     SetTrackListChange: fn (self: *IReaperControlSurface) callconv(.C) void,
//     SetSurfaceVolume: fn (self: *IReaperControlSurface, trackid: *MediaTrack, volume: f64) callconv(.C) void,
//     SetSurfacePan: fn (self: *IReaperControlSurface, trackid: *MediaTrack, pan: f64) callconv(.C) void,
//     SetSurfaceMute: fn (self: *IReaperControlSurface, trackid: *MediaTrack, mute: bool) callconv(.C) void,
//     SetSurfaceSelected: fn (self: *IReaperControlSurface, trackid: *MediaTrack, selected: bool) callconv(.C) void,
//     SetSurfaceSolo: fn (self: *IReaperControlSurface, trackid: *MediaTrack, solo: bool) callconv(.C) void,
//     SetSurfaceRecArm: fn (self: *IReaperControlSurface, trackid: *MediaTrack, recarm: bool) callconv(.C) void,
//     SetPlayState: fn (self: *IReaperControlSurface, play: bool, pause: bool, rec: bool) callconv(.C) void,
//     SetRepeatState: fn (self: *IReaperControlSurface, rep: bool) callconv(.C) void,
//     SetTrackTitle: fn (self: *IReaperControlSurface, trackid: *MediaTrack, title: [*]const u8) callconv(.C) void,
//     GetTouchState: fn (self: *IReaperControlSurface, trackid: *MediaTrack, isPan: c_int) callconv(.C) bool,
//     SetAutoMode: fn (self: *IReaperControlSurface, mode: c_int) callconv(.C) void,
//     ResetCachedVolPanStates: fn (self: *IReaperControlSurface) callconv(.C) void,
//     OnTrackSelection: fn (self: *IReaperControlSurface, trackid: *MediaTrack) callconv(.C) void,
//     IsKeyDown: fn (self: *IReaperControlSurface, key: c_int) callconv(.C) bool,
//     Extended: fn (self: *IReaperControlSurface, call: c_int, parm1: ?*c_void, parm2: ?*c_void, parm3: ?*c_void) callconv(.C) c_int,
// };

fn GetTypeString(self: *IReaperControlSurface) callconv(.C) [*]const u8 {
    _ = self;
    return "";
}

fn GetDescString(self: *IReaperControlSurface) callconv(.C) [*]const u8 {
    _ = self;
    return "";
}

fn GetConfigString(self: *IReaperControlSurface) callconv(.C) [*]const u8 {
    _ = self;
    return "";
}

const IReaperControlSurface = struct {
    GetTypeString: *const fn (self: *IReaperControlSurface) callconv(.C) [*]const u8,
    GetDescString: *const fn (self: *IReaperControlSurface) callconv(.C) [*]const u8,
    GetConfigString: *const fn (self: *IReaperControlSurface) callconv(.C) [*]const u8,
    pub fn CloseNoReset(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        ShowConsoleMsg("CloseNoReset\n");
    }
    pub fn Run(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        ShowConsoleMsg("Run\n");
    }
    pub fn SetTrackListChange(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        ShowConsoleMsg("SetTrackListChange\n");
    }
    pub fn SetSurfaceVolume(self: *IReaperControlSurface, trackid: *MediaTrack, volume: f64) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = volume;
        ShowConsoleMsg("SetSurfaceVolume\n");
    }
    pub fn SetSurfacePan(self: *IReaperControlSurface, trackid: *MediaTrack, pan: f64) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = pan;
        ShowConsoleMsg("SetSurfacePan\n");
    }
    pub fn SetSurfaceMute(self: *IReaperControlSurface, trackid: *MediaTrack, mute: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = mute;
        ShowConsoleMsg("SetSurfaceMute\n");
    }
    pub fn SetSurfaceSelected(self: *IReaperControlSurface, trackid: *MediaTrack, selected: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = selected;
        ShowConsoleMsg("SetSurfaceSelected\n");
    }
    pub fn SetSurfaceSolo(self: *IReaperControlSurface, trackid: *MediaTrack, solo: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = solo;
        ShowConsoleMsg("SetSurfaceSolo\n");
    }
    pub fn SetSurfaceRecArm(self: *IReaperControlSurface, trackid: *MediaTrack, recarm: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = recarm;
        ShowConsoleMsg("SetSurfaceRecArm\n");
    }
    pub fn SetPlayState(self: *IReaperControlSurface, play: bool, pause: bool, rec: bool) callconv(.C) void {
        _ = self;
        _ = play;
        _ = pause;
        _ = rec;
        ShowConsoleMsg("SetPlayState\n");
    }
    pub fn SetRepeatState(self: *IReaperControlSurface, rep: bool) callconv(.C) void {
        _ = self;
        _ = rep;
        ShowConsoleMsg("SetRepeatState\n");
    }
    pub fn SetTrackTitle(self: *IReaperControlSurface, trackid: *MediaTrack, title: [*]const u8) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = title;
        ShowConsoleMsg("SetTrackTitle\n");
    }
    pub fn GetTouchState(self: *IReaperControlSurface, trackid: *MediaTrack, isPan: c_int) callconv(.C) bool {
        _ = self;
        _ = trackid;
        _ = isPan;
        ShowConsoleMsg("GetTouchState\n");
        return false;
    }
    pub fn SetAutoMode(self: *IReaperControlSurface, mode: c_int) callconv(.C) void {
        _ = self;
        _ = mode;

        ShowConsoleMsg("SetAutoMode\n");
    }
    pub fn ResetCachedVolPanStates(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;

        ShowConsoleMsg("ResetCachedVolPanStates\n");
    }
    pub fn OnTrackSelection(self: *IReaperControlSurface, trackid: *MediaTrack) callconv(.C) void {
        _ = self;
        _ = trackid;
        ShowConsoleMsg("OnTrackSelection\n");
    }
    pub fn IsKeyDown(self: *IReaperControlSurface, key: c_int) callconv(.C) bool {
        _ = self;
        _ = key;
        ShowConsoleMsg("IsKeyDown\n");
        return false;
    }
    pub fn Extended(self: *IReaperControlSurface, call: c_int, parm1: ?*c_void, parm2: ?*c_void, parm3: ?*c_void) callconv(.C) c_int {
        _ = self;
        _ = call;
        _ = parm1;
        _ = parm2;
        _ = parm3;
        ShowConsoleMsg("Extended\n");
        return 0;
    }
};

// pub const fakeCsurf = IReaperControlSurface{
//     .GetTypeString = &GetTypeString,
//     .GetDescString = &GetDescString,
//     .GetConfigString = &GetConfigString,
// };
