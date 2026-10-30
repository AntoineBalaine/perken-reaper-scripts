const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper");
const reaper = Reaper.reaper;
const MediaTrack = reaper.MediaTrack;
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
const constants = @import("../constants_mft.zig");
const midi_events = @import("midi_events_mft.zig");
const midi_out = @import("../midi_out_mft.zig");
const MftGlobals = @import("../mft_globals.zig").MftGlobals;
const log = std.log.scoped(.csurf_mft);

// REAPER csurf Extended() call selector for the last-touched track change.
const CSURF_EXT_SETLASTTOUCHEDTRACK: c_int = 0x0001000C;

pub var ignore_notifications = false;
pub var my_csurf: c.C_ControlSurface = undefined;

pub fn init(indev: c_int, outdev: c_int, errStats: ?*c_int) c.C_ControlSurface {
    var globals = MftGlobals.get();
    globals.m_midi_in_dev = indev;
    globals.m_midi_out_dev = outdev;
    globals.m_midi_in = if (indev >= 0) reaper.CreateMIDIInput(indev) else null;
    globals.m_midi_out = if (outdev >= 0) c.CreateThreadedMIDIOutput(reaper.CreateMIDIOutput(outdev, false, null)) else null;
    if (errStats) |errstats| {
        if (indev >= 0 and globals.m_midi_in == null) errstats.* |= 1;
        if (outdev >= 0 and globals.m_midi_out == null) errstats.* |= 2;
    }
    if (globals.m_midi_in) |midi_in| {
        c.MidiIn_start(midi_in);
    } else {
        log.err("couldn’t create midi in", .{});
    }
    if (globals.m_midi_out) |mo| {
        midi_out.clearAll(mo);
        midi_out.sendModuleColor(mo, globals.preferences.colorForModule(globals.mft.active_module));
    } else {
        log.err("couldn’t create midi out", .{});
    }

    globals.online = globals.m_midi_in != null and globals.m_midi_out != null;

    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    my_csurf = myCsurf;
    return myCsurf;
}

pub fn deinit(csurf: c.C_ControlSurface) void {
    var globals = MftGlobals.get();
    globals.online = false;
    if (globals.m_midi_out) |mo| {
        midi_out.clearAll(mo);
        c.MidiOut_Destroy(mo);
        globals.m_midi_out = null;
    }
    if (globals.m_midi_in) |midi_in| {
        c.MidiIn_Destroy(midi_in);
        globals.m_midi_in = null;
    }
    c.ControlSurface_Destroy(csurf);
}

export fn zGetTypeString() callconv(.c) [*]const u8 {
    return constants.CONTROLLER_NAME;
}

export fn zGetDescString() callconv(.c) [*]const u8 {
    return reaper.LocalizeString("Perken MFT", "csurf", 1);
}

var config_buf: [512:0]u8 = undefined;
export fn zGetConfigString() callconv(.c) [*]const u8 {
    const globals = MftGlobals.get();
    _ = std.mem.printSentinel(&config_buf, "0 0 {d} {d}", .{ globals.m_midi_in_dev.?, globals.m_midi_out_dev.? }, 0) catch {
        return "0 0 0 0";
    };
    return &config_buf;
}

export fn zCloseNoReset() callconv(.c) void {
    deinit(my_csurf);
}

var led_test_running = false;

export fn zRun() callconv(.c) void {
    if (ignore_notifications) return;
    const globals = MftGlobals.get();
    if (globals.m_midi_in) |midi_in| {
        c.MidiIn_SwapBufs(midi_in, c.GetTickCount.?());
        const list = c.MidiIn_GetReadBuf(midi_in);
        var l: c_int = 0;
        while (c.MDEvtLs_EnumItems(list, &l)) |evts| : (l += 1) {
            midi_events.OnMidiEvent(evts, globals);
        }
    }

    // The LED test is toggled from the panel; the sweep runs here so the panel
    // stays free of the MIDI-out cImport. On stopping, restore the surface.
    if (globals.m_midi_out) |mo| {
        if (globals.wizard.led_test_active) {
            const frame = globals.wizard.ledTestAdvance();
            midi_out.sendAllColors(mo, frame.hue);
            midi_out.sendAllRings(mo, frame.ring);
            led_test_running = true;
        } else if (led_test_running) {
            led_test_running = false;
            midi_out.clearAll(mo);
            midi_out.sendModuleColor(mo, globals.preferences.colorForModule(globals.mft.active_module));
        }
    }
}

export fn zSetTrackListChange() callconv(.c) void {}
export fn zSetSurfaceVolume(trackid: MediaTrack, volume: f64) callconv(.c) void {
    _ = trackid;
    _ = volume;
}
export fn zSetSurfacePan(trackid: MediaTrack, pan: f64) callconv(.c) void {
    _ = trackid;
    _ = pan;
}
export fn zSetSurfaceMute(trackid: MediaTrack, mute: bool) callconv(.c) void {
    _ = trackid;
    _ = mute;
}
export fn zSetSurfaceSelected(trackid: MediaTrack, selected: bool) callconv(.c) void {
    _ = trackid;
    _ = selected;
}
export fn zSetSurfaceSolo(trackid: MediaTrack, solo: bool) callconv(.c) void {
    _ = trackid;
    _ = solo;
}
export fn zSetSurfaceRecArm(trackid: MediaTrack, recarm: bool) callconv(.c) void {
    _ = trackid;
    _ = recarm;
}
export fn zSetPlayState(play: bool, pause: bool, rec: bool) callconv(.c) void {
    _ = play;
    _ = pause;
    _ = rec;
}
export fn zSetRepeatState(rep: bool) callconv(.c) void {
    _ = rep;
}
export fn zSetTrackTitle(trackid: MediaTrack, title: [*]const u8) callconv(.c) void {
    _ = trackid;
    _ = title;
}
export fn zGetTouchState(trackid: *MediaTrack, isPan: c_int) callconv(.c) bool {
    _ = trackid;
    _ = isPan;
    return false;
}
export fn zSetAutoMode(mode: c_int) callconv(.c) void {
    _ = mode;
}
export fn zResetCachedVolPanStates() callconv(.c) void {}
export fn zOnTrackSelection(trackid: MediaTrack) callconv(.c) void {
    _ = trackid;
}
export fn zIsKeyDown(key: c_int) callconv(.c) bool {
    _ = key;
    return false;
}
export fn zExtended(call: c_int, parm1: ?*anyopaque, parm2: ?*anyopaque, parm3: ?*anyopaque) callconv(.c) c_int {
    _ = parm2;
    _ = parm3;
    if (call == CSURF_EXT_SETLASTTOUCHEDTRACK) {
        // parm1 is the newly last-touched MediaTrack (null clears it). The
        // encoders drive this track's FX until the next change.
        MftGlobals.get().current_track = @ptrCast(parm1);
    }
    return 0;
}

fn sendDlgItemMessage(hwnd: c.HWND, idx: c_int, msg: c.UINT, wparam: c.WPARAM, lparam: c.LPARAM) c.LRESULT {
    return c.SendMessage.?(c.GetDlgItem.?(hwnd, idx), msg, wparam, lparam);
}

fn dlgProc(hwndDlg: c.HWND, uMsg: c_uint, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.c) c.WDL_DLGRET {
    switch (uMsg) {
        c.WM_INITDIALOG => {
            var parms: [4]i32 = undefined;
            parseParms(@ptrFromInt(@as(usize, @intCast(lParam))), &parms);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT1), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT1_LBL), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2_LBL), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2_LBL2), c.SW_HIDE);

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
                var indev: isize = -1;
                var outdev: isize = -1;
                const offs: isize = 0;
                const size: isize = 9;

                var r = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_GETCURSEL, 0, 0);
                if (r != c.CB_ERR) indev = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_GETITEMDATA, @as(c.WPARAM, @intCast(r)), 0);

                r = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_GETCURSEL, 0, 0);
                if (r != c.CB_ERR) outdev = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_GETITEMDATA, @as(c.WPARAM, @intCast(r)), 0);

                var tmp: [512:0]u8 = undefined;
                _ = std.mem.printSentinel(&tmp, "{d} {d} {d} {d}", .{ offs, size, indev, outdev }, 0) catch return 0;
                _ = c.lstrcpyn.?(lParam, &tmp, @intCast(wParam));
            }
        },
        else => {},
    }
    return 0;
}

fn makeIntResource(x: anytype) [*c]const u8 {
    return @ptrFromInt(@as(u32, @intCast(x)));
}

pub fn configFunc(type_string: [*c]const u8, parent: c.HWND, initConfigString: [*c]const u8) callconv(.c) c.HWND {
    _ = type_string;
    const cast: c.LPARAM = @intCast(@intFromPtr(initConfigString));
    return c.SWELL_CreateDialog.?(c.SWELL_curmodule_dialogresource_head, makeIntResource(c.IDD_SURFACEEDIT_MCU), parent, &dlgProc, cast);
}

fn parseParms(str: [*c]const c_char, parms: *[4]i32) void {
    parms[0] = 0;
    parms[1] = 9;
    parms[2] = -1;
    parms[3] = -1;

    var iterator = std.mem.splitScalar(u8, std.mem.span(@as([*:0]const u8, @ptrCast(str))), ' ');
    var x: u8 = 0;
    while (iterator.next()) |val| {
        if (!std.mem.eql(u8, "", val) and x < 4) {
            const parsed = std.fmt.parseInt(i32, val, 10) catch -1;
            parms[x] = parsed;
            x += 1;
        }
    }
}

fn createFunc(type_string: [*c]const c_char, configString: [*c]const c_char, errStats: *c_int) callconv(.c) c.C_ControlSurface {
    _ = type_string;
    var parms: [4]i32 = undefined;
    parseParms(configString, &parms);
    return init(parms[2], parms[3], errStats);
}

const reaper_csurf_reg_t = extern struct {
    type_string: [*:0]const u8,
    desc_string: [*:0]const u8,
    IReaperControlSurface: *const fn (type_string: [*:0]const c_char, configString: [*:0]const c_char, errStats: *c_int) callconv(.c) c.C_ControlSurface,
    ShowConfig: *const fn (type_string: [*c]const u8, parent: c.HWND, initConfigString: [*c]const u8) callconv(.c) c.HWND,
};

pub const mft_reg = reaper_csurf_reg_t{
    .type_string = constants.CONTROLLER_NAME,
    .desc_string = "Perken MFT",
    .IReaperControlSurface = &createFunc,
    .ShowConfig = &configFunc,
};
