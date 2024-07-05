const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;
const State = @import("../internals/state.zig");
const c = @cImport({
    @cInclude("csurf/control_surface_wrapper.h");
});

var state: *State = undefined;
pub fn init(initState: *State) c.C_ControlSurface {
    state = initState;
    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    return myCsurf;
}

pub fn deinit(csurf: c.C_ControlSurface) void {
    c.ControlSurface_Destroy(csurf);
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
    // std.debug.print("CloseNoReset\n", .{});
}
export fn zRun() callconv(.C) void {
    // myStruct.callMe();
    // std.debug.print("Run\n",.{});
}
export fn zSetTrackListChange() callconv(.C) void {
    std.debug.print("SetTrackListChange\n", .{});
    state.*.csurfCB();
}
export fn zSetSurfaceVolume(trackid: *MediaTrack, volume: f64) callconv(.C) void {
    _ = trackid;
    _ = volume;
    // std.debug.print("SetSurfaceVolume\n", .{});
}
export fn zSetSurfacePan(trackid: *MediaTrack, pan: f64) callconv(.C) void {
    _ = trackid;
    _ = pan;
    // std.debug.print("SetSurfacePan\n", .{});
}
export fn zSetSurfaceMute(trackid: *MediaTrack, mute: bool) callconv(.C) void {
    _ = trackid;
    _ = mute;
    // std.debug.print("SetSurfaceMute\n", .{});
}
export fn zSetSurfaceSelected(trackid: *MediaTrack, selected: bool) callconv(.C) void {
    _ = trackid;
    _ = selected;
    std.debug.print("SetSurfaceSelected\n", .{});
}
export fn zSetSurfaceSolo(trackid: *MediaTrack, solo: bool) callconv(.C) void {
    _ = trackid;
    _ = solo;
    // std.debug.print("SetSurfaceSolo\n", .{});
}
export fn zSetSurfaceRecArm(trackid: *MediaTrack, recarm: bool) callconv(.C) void {
    _ = trackid;
    _ = recarm;
    // std.debug.print("SetSurfaceRecArm\n", .{});
}
export fn zSetPlayState(play: bool, pause: bool, rec: bool) callconv(.C) void {
    _ = play;
    _ = pause;
    _ = rec;
    // std.debug.print("SetPlayState\n", .{});
}
export fn zSetRepeatState(rep: bool) callconv(.C) void {
    _ = rep;
    // std.debug.print("SetRepeatState\n", .{});
}
export fn zSetTrackTitle(trackid: *MediaTrack, title: [*]const u8) callconv(.C) void {
    _ = trackid;
    _ = title;
    // std.debug.print("SetTrackTitle\n", .{});
}
export fn zGetTouchState(trackid: *MediaTrack, isPan: c_int) callconv(.C) bool {
    _ = trackid;
    _ = isPan;
    std.debug.print("GetTouchState\n", .{});
    return false;
}
export fn zSetAutoMode(mode: c_int) callconv(.C) void {
    _ = mode;

    // std.debug.print("SetAutoMode\n", .{});
}
export fn zResetCachedVolPanStates() callconv(.C) void {
    // std.debug.print("ResetCachedVolPanStates\n", .{});
}
export fn zOnTrackSelection(trackid: MediaTrack) callconv(.C) void {
    std.debug.print("OnTrackSelection\n", .{});
    state.handleNewTrack(trackid);
}
export fn zIsKeyDown(key: c_int) callconv(.C) bool {
    _ = key;
    // std.debug.print("IsKeyDown\n",.{});
    return false;
}
export fn zExtended(call: c_int, parm1: ?*c_void, parm2: ?*c_void, parm3: ?*c_void) callconv(.C) c_int {
    _ = parm1;
    _ = parm2;
    _ = parm3;
    // std.debug.print("Extended\n", .{});
    switch (call) {
        0x0001FFFF => std.debug.print("CSURF_EXT_RESET\n", .{}), // clear all surface state and reset (harder reset than SetTrackListChange)
        0x00010001 => std.debug.print("CSURF_EXT_SETINPUTMONITOR\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)recmonitor
        0x00010002 => std.debug.print("CSURF_EXT_SETMETRONOME\n", .{}), // parm1=0 to disable metronome, !0 to enable
        0x00010003 => std.debug.print("CSURF_EXT_SETAUTORECARM\n", .{}), // parm1=0 to disable autorecarm, !0 to enable
        0x00010004 => std.debug.print("CSURF_EXT_SETRECMODE\n", .{}), // parm1=(int*)record mode: 0=autosplit and create takes, 1=replace (tape) mode
        0x00010005 => std.debug.print("CSURF_EXT_SETSENDVOLUME\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)sendidx, parm3=(double*)volume
        0x00010006 => std.debug.print("CSURF_EXT_SETSENDPAN\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)sendidx, parm3=(double*)pan
        0x00010007 => std.debug.print("CSURF_EXT_SETFXENABLED\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)fxidx, parm3=0 if bypassed, !0 if enabled
        0x00010008 => std.debug.print("CSURF_EXT_SETFXPARAM\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)(fxidx<<16|paramidx), parm3=(double*)normalized value
        0x00010018 => std.debug.print("CSURF_EXT_SETFXPARAM_RECFX\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)(fxidx<<16|paramidx), parm3=(double*)normalized value
        0x00010009 => std.debug.print("CSURF_EXT_SETBPMANDPLAYRATE\n", .{}), // parm1=*(double*)bpm (may be NULL), parm2=*(double*)playrate (may be NULL)
        0x0001000A => std.debug.print("CSURF_EXT_SETLASTTOUCHEDFX\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all parms NULL=clear last touched FX
        0x0001000B => std.debug.print("CSURF_EXT_SETFOCUSEDFX\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all parms NULL=clear focused FX
        0x0001000C => std.debug.print("CSURF_EXT_SETLASTTOUCHEDTRACK\n", .{}), // parm1=(MediaTrack*)track
        0x0001000D => std.debug.print("CSURF_EXT_SETMIXERSCROLL\n", .{}), // parm1=(MediaTrack*)track, leftmost track visible in the mixer
        0x0001000E => std.debug.print("CSURF_EXT_SETPAN_EX\n", .{}), // parm1=(MediaTrack*)track, parm2=(double*)pan, parm3=(int*)mode 0=v1-3 balance, 3=v4+ balance, 5=stereo pan, 6=dual pan. for modes 5 and 6, (double*)pan points to an array of two doubles.  if a csurf supports CSURF_EXT_SETPAN_EX, it should ignore CSurf_SetSurfacePan.
        0x00010010 => std.debug.print("CSURF_EXT_SETRECVVOLUME\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)recvidx, parm3=(double*)volume
        0x00010011 => std.debug.print("CSURF_EXT_SETRECVPAN\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)recvidx, parm3=(double*)pan
        0x00010012 => std.debug.print("CSURF_EXT_SETFXOPEN\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)fxidx, parm3=0 if UI closed, !0 if open
        0x00010013 => std.debug.print("CSURF_EXT_SETFXCHANGE\n", .{}), // parm1=(MediaTrack*)track, whenever FX are added, deleted, or change order. flags=(INT_PTR)parm2, &1=rec fx
        0x00010014 => std.debug.print("CSURF_EXT_SETPROJECTMARKERCHANGE\n", .{}), // whenever project markers are changed
        0x00010015 => std.debug.print("CSURF_EXT_TRACKFX_PRESET_CHANGED\n", .{}), // parm1=(MediaTrack*)track, parm2=(int*)fxidx (6.13+ probably)
        0x00080001 => std.debug.print("CSURF_EXT_SUPPORTS_EXTENDED_TOUCH\n", .{}), // returns nonzero if GetTouchState can take isPan=2 for width, etc
        0x00010099 => std.debug.print("CSURF_EXT_MIDI_DEVICE_REMAP\n", .{}), // parm1 = isout, parm2 = old idx, parm3 = new idx
        else => unreachable,
    }
    return 0;
}
