const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;
const State = @import("../internals/state.zig");
const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("../WDL/swell/swell-types.h");
    @cInclude("../WDL/swell/swell-functions.h");
    @cInclude("../WDL/win32_utf8.h");
    @cInclude("../WDL/wdltypes.h");
    @cInclude("resource.h");
});
const m = @import("midi_wrapper.zig");
pub var g_hInst: reaper.HINSTANCE = undefined;
fn sendDlgItemMessage(hwnd: c.HWND, idx: c_int, msg: c.UINT, wparam: c.WPARAM, lparam: c.LPARAM) c.LRESULT {
    // c.SendDlgItemMessage()
    return c.SendMessage.?(c.GetDlgItem.?(hwnd, idx), msg, wparam, lparam);
}

fn dlgProc(hwndDlg: c.HWND, uMsg: c_uint, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) c.WDL_DLGRET {
    switch (uMsg) {
        c.WM_INITDIALOG => {
            var parms: [4]i32 = undefined;
            parseParms(lParam, &parms);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT1), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT1_LBL), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2_LBL), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2_LBL2), c.SW_HIDE);

            // zig’s translateC can’t convert the type of WDL_UTF8_HookComboBox.
            // That function’s a compat define when utf8 is disabled.
            // fingers crossed, and hope that doesn’t happen.
            // c.WDL_UTF8_HookComboBox(c.GetDlgItem(hwndDlg, c.IDC_COMBO2));
            // c.WDL_UTF8_HookComboBox(c.GetDlgItem(hwndDlg, c.IDC_COMBO3));
            var n = reaper.GetNumMIDIInputs();
            const loc = reaper.LocalizeString("None", "csurf", 0);
            var x = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_ADDSTRING, 0, @as(c.LPARAM, @intCast(@intFromPtr(loc))));
            _ = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_SETITEMDATA, @as(c.WPARAM, @intCast(x)), -1);
            x = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_ADDSTRING, 0, @as(c.LPARAM, @intCast(@intFromPtr(loc))));
            _ = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_SETITEMDATA, @as(c.WPARAM, @intCast(x)), -1);
            var cur: c_int = 0;
            while (cur < n) : (cur += 1) {
                var buf: [512]c_char = undefined;
                if (reaper.GetMIDIInputName(cur, &buf, @sizeOf(@TypeOf(buf)))) {
                    const a: c.WPARAM = @intCast(sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_ADDSTRING, @as(c.WPARAM, 0), @as(c.LPARAM, @intCast(@intFromPtr(&buf)))));
                    _ = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_SETITEMDATA, a, cur);

                    if (cur == parms[2]) {
                        _ = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_SETCURSEL, a, 0);
                    }
                }
            }

            n = reaper.GetNumMIDIOutputs();
            cur = 0;

            while (cur < n) : (cur += 1) {
                var buf: [512]c_char = undefined;
                if (reaper.GetMIDIOutputName(@intCast(cur), &buf, @sizeOf(@TypeOf(buf)))) {
                    const a: c.WPARAM = @intCast(sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_ADDSTRING, 0, @as(c.LPARAM, @intCast(@intFromPtr(&buf)))));
                    _ = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_SETITEMDATA, a, @as(c.LPARAM, @intCast(cur)));
                    if (cur == parms[3]) {
                        _ = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_SETCURSEL, a, 0);
                    }
                }
            }
        },
        c.WM_USER + 1024 => {
            if (wParam > 1 and lParam != 0) {
                var tmp: [512]u8 = undefined;
                var indev: isize = -1;
                var outdev: isize = -1;
                var r = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_GETCURSEL, 0, 0);
                if (r != c.CB_ERR) indev = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_GETITEMDATA, @as(c.WPARAM, @intCast(r)), 0);

                r = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_GETCURSEL, 0, 0);
                if (r != c.CB_ERR) outdev = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_GETITEMDATA, @as(c.WPARAM, @intCast(r)), 0);

                const buffer: []u8 = &tmp;
                _ = std.fmt.bufPrint(buffer, "0 0 {d} {d}", .{ indev, outdev }) catch {};
                _ = c.lstrcpyn.?(lParam, &tmp, @as(c_int, @intCast(wParam)));
            }
        },
        else => {},
    }
    return 0;
}

fn makeIntResource(x: anytype) [*c]const u8 {
    return @ptrFromInt(@as(u32, @intCast(x)));
}

pub fn configFunc(type_string: [*c]const u8, parent: c.HWND, initConfigString: [*c]const u8) callconv(.C) c.HWND {
    std.debug.print("configFunc\n", .{});
    _ = type_string;
    const cast: c.LPARAM = @intCast(@intFromPtr(initConfigString));
    // const cast: c.LPARAM = @intCast(initConfigString);

    return c.SWELL_CreateDialog.?(c.SWELL_curmodule_dialogresource_head, makeIntResource(c.IDD_SURFACEEDIT_MCU), parent, &dlgProc, cast);
    // return c.CreateDialogParam.?(g_hInst, makeIntResource(c.IDD_SURFACEEDIT_MCU), parent, &dlgProc, cast);
}

fn parseParms(str: [*c]const c_char, parms: *[4]i32) void {
    parms[0] = 0;
    parms[1] = 9;
    parms[2] = -1;
    parms[3] = -1;

    const cast: [*:0]const u8 = @ptrCast(str);
    var iterator = std.mem.splitScalar(u8, std.mem.span(cast), ' ');
    var i: u8 = 0;
    while (iterator.next()) |val| {
        if (!std.mem.eql(u8, "", val) and i < 4) {
            i += 1;
            parms[i] = std.fmt.parseInt(i32, val, 10) catch -1;
        }
    }
}

fn createFunc(type_string: [*c]const c_char, configString: [*c]const c_char, errStats: *c_int) callconv(.C) c.C_ControlSurface {
    std.debug.print("createFunc\n", .{});
    _ = type_string;
    var parms: [4]i32 = undefined;
    parseParms(configString, &parms);
    const myCsurf: c.C_ControlSurface = init(parms[2], parms[3], errStats);
    return myCsurf;
}

/// reaper_plugin.reaper_csurf_reg_t
const reaper_csurf_reg_t = extern struct {
    //
    type_string: [*:0]const u8,
    desc_string: [*:0]const u8,
    IReaperControlSurface: *const fn (type_string: [*:0]const c_char, configString: [*:0]const c_char, errStats: *c_int) callconv(.C) c.C_ControlSurface,
    ShowConfig: *const fn (type_string: [*c]const u8, parent: c.HWND, initConfigString: [*c]const u8) callconv(.C) c.HWND,
};

pub const c1_reg = reaper_csurf_reg_t{
    .type_string = "Console1",
    .desc_string = "Softube Console1",
    .IReaperControlSurface = &createFunc,
    .ShowConfig = &configFunc,
};

var m_midiin: ?reaper.midi_Input = null;
var m_midiout: ?reaper.midi_Output = null;

var state: *State = undefined;
pub fn init(indev: c_int, outdev: c_int, errStats: ?*c_int) c.C_ControlSurface {
    m_midiin = if (indev >= 0) reaper.CreateMIDIInput(indev) else null;
    // TODO : investigate whether the midioutput needs to be threaded
    // (this was the case in the faderport example)
    m_midiout = if (outdev >= 0) reaper.CreateMIDIOutput(outdev, false, null) else null;
    if (errStats) |errstats| {
        if (indev >= 0 and m_midiin == null) errstats.* |= 1;
        if (outdev >= 0 and m_midiout == null) errstats.* |= 2;
    }
    if (m_midiin) |midi_in| {
        m.MidiIn_start(midi_in);
    }
    if (m_midiout) |midi_out| {
        m.MidiOut_Send(midi_out, 0xb0, 0x00, 0x06, -1);
        m.MidiOut_Send(midi_out, 0xb0, 0x20, 0x27, -1);
        for (0..0x30) |x| { // lights out
            m.MidiOut_Send(midi_out, 0xa0, @as(u8, @intCast(x)), 0x00, -1);
        }
        m.MidiOut_Send(midi_out, 0x91, 0x00, 0x64, -1);
    }
    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    return myCsurf;
}

pub fn deinit(csurf: c.C_ControlSurface) void {
    if (m_midiout) |midiOut| {
        for (0..0x30) |x| { // lights out
            m.MidiOut_Send(midiOut, 0xa0, @as(u8, @intCast(x)), 0x00, -1);
        }
    }

    c.DELETE_ASYNC(m_midiout.?);
    c.DELETE_ASYNC(m_midiin.?);
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
    // state.*.csurfCB();
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
    _ = trackid;
    std.debug.print("OnTrackSelection\n", .{});
    // state.handleNewTrack(trackid);
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

test parseParms {
    const expect = std.testing.expect;

    var parms: [4]c_int = undefined;
    var my_arr = [5]c_char{ '1', ' ', '2', ' ', '3' };
    const str: [*]const c_char = &my_arr;
    try parseParms(str, &parms);
    try expect(parms[1] == 1);
    try expect(parms[2] == 2);
    // try expect(str[3] == 3);
}
