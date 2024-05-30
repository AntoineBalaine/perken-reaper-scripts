const std = @import("std");
const Reaper = @import("reaper.zig");
const ShowConsoleMsg = Reaper.ShowConsoleMsg;
const MediaTrack = Reaper.MediaTrack;
const c_void = anyopaque;

const c = @cImport({
    @cInclude("./fakeCSurfWrapper.h");
});

pub fn fakeCSurf() c.C_FakeCsurf {
    const surface = zigCsurf{
        .GetTypeString = &GetTypeString,
        .GetDescString = &GetDescString,
        .GetConfigString = &GetConfigString,
    };
    // Create a new FakeCsurf instance
    const myCsurf: c.C_FakeCsurf = c.FakeCsurf_Create(@constCast(@ptrCast(&surface)));
    return myCsurf;
}

fn GetTypeString(self: *zigCsurf) callconv(.C) [*]const u8 {
    _ = self;
    return "";
}

fn GetDescString(self: *zigCsurf) callconv(.C) [*]const u8 {
    _ = self;
    return "";
}

fn GetConfigString(self: *zigCsurf) callconv(.C) [*]const u8 {
    _ = self;
    return "";
}

const zigCsurf = extern struct {
    GetTypeString: *const fn (self: *zigCsurf) callconv(.C) [*]const u8,
    GetDescString: *const fn (self: *zigCsurf) callconv(.C) [*]const u8,
    GetConfigString: *const fn (self: *zigCsurf) callconv(.C) [*]const u8,
    pub fn CloseNoReset(self: *zigCsurf) callconv(.C) void {
        _ = self;
        ShowConsoleMsg("CloseNoReset\n");
    }
    pub fn Run(self: *zigCsurf) callconv(.C) void {
        _ = self;
        ShowConsoleMsg("Run\n");
    }
    pub fn SetTrackListChange(self: *zigCsurf) callconv(.C) void {
        _ = self;
        ShowConsoleMsg("SetTrackListChange\n");
    }
    pub fn SetSurfaceVolume(self: *zigCsurf, trackid: *MediaTrack, volume: f64) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = volume;
        ShowConsoleMsg("SetSurfaceVolume\n");
    }
    pub fn SetSurfacePan(self: *zigCsurf, trackid: *MediaTrack, pan: f64) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = pan;
        ShowConsoleMsg("SetSurfacePan\n");
    }
    pub fn SetSurfaceMute(self: *zigCsurf, trackid: *MediaTrack, mute: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = mute;
        ShowConsoleMsg("SetSurfaceMute\n");
    }
    pub fn SetSurfaceSelected(self: *zigCsurf, trackid: *MediaTrack, selected: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = selected;
        ShowConsoleMsg("SetSurfaceSelected\n");
    }
    pub fn SetSurfaceSolo(self: *zigCsurf, trackid: *MediaTrack, solo: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = solo;
        ShowConsoleMsg("SetSurfaceSolo\n");
    }
    pub fn SetSurfaceRecArm(self: *zigCsurf, trackid: *MediaTrack, recarm: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = recarm;
        ShowConsoleMsg("SetSurfaceRecArm\n");
    }
    pub fn SetPlayState(self: *zigCsurf, play: bool, pause: bool, rec: bool) callconv(.C) void {
        _ = self;
        _ = play;
        _ = pause;
        _ = rec;
        ShowConsoleMsg("SetPlayState\n");
    }
    pub fn SetRepeatState(self: *zigCsurf, rep: bool) callconv(.C) void {
        _ = self;
        _ = rep;
        ShowConsoleMsg("SetRepeatState\n");
    }
    pub fn SetTrackTitle(self: *zigCsurf, trackid: *MediaTrack, title: [*]const u8) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = title;
        ShowConsoleMsg("SetTrackTitle\n");
    }
    pub fn GetTouchState(self: *zigCsurf, trackid: *MediaTrack, isPan: c_int) callconv(.C) bool {
        _ = self;
        _ = trackid;
        _ = isPan;
        ShowConsoleMsg("GetTouchState\n");
        return false;
    }
    pub fn SetAutoMode(self: *zigCsurf, mode: c_int) callconv(.C) void {
        _ = self;
        _ = mode;

        ShowConsoleMsg("SetAutoMode\n");
    }
    pub fn ResetCachedVolPanStates(self: *zigCsurf) callconv(.C) void {
        _ = self;

        ShowConsoleMsg("ResetCachedVolPanStates\n");
    }
    pub fn OnTrackSelection(self: *zigCsurf, trackid: *MediaTrack) callconv(.C) void {
        _ = self;
        _ = trackid;
        ShowConsoleMsg("OnTrackSelection\n");
    }
    pub fn IsKeyDown(self: *zigCsurf, key: c_int) callconv(.C) bool {
        _ = self;
        _ = key;
        ShowConsoleMsg("IsKeyDown\n");
        return false;
    }
    pub fn Extended(self: *zigCsurf, call: c_int, parm1: ?*c_void, parm2: ?*c_void, parm3: ?*c_void) callconv(.C) c_int {
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
