const std = @import("std");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;

const c = @cImport({
    @cInclude("./control_surface_wrapper.h");
});

pub fn init() c.C_ControlSurface {
    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    return myCsurf;
}

fn GetTypeString() callconv(.C) [*]const u8 {
    return "";
}

fn GetDescString() callconv(.C) [*]const u8 {
    return "";
}

fn GetConfigString() callconv(.C) [*]const u8 {
    return "";
}
export const zGetTypeString = &GetTypeString;

export const zGetDescString = &GetDescString;

export const zGetConfigString = &GetConfigString;

export fn zCloseNoReset() callconv(.C) void {
    reaper.ShowConsoleMsg("CloseNoReset\n");
}
export fn zRun() callconv(.C) void {
    reaper.ShowConsoleMsg("Run\n");
}
export fn zSetTrackListChange() callconv(.C) void {
    reaper.ShowConsoleMsg("SetTrackListChange\n");
}
export fn zSetSurfaceVolume(trackid: *MediaTrack, volume: f64) callconv(.C) void {
    _ = trackid;
    _ = volume;
    reaper.ShowConsoleMsg("SetSurfaceVolume\n");
}
export fn zSetSurfacePan(trackid: *MediaTrack, pan: f64) callconv(.C) void {
    _ = trackid;
    _ = pan;
    reaper.ShowConsoleMsg("SetSurfacePan\n");
}
export fn zSetSurfaceMute(trackid: *MediaTrack, mute: bool) callconv(.C) void {
    _ = trackid;
    _ = mute;
    reaper.ShowConsoleMsg("SetSurfaceMute\n");
}
export fn zSetSurfaceSelected(trackid: *MediaTrack, selected: bool) callconv(.C) void {
    _ = trackid;
    _ = selected;
    reaper.ShowConsoleMsg("SetSurfaceSelected\n");
}
export fn zSetSurfaceSolo(trackid: *MediaTrack, solo: bool) callconv(.C) void {
    _ = trackid;
    _ = solo;
    reaper.ShowConsoleMsg("SetSurfaceSolo\n");
}
export fn zSetSurfaceRecArm(trackid: *MediaTrack, recarm: bool) callconv(.C) void {
    _ = trackid;
    _ = recarm;
    reaper.ShowConsoleMsg("SetSurfaceRecArm\n");
}
export fn zSetPlayState(play: bool, pause: bool, rec: bool) callconv(.C) void {
    _ = play;
    _ = pause;
    _ = rec;
    reaper.ShowConsoleMsg("SetPlayState\n");
}
export fn zSetRepeatState(rep: bool) callconv(.C) void {
    _ = rep;
    reaper.ShowConsoleMsg("SetRepeatState\n");
}
export fn zSetTrackTitle(trackid: *MediaTrack, title: [*]const u8) callconv(.C) void {
    _ = trackid;
    _ = title;
    reaper.ShowConsoleMsg("SetTrackTitle\n");
}
export fn zGetTouchState(trackid: *MediaTrack, isPan: c_int) callconv(.C) bool {
    _ = trackid;
    _ = isPan;
    reaper.ShowConsoleMsg("GetTouchState\n");
    return false;
}
export fn zSetAutoMode(mode: c_int) callconv(.C) void {
    _ = mode;

    reaper.ShowConsoleMsg("SetAutoMode\n");
}
export fn zResetCachedVolPanStates() callconv(.C) void {
    reaper.ShowConsoleMsg("ResetCachedVolPanStates\n");
}
export fn zOnTrackSelection(trackid: *MediaTrack) callconv(.C) void {
    _ = trackid;
    reaper.ShowConsoleMsg("OnTrackSelection\n");
}
export fn zIsKeyDown(key: c_int) callconv(.C) bool {
    _ = key;
    reaper.ShowConsoleMsg("IsKeyDown\n");
    return false;
}
export fn zExtended(call: c_int, parm1: ?*c_void, parm2: ?*c_void, parm3: ?*c_void) callconv(.C) c_int {
    _ = call;
    _ = parm1;
    _ = parm2;
    _ = parm3;
    reaper.ShowConsoleMsg("Extended\n");
    return 0;
}
