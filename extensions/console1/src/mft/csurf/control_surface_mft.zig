const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper");
const reaper = Reaper.reaper;
const MediaTrack = reaper.MediaTrack;
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
const constants = @import("../constants_mft.zig");
const midi_events = @import("midi_events_mft.zig");
const device_names = @import("midi_device_names");
const reaper_helpers = @import("reaper_helpers");
const midi_out = @import("../midi_out_mft.zig");
const MftGlobals = @import("../mft_globals.zig").MftGlobals;
const log = std.log.scoped(.csurf_mft);

// REAPER csurf Extended() call selector for the last-touched track change.
const CSURF_EXT_SETLASTTOUCHEDTRACK: c_int = 0x0001000C;

pub var ignore_notifications = false;
pub var my_csurf: c.C_ControlSurface = undefined;

/// The MIDI devices of REAPER, in the form that `midi_device_names.find` reads.
const ReaperDevices = struct {
    input: bool,

    pub fn count(self: ReaperDevices) c_int {
        return if (self.input) reaper.GetNumMIDIInputs() else reaper.GetNumMIDIOutputs();
    }

    /// The name of a device, or null when the number has none: the numbers that REAPER keeps for devices that are not there.
    pub fn name(self: ReaperDevices, dev: c_int, buf: []u8) ?[]const u8 {
        return reaper_helpers.deviceName(buf, self.input, dev, false);
    }
};

/// The keys of the devices that the surface is set to, which are kept in its config string. They stay the same when a device is not
/// there, so that it is found again when it is plugged in.
var in_key_buf: [device_names.max_key]u8 = undefined;
var in_key_len: usize = 0;
var out_key_buf: [device_names.max_key]u8 = undefined;
var out_key_len: usize = 0;

/// What the open dialog was given and did not find among the devices: what it saves keeps it, so that opening it and pressing OK does
/// not forget a device that is not plugged in today.
var dialog_in_key_buf: [device_names.max_key]u8 = undefined;
var dialog_in_key_len: usize = 0;
var dialog_out_key_buf: [device_names.max_key]u8 = undefined;
var dialog_out_key_len: usize = 0;

fn setKey(buf: *[device_names.max_key]u8, len: *usize, key: []const u8) void {
    len.* = @min(key.len, buf.len);
    @memcpy(buf[0..len.*], key[0..len.*]);
}

/// The number of the device that a surface is set to now. A config that has the key of the device finds it among the devices that are
/// there, whatever its number is, and none when it is not there; a config that has only a number, which is one that an older version
/// saved, has that number.
fn resolveDevice(input: bool, id: c_int, key: ?[]const u8) c_int {
    const wanted = key orelse return id;
    const found = device_names.find(ReaperDevices{ .input = input }, wanted);
    if (found) |dev| {
        log.info("midi {s} {s}: is the device {d}", .{ if (input) "in" else "out", wanted, dev });
        return dev;
    }
    log.warn("midi {s} {s}: is not there", .{ if (input) "in" else "out", wanted });
    return -1;
}

/// The key of the device that has this number, or null for none.
fn keyOfDevice(input: bool, dev: c_int, buf: *[512]u8) ?[]const u8 {
    if (dev < 0) return null;
    const name = (ReaperDevices{ .input = input }).name(dev, buf) orelse return null;
    return device_names.key(name);
}

fn parseDeviceKeys(str: [*c]const c_char, keys: *device_names.Keys) void {
    device_names.parseKeys(std.mem.span(@as([*:0]const u8, @ptrCast(str))), keys);
}

/// The surface that holds the MIDI devices that the globals have. Because REAPER makes the surface of new settings before it deletes the
/// one of the old, the one that is deleted must not let go of the devices of the next.
var midi_owner: ?*anyopaque = null;

/// Lets go of the MIDI devices. Calling it with none is fine.
fn closeMidi() void {
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
}

pub fn init(indev: c_int, outdev: c_int, errStats: ?*c_int) c.C_ControlSurface {
    var globals = MftGlobals.get();
    // Because the devices of the surface that this one replaces are still open when REAPER makes it, they are let go of first.
    closeMidi();
    midi_owner = null;
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
    midi_owner = myCsurf;
    return myCsurf;
}

/// Deletes a surface that this extension made for itself, whose destructor lets go of the devices that it holds. The surfaces that
/// REAPER made are deleted by REAPER, which must not be done twice.
pub fn deinit(csurf: c.C_ControlSurface) void {
    c.ControlSurface_Destroy(csurf);
}

export fn zGetTypeString() callconv(.c) [*]const u8 {
    return constants.CONTROLLER_NAME;
}

export fn zGetDescString() callconv(.c) [*]const u8 {
    return reaper.LocalizeString("Perken MFT", "csurf", 1);
}

var config_buf: [1024:0]u8 = undefined;
export fn zGetConfigString() callconv(.c) [*]const u8 {
    const globals = MftGlobals.get();
    // Because REAPER numbers the devices of Linux differently from one session to the next, the config string has the keys of the
    // devices after their numbers, which are what the surface looks for the next time.
    var in_word_buf: [3 * device_names.max_key]u8 = undefined;
    var out_word_buf: [3 * device_names.max_key]u8 = undefined;
    _ = std.mem.printSentinel(&config_buf, "0 0 {d} {d} {s} {s}", .{
        globals.m_midi_in_dev orelse -1,
        globals.m_midi_out_dev orelse -1,
        device_names.encode(&in_word_buf, in_key_buf[0..in_key_len]),
        device_names.encode(&out_word_buf, out_key_buf[0..out_key_len]),
    }, 0) catch {
        return "0 0 0 0";
    };
    return &config_buf;
}

/// REAPER closes a surface without resetting it, before it deletes it: the devices are let go of if this surface holds them, and the
/// surface itself is REAPER's.
export fn zCloseNoReset(self: ?*anyopaque) callconv(.c) void {
    if (self != null and self == midi_owner) closeMidi();
}

/// The destructor of a surface, which REAPER calls when the settings change and when it closes.
export fn zSurfaceDestroyed(self: ?*anyopaque) callconv(.c) void {
    if (self != null and self == midi_owner) {
        closeMidi();
        midi_owner = null;
    }
    if (self != null and self == my_csurf) my_csurf = null;
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
            // Because the numbers of the config are of the session that saved it, the devices that are selected are the ones that its
            // keys find now.
            var keys: device_names.Keys = .{};
            parseDeviceKeys(@ptrFromInt(@as(usize, @intCast(lParam))), &keys);
            parms[2] = resolveDevice(true, parms[2], keys.in);
            parms[3] = resolveDevice(false, parms[3], keys.out);
            setKey(&dialog_in_key_buf, &dialog_in_key_len, if (parms[2] < 0) keys.in orelse "" else "");
            setKey(&dialog_out_key_buf, &dialog_out_key_len, if (parms[3] < 0) keys.out orelse "" else "");
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

                // The keys of the devices follow their numbers, which are what the surface finds them by the next time.
                var tmp: [1024:0]u8 = undefined;
                var name_buf: [512]u8 = undefined;
                var in_word_buf: [3 * device_names.max_key]u8 = undefined;
                var out_word_buf: [3 * device_names.max_key]u8 = undefined;
                const in_key = keyOfDevice(true, @intCast(indev), &name_buf) orelse (if (indev < 0) dialog_in_key_buf[0..dialog_in_key_len] else "");
                const in_word = device_names.encode(&in_word_buf, in_key);
                const out_key = keyOfDevice(false, @intCast(outdev), &name_buf) orelse (if (outdev < 0) dialog_out_key_buf[0..dialog_out_key_len] else "");
                const out_word = device_names.encode(&out_word_buf, out_key);
                _ = std.mem.printSentinel(&tmp, "{d} {d} {d} {d} {s} {s}", .{ offs, size, indev, outdev, in_word, out_word }, 0) catch return 0;
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
    var keys: device_names.Keys = .{};
    parseDeviceKeys(configString, &keys);
    // Because the numbers of the devices are not the same from one session to the next, the surface looks for the devices that its
    // config names, and takes the numbers of the config only when it names none.
    const in_dev = resolveDevice(true, parms[2], keys.in);
    const out_dev = resolveDevice(false, parms[3], keys.out);
    const my_surface = init(in_dev, out_dev, errStats);
    // The surface keeps the key of each device that it has now, and of the others the key that its config named, so that a device that
    // is not plugged in today is found when it is.
    var name_buf: [512]u8 = undefined;
    if (keyOfDevice(true, in_dev, &name_buf)) |key| setKey(&in_key_buf, &in_key_len, key) else setKey(&in_key_buf, &in_key_len, keys.in orelse "");
    if (keyOfDevice(false, out_dev, &name_buf)) |key| setKey(&out_key_buf, &out_key_len, key) else setKey(&out_key_buf, &out_key_len, keys.out orelse "");
    return my_surface;
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
