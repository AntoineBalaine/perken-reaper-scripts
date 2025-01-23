const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const utils = @import("../utils.zig");
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;
const c1 = @import("../c1.zig");
const ReentrancyMessage = @import("../reentrancy.zig").ReentrancyMessage;
const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("WDL/swell/swell-types.h");
    @cInclude("WDL/swell/swell-functions.h");
    @cInclude("WDL/win32_utf8.h");
    @cInclude("WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const ModulesList = @import("../statemachine.zig").ModulesList;
const globals = @import("../globals.zig");
const constants = @import("../constants.zig");
const actions = @import("../actions.zig");
const midi_events = @import("midi_events.zig");
const log = std.log.scoped(.csurf);
const fx_ctrl_state = @import("../fx_ctrl_state.zig");
const TrackList = fx_ctrl_state.TrackList;
const track_list_actions = @import("../tracklist_actions.zig");
pub var controller_dir: [*:0]const u8 = undefined;

const MIDI_eventlist = @import("../reaper.zig").reaper.MIDI_eventlist;

var blink_frame: u8 = 0;
var blink_state: bool = false;

pub var my_csurf: c.C_ControlSurface = undefined;
var m_buttonstate_lastrun: c.DWORD = 0;

pub fn init(indev: c_int, outdev: c_int, errStats: ?*c_int) c.C_ControlSurface {
    globals.m_midi_in_dev = indev;
    globals.m_midi_out_dev = outdev;
    globals.m_midi_in = if (indev >= 0) reaper.CreateMIDIInput(indev) else null;
    globals.m_midi_out = if (outdev >= 0) c.CreateThreadedMIDIOutput(reaper.CreateMIDIOutput(outdev, false, null)) else null;
    if (errStats) |errstats| {
        if (indev >= 0 and globals.m_midi_in == null) errstats.* |= 1;
        if (outdev >= 0 and globals.m_midi_out == null) errstats.* |= 2;
    }
    if (globals.m_midi_in) |midi_in| {
        log.info("created midi in", .{});
        c.MidiIn_start(midi_in);
    } else {
        log.err("couldn’t create midi in", .{});
    }
    if (globals.m_midi_out) |_| {
        log.info("created midi out", .{});
        actions.dispatch(&globals.state, .{ .midi_out = .clear_all }); // lights off
    } else {
        log.err("couldn’t create midi out", .{});
    }
    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    my_csurf = myCsurf;
    return myCsurf;
}

pub fn deinit(csurf: c.C_ControlSurface) void {
    if (globals.m_midi_out) |_| {
        actions.dispatch(&globals.state, .{ .midi_out = .clear_all }); // lights off
    }

    if (globals.m_midi_out) |midi_out| {
        c.MidiOut_Destroy(midi_out);
        globals.m_midi_out = null;
    }
    if (globals.m_midi_in) |midi_in| {
        c.MidiIn_Destroy(midi_in);
        globals.m_midi_in = null;
    }
    c.ControlSurface_Destroy(csurf);
}

export fn zGetTypeString() callconv(.C) [*]const u8 {
    return "Console1";
}

export fn zGetDescString() callconv(.C) [*]const u8 {
    return reaper.LocalizeString("Perken C1", "csurf", 1);
}

var config_buf: [512:0]u8 = undefined;
export fn zGetConfigString() callconv(.C) [*]const u8 {
    const buffer: []u8 = &config_buf;
    _ = std.fmt.bufPrintZ(buffer, "0 0 {d} {d}", .{ globals.m_midi_in_dev.?, globals.m_midi_out_dev.? }) catch {
        log.err("csurf console1 config string format", .{});
        return "0 0 0 0";
    };
    return &config_buf;
}

export fn zCloseNoReset() callconv(.C) void {
    deinit(my_csurf);
}

export fn zRun() callconv(.C) void {
    if (globals.m_midi_in) |midi_in| {
        c.MidiIn_SwapBufs(midi_in, c.GetTickCount.?());
        const list = c.MidiIn_GetReadBuf(midi_in);
        var l: c_int = 0;
        while (c.MDEvtLs_EnumItems(list, &l)) |evts| : (l += 1) {
            midi_events.OnMidiEvent(evts);
        }
    }

    if (globals.m_midi_out) |_| {
        if (globals.state.current_mode == .fx_ctrl) {
            blinkSelTrksLEDs(&blink_frame, &blink_state);
        }
        if (!globals.playState or (globals.pauseState)) return;
        // TODO: CALL midi_out.queryMeters.

        actions.dispatch(&globals.state, .{ .midi_out = .queryMeters });
    }
}

export fn zSetTrackListChange() callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetTrackListChange,
        .track_id = null,
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    actions.dispatch(&globals.state, .{ .Csurf = .track_list_changed });
}

inline fn FIXID(trackid: MediaTrack) c_int {
    const oid = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode);
    return oid - globals.state.last_touched_tr_id;
}

export fn zSetSurfaceVolume(trackid: MediaTrack, volume: f64) callconv(.C) void {
    // NOTE: Justin's logic uses FIXID here
    // is meant to prevent using the csurf with the master track?
    // const id = FIXID(trackid);
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetSurfaceVolume,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .volume = volume },
    } }});
    if (reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode) != globals.state.last_touched_tr_id) return;
    const volint = utils.volToU8(volume);
    if (globals.state.fx_ctrl.vol_lastpos != volint) {
        globals.state.fx_ctrl.vol_lastpos = volint;
        actions.dispatch(&globals.state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_Vol, .value = volint } } });
    }
}

// pan is btw -1.0 and 1.0
export fn zSetSurfacePan(trackid: MediaTrack, pan: f64) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetSurfacePan,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .pan = pan },
    } }});
    if (reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode) != globals.state.last_touched_tr_id) return;
    actions.dispatch(&globals.state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_Pan, .value = @intFromFloat((pan + 1) / 2 * 127) } } });
}
export fn zSetSurfaceMute(trackid: MediaTrack, mute: bool) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetSurfaceMute,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    if (reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode) != globals.state.last_touched_tr_id) return;
    actions.dispatch(&globals.state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_mute, .value = if (mute) 0x7f else 0x0 } } });
}
export fn zSetSurfaceSelected(trackid: MediaTrack, selected: bool) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetSurfaceSelected,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    actions.dispatch(&globals.state, .{ .Csurf = .{ .track_selected = .{ .tr = trackid, .selected = selected } } });
}
export fn zSetSurfaceSolo(trackid: MediaTrack, solo: bool) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetSurfaceSolo,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    if (reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode) != globals.state.last_touched_tr_id) return;
    actions.dispatch(&globals.state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_solo, .value = if (solo) 0x7f else 0x0 } } });
}

export fn zSetSurfaceRecArm(trackid: MediaTrack, recarm: bool) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetSurfaceRecArm,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    _ = recarm;
}

export fn zSetPlayState(play: bool, pause: bool, rec: bool) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetPlayState,
        .track_id = null,
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    _ = rec;
    globals.playState = play;
    globals.pauseState = pause;
    if (!globals.playState or globals.pauseState) {
        actions.dispatch(&globals.state, .{ .midi_out = .reset_meters });
    }
}
export fn zSetRepeatState(rep: bool) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetRepeatState,
        .track_id = null,
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    _ = rep;
}
export fn zSetTrackTitle(trackid: *MediaTrack, title: [*]const u8) callconv(.C) void {
    _ = trackid;
    _ = title;
}
export fn zGetTouchState(trackid: *MediaTrack, isPan: c_int) callconv(.C) bool {
    _ = trackid;
    _ = isPan;
    return false;
}
export fn zSetAutoMode(mode: c_int) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .SetAutoMode,
        .track_id = null,
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    _ = mode;
}

export fn zResetCachedVolPanStates() callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .ResetCachedVolPanStates,
        .track_id = null,
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    globals.state.fx_ctrl.vol_lastpos = 0;
}

pub fn blinkSelTrksLEDs(frame: *u8, blink_state_: *bool) void {
    if (globals.state.current_mode != .fx_ctrl) return;

    frame.* +%= 1;
    if (frame.* == 30) {
        frame.* = 0;
        blink_state_.* = !blink_state_.*;

        actions.dispatch(&globals.state, .{ .track_list = .{ .blink_leds = .{
            .blink_state = blink_state_.*,
            .midi_out = globals.m_midi_out.?,
        } } });
    }
}

export fn zOnTrackSelection(trackid: MediaTrack) callconv(.C) void {
    std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
        .type = .OnTrackSelection,
        .track_id = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode),
        .timestamp = std.time.milliTimestamp(),
        .data = .{ .none = {} },
    } }});
    // FIXME: should we be using this ?
    actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .update_console_for_track = trackid } });
}
export fn zIsKeyDown(key: c_int) callconv(.C) bool {
    _ = key;
    return false;
}

const Extended = enum(c_int) {
    MIDI_DEVICE_REMAP = 0x00010099,
    RESET = 0x0001FFFF,
    SETAUTORECARM = 0x00010003,
    SETBPMANDPLAYRATE = 0x00010009,
    SETFOCUSEDFX = 0x0001000B,
    SETFXCHANGE = 0x00010013,
    SETFXENABLED = 0x00010007,
    SETFXOPEN = 0x00010012,
    SETFXPARAM = 0x00010008,
    SETFXPARAM_RECFX = 0x00010018,
    SETINPUTMONITOR = 0x00010001,
    SETLASTTOUCHEDFX = 0x0001000A,
    SETLASTTOUCHEDTRACK = 0x0001000C,
    SETMETRONOME = 0x00010002,
    SETMIXERSCROLL = 0x0001000D,
    SETPAN_EX = 0x0001000E,
    SETPROJECTMARKERCHANGE = 0x00010014,
    SETRECMODE = 0x00010004,
    SETRECVPAN = 0x00010011,
    SETRECVVOLUME = 0x00010010,
    SETSENDPAN = 0x00010006,
    SETSENDVOLUME = 0x00010005,
    SUPPORTS_EXTENDED_TOUCH = 0x00080001,
    TRACKFX_PRESET_CHANGED = 0x00010015,
    unknown,
};

export fn zExtended(call: Extended, parm1: ?*c_void, parm2: ?*c_void, parm3: ?*c_void) callconv(.C) c_int {
    switch (call) {

        // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all parms NULL=clear focused FX
        .SETFOCUSEDFX => {
            std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
                .type = .Extended_SetFocusedFX,
                .track_id = if (parm1) |trPtr| reaper.CSurf_TrackToID(@as(MediaTrack, @ptrCast(trPtr)), constants.g_csurf_mcpmode) else null,
                .timestamp = std.time.milliTimestamp(),
                .data = .{ .none = {} },
            } }});
            if (parm2 != null) return 1; // ignore media items' FXchains
            const trId = if (parm1) |trPtr| reaper.CSurf_TrackToID(@as(MediaTrack, @ptrCast(trPtr)), constants.g_csurf_mcpmode) else null;
            if (trId == null) return 1;
            if (parm3) |ptr| {
                const fxIdx = @as(*u8, @ptrCast(ptr));
                globals.state.fx_ctrl.display = fxIdx.*;
                log.debug("display: {d}", .{globals.state.fx_ctrl.display.?});
            }
        },
        // TODO: sync with controller and state

        // #define CSURF_EXT_SETFXOPEN 0x00010012 // parm1=(MediaTrack*)track, parm2=(int*)fxidx, parm3=0 if UI closed, !0 if open
        .SETFXOPEN => {
            // const mediaTrack =  @as(MediaTrack, @ptrCast(parm1.?));
            if (parm3) |ptr| {
                const isOpen = @intFromPtr(ptr);
                // const isOpen = @as(*u8, @ptrCast(ptr));
                if (isOpen == 0) { // UI closed
                    globals.state.fx_ctrl.display = null;
                } else {
                    if (parm2) |fxIdxPtr| {
                        // const cntrlrIdx = reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1; // make it 1-based
                        //param.X.container_map.fx_index
                        const cntnrIdx = @as(*u8, @ptrCast(fxIdxPtr)).*;
                        _ = cntnrIdx;
                        // TrackFX_GetNamedConfigParm()
                    }
                }
            } else {
                globals.state.fx_ctrl.display = null;
            }
        },

        .SETLASTTOUCHEDTRACK => {
            std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
                .type = .Extended_SetLastTouchedTrack,
                .track_id = if (parm1) |trPtr| reaper.CSurf_TrackToID(@as(MediaTrack, @ptrCast(trPtr)), constants.g_csurf_mcpmode) else null,
                .timestamp = std.time.milliTimestamp(),
                .data = .{ .none = {} },
            } }});
            if (parm1) |mediaTrack|
                actions.dispatch(&globals.state, .{ .Csurf = .{ .last_touched_track = @ptrCast(mediaTrack) } });
        },
        .SETPAN_EX => {
            // csurf doesn't have means of checking if fx get re-ordered.
            // SETPAN_EX does get called if the fx chain is open and the user re-orders the fx, though.
            if (parm1) |mediaTrack| {
                _ = globals.state.fx_ctrl.validateTrack(
                    null,
                    @as(MediaTrack, @ptrCast(mediaTrack)),
                    null,
                ) catch {};
            }
        },
        .SETFXPARAM => {
            const track: reaper.MediaTrack = @ptrCast(parm1);
            const id = reaper.CSurf_TrackToID(track, constants.g_csurf_mcpmode);
            if (globals.state.last_touched_tr_id == id) {
                const f: c_int = @as(*c_int, @alignCast(@ptrCast(parm2))).*;

                const fxidx = (f >> 16) & 0xFFFF;
                const fx_idx_cast: usize = @intCast(fxidx);
                // const prmidx = f & 0xFFFF;
                const prm_idx_cast: usize = @intCast(f & 0xFFFF);

                const value = @as(*f64, @alignCast(@ptrCast(parm3))).*;

                std.log.scoped(.reentrancy).debug("{}", .{ReentrancyMessage{ .notification = .{
                    .type = .Extended_SetFXParam,
                    .track_id = id,
                    .timestamp = std.time.milliTimestamp(),
                    .data = .{ .fx_param = .{
                        .fx_index = fx_idx_cast,
                        .param_index = prm_idx_cast,
                        .value = value,
                    } },
                } }});

                actions.dispatch(&globals.state, .{ .Csurf = .{ .fx_param_changed = .{
                    .track = track,
                    .fx_index = fx_idx_cast,
                    .param_index = prm_idx_cast,
                    .value = @as(*f64, @alignCast(@ptrCast(parm3))).*,
                } } });
            }
        },
        .SETFXCHANGE,
        .SETFXENABLED,
        .MIDI_DEVICE_REMAP,
        .RESET,
        .SETAUTORECARM,
        .SETBPMANDPLAYRATE,
        .SETMETRONOME,
        .SETMIXERSCROLL,
        .SETFXPARAM_RECFX,
        .SETINPUTMONITOR,
        .SETLASTTOUCHEDFX,
        .SETPROJECTMARKERCHANGE,
        .SETRECMODE,
        .SETRECVPAN,
        .SETRECVVOLUME,
        .SETSENDPAN,
        .SETSENDVOLUME,
        .SUPPORTS_EXTENDED_TOUCH,
        .TRACKFX_PRESET_CHANGED,
        => {},
        else => {},
    }
    return 1;
}

fn sendDlgItemMessage(hwnd: c.HWND, idx: c_int, msg: c.UINT, wparam: c.WPARAM, lparam: c.LPARAM) c.LRESULT {
    return c.SendMessage.?(c.GetDlgItem.?(hwnd, idx), msg, wparam, lparam);
}

const WDL_UTF8_OLDPROCPROP = "WDLUTF8OldProc";

fn dlgProc(hwndDlg: c.HWND, uMsg: c_uint, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) c.WDL_DLGRET {
    switch (uMsg) {
        c.WM_INITDIALOG => {
            var parms: [4]i32 = undefined;
            parseParms(@ptrFromInt(@as(usize, @intCast(lParam))), &parms);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT1), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT1_LBL), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2_LBL), c.SW_HIDE);
            c.ShowWindow.?(c.GetDlgItem.?(hwndDlg, c.IDC_EDIT2_LBL2), c.SW_HIDE);

            // zig’s translateC can’t convert the type of WDL_UTF8_HookComboBox.
            // That function’s a compat define when utf8 is disabled.
            // fingers crossed, and hope that doesn’t happen.
            // c.WDL_UTF8_HookComboBox.?(c.GetDlgItem.?(hwndDlg, c.IDC_COMBO2));
            // WDL_UTF8_HookComboBox(c.GetDlgItem.?(hwndDlg, c.IDC_COMBO3));
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

            _ = c.SetDlgItemInt.?(hwndDlg, c.IDC_EDIT1, @intCast(parms[0]), c.TRUE);
            _ = c.SetDlgItemInt.?(hwndDlg, c.IDC_EDIT2, @intCast(parms[1]), c.FALSE);
        },
        c.WM_USER + 1024 => {
            if (wParam > 1 and lParam != 0) {
                var indev: isize = -1;
                var outdev: isize = -1;
                var offs: isize = 0;
                var size: isize = 9;

                // Get MIDI device selections
                var r = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_GETCURSEL, 0, 0);
                if (r != c.CB_ERR) indev = sendDlgItemMessage(hwndDlg, c.IDC_COMBO2, c.CB_GETITEMDATA, @as(c.WPARAM, @intCast(r)), 0);

                r = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_GETCURSEL, 0, 0);
                if (r != c.CB_ERR) outdev = sendDlgItemMessage(hwndDlg, c.IDC_COMBO3, c.CB_GETITEMDATA, @as(c.WPARAM, @intCast(r)), 0);

                // Get edit control values
                var t: c_int = undefined;
                r = c.GetDlgItemInt.?(hwndDlg, c.IDC_EDIT1, @ptrCast(&t), c.TRUE);
                if (t != 0) offs = r;

                r = c.GetDlgItemInt.?(hwndDlg, c.IDC_EDIT2, @ptrCast(&t), c.FALSE);
                if (t != 0) {
                    if (r < 1) {
                        r = 1;
                    } else if (r > 256) {
                        r = 256;
                    }
                    size = r;
                }

                // Format config string
                var tmp: [512:0]u8 = undefined;
                _ = std.fmt.bufPrintZ(&tmp, "{d} {d} {d} {d}", .{ offs, size, indev, outdev }) catch return 0;

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

pub fn configFunc(type_string: [*c]const u8, parent: c.HWND, initConfigString: [*c]const u8) callconv(.C) c.HWND {
    _ = type_string;
    const cast: c.LPARAM = @intCast(@intFromPtr(initConfigString));
    // const cast: c.LPARAM = @intCast(initConfigString);

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
            // tb determined, is this correct? It looks like the cpp version starts at 1
            x += 1;
        }
    }
}

fn createFunc(type_string: [*c]const c_char, configString: [*c]const c_char, errStats: *c_int) callconv(.C) c.C_ControlSurface {
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
    .desc_string = "Perken Console1",
    .IReaperControlSurface = &createFunc,
    .ShowConfig = &configFunc,
};

test parseParms {
    const expect = std.testing.expect;

    var parms: [4]c_int = undefined;
    // Create a string that matches the expected format
    var my_arr = [_]u8{ '1', ' ', '2', ' ', '3', 0 }; // Note: added null terminator
    const str: [*c]const c_char = @ptrCast(&my_arr);
    parseParms(str, &parms);

    // Test against actual implementation behavior
    try expect(parms[0] == 1); // First number
    try expect(parms[1] == 2); // Second number
    try expect(parms[2] == 3); // Third number
    try expect(parms[3] == -1); // Should remain -1 as default
}
