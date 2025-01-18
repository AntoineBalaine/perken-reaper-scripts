const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;
const c1 = @import("../c1.zig");
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
const logger = @import("../logger.zig");
const midi_events = @import("midi_events.zig");

const CONTROLLER_NAME = @import("../fx_ctrl_state.zig").CONTROLLER_NAME;
// TODO: update ini module, move tests from module into project
// TODO: fix persisting csurf selection in preferences
// TODO: OUTPUT: send feedback to controller based on changes to fx parms in container
// TODO: OUTPUT: send feedback to controller's meters (peaks, gain reductio, etc.)
pub var controller_dir: [*:0]const u8 = undefined;

const MIDI_eventlist = @import("../reaper.zig").reaper.MIDI_eventlist;

var tmp: [4096:0]u8 = undefined;

var my_csurf: c.C_ControlSurface = undefined;
var m_buttonstate_lastrun: c.DWORD = 0;

var testCC: u8 = 0x6d;
var testFrame: u8 = 0;
var testBlink: bool = false;

fn iterCC() void {
    testFrame += 1;
    if (testFrame >= 60) { // reset frames once we get to 60 (== 2 second)
        testFrame = 0;
    }
    if (testCC > 0x73) { // reset CC to 0 once we get to the last CC control
        testCC = 0x6d;
    }
    if (testFrame == 0 or testFrame == 30) {
        if (testFrame == 0) {
            testCC += 1;
        }
        testBlink = !testBlink;
        const onOff: u8 = if (testBlink) 0x7f else 0x0;

        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Out_MtrRgt), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Out_MtrLft), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrRgt), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrLft), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Comp_Mtr), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Shp_Mtr), onOff, -1);

        logger.log(.debug, "blink msg:\t 0x{x}\t0x{x}\n", .{ testCC, onOff }, null, globals.allocator);
    }
}

fn volToU8(vol: f64) u8 {
    var d: f64 = (reaper.DB2SLIDER(VAL2DB(vol)) * 127.0 / 1000.0);
    d = if (d < 0.0) 0.0 else if (d > 127.0) 127.0 else d;
    const t: u8 = @intFromFloat(d + 0.5);
    return t;
}

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
        c.MidiIn_start(midi_in);
    }
    if (globals.m_midi_out) |midi_out| {
        for (std.enums.values(c1.CCs)) |f| {
            if (f == c1.CCs.Comp_Mtr or f == c1.CCs.Shp_Mtr) {
                c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(f), 0x7f, -1);
            } else {
                c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(f), 0x0, -1);
            }
        }
    }
    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    my_csurf = myCsurf;
    return myCsurf;
}

pub fn deinit(csurf: c.C_ControlSurface) void {
    if (globals.m_midi_out) |midi_out| {
        // lights off
        for (std.enums.values(c1.CCs)) |f| {
            if (f == c1.CCs.Comp_Mtr or f == c1.CCs.Shp_Mtr) {
                c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(f), 0x7f, -1);
            } else {
                c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(f), 0x0, -1);
            }
        }
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

fn GetTypeString() callconv(.C) [*]const u8 {
    return "CONSOLE1";
}

fn GetDescString() callconv(.C) [*]const u8 {
    // example code does this weird thing:
    // descspace.SetFormatted(512,__LOCALIZE_VERFMT("PreSonus FaderPort (dev %d,%d)","csurf"),globals.m_midi_in_dev,globals.m_midi_out_dev);
    return reaper.LocalizeString("Softube Console1", "csurf", 1);
}

fn GetConfigString() callconv(.C) [*]const u8 {
    const buffer: []u8 = &tmp;
    _ = std.fmt.bufPrint(buffer, "0 0 {d} {d}", .{ globals.m_midi_in_dev.?, globals.m_midi_out_dev.? }) catch {
        logger.log(.err, "csurf console1 config string format\n", .{}, null, globals.allocator);
        return "0 0 0 0";
    };
    return &tmp;
}
export const zGetTypeString = &GetTypeString;

export const zGetDescString = &GetDescString;

export const zGetConfigString = &GetConfigString;

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
        // iterCC();
    }
    if (!globals.playState or (globals.pauseState)) return;

    // query meters
    if (globals.m_midi_out) |midiOut| {
        const mediaTrack = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
        const left = reaper.Track_GetPeakInfo(mediaTrack, 0);
        const right = reaper.Track_GetPeakInfo(mediaTrack, 1);
        const left_midi: u8 = if (left > 1.0) 127 else @intFromFloat(left * 127);
        const right_midi: u8 = if (right > 1.0) 127 else @intFromFloat(right * 127);
        c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Out_MtrLft), left_midi, -1);
        c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Out_MtrRgt), right_midi, -1);
        if (globals.state.fx_ctrl.fxMap.COMP) |comp| {
            const success = reaper.TrackFX_GetNamedConfigParm(
                mediaTrack,
                globals.state.fx_ctrl.getSubContainerIdx(comp[0] + 1, // make it 1-based
                    reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1, // make it 1-based
                    mediaTrack),
                "GainReduction_dB",
                tmp[0..],
                tmp.len,
            );
            if (!success) {
                logger.log(.err, "failed to get gain reduction\n", .{}, null, globals.allocator);
            } else {
                const slice = std.mem.sliceTo(&tmp, 0);
                const gainReduction = std.fmt.parseFloat(f64, slice) catch null;

                if (gainReduction) |GR| {
                    // not quite 1:1 with the console's meter, but good enough for jazz
                    const conv: u8 = @intFromFloat(DB2VAL(GR) * 127);
                    c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Comp_Mtr), conv, -1);
                } else {
                    logger.log(.err, "failed to parse gain reduction\n", .{}, null, globals.allocator);
                }
            }
        }
    }
}
export fn zSetTrackListChange() callconv(.C) void {}

inline fn FIXID(trackid: MediaTrack) c_int {
    const oid = reaper.CSurf_TrackToID(trackid, constants.g_csurf_mcpmode);
    return oid - globals.state.last_touched_tr_id;
}

export fn zSetSurfaceVolume(trackid: MediaTrack, volume: f64) callconv(.C) void {
    _ = trackid; // autofix
    // FIXME: what's the id check for in the sdk examples?
    // is meant to prevent using the csurf with the master track?
    // const id = FIXID(trackid);
    // _ = id; // autofix
    if (globals.m_midi_out) |midiout| {
        const volint = volToU8(volume);
        if (globals.state.fx_ctrl.vol_lastpos != volint) {
            globals.state.fx_ctrl.vol_lastpos = volint;
            c.MidiOut_Send(midiout, 0xb, @intFromEnum(c1.CCs.Out_Vol), volint, -1);
        }
    }
}

// pan is btw -1.0 and 1.0
export fn zSetSurfacePan(trackid: *MediaTrack, pan: f64) callconv(.C) void {
    _ = trackid; // autofix
    if (globals.m_midi_out) |midiout| {
        // shift the range from [−1,1] to [0,2]
        // scale the range from [0,2] to [0,1]
        // scale the range from [0,1] to [0,127]
        const val: u8 = @intFromFloat((pan + 1) / 2 * 127);
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(c1.CCs.Out_Pan), val, -1);
    }
}
export fn zSetSurfaceMute(trackid: *MediaTrack, mute: bool) callconv(.C) void {
    _ = trackid;
    if (globals.m_midi_out) |midiout| {
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(c1.CCs.Out_mute), if (mute) 0x7f else 0x0, -1);
    }
}
export fn zSetSurfaceSelected(trackid: *MediaTrack, selected: bool) callconv(.C) void {
    _ = trackid;
    _ = selected;
}
export fn zSetSurfaceSolo(trackid: *MediaTrack, solo: bool) callconv(.C) void {
    _ = trackid;
    if (globals.m_midi_out) |midiout| {
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(c1.CCs.Out_solo), if (solo) 0x7f else 0x0, -1);
    }
}
export fn zSetSurfaceRecArm(trackid: *MediaTrack, recarm: bool) callconv(.C) void {
    _ = trackid;
    _ = recarm;
}
export fn zSetPlayState(play: bool, pause: bool, rec: bool) callconv(.C) void {
    _ = rec;
    globals.playState = play;
    globals.pauseState = pause;
    if (!globals.playState or globals.pauseState) {
        if (globals.m_midi_out) |midiOut| {
            // set meters to zero when not playing
            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrLft), 0x0, -1);
            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrRgt), 0x0, -1);
            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Out_MtrLft), 0x0, -1);
            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Out_MtrRgt), 0x0, -1);
        }
    }
}
export fn zSetRepeatState(rep: bool) callconv(.C) void {
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
    _ = mode;
}

export fn zResetCachedVolPanStates() callconv(.C) void {
    globals.state.fx_ctrl.vol_lastpos = 0;
}
pub fn selectTrk(media_track: MediaTrack) void {
    logger.log(.debug, "selectTrk()\n", .{}, null, globals.allocator);
    // QUESTION: what does mcpView param do?
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);

    if (globals.state.last_touched_tr_id == id) {
        return;
    }
    globals.state.fx_ctrl.validateTrack(null, media_track, null) catch {
        logger.log(.err, "track validation failed: \ttrack {d}\n", .{id}, null, globals.allocator);
    };
    if (globals.state.fx_ctrl.display) |_| { // display fxChain windows
        const prevTr = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);

        const currentFX = reaper.TrackFX_GetChainVisible(prevTr);
        reaper.TrackFX_Show(prevTr, currentFX, if (currentFX == -2 or currentFX >= 0) 0 else 1);
        const cntnrIdx = reaper.TrackFX_GetByName(media_track, CONTROLLER_NAME, false) + 1; // make it 1-based
        reaper.TrackFX_Show(media_track, cntnrIdx, 1); // close window
    }
    if (globals.m_midi_out) |midiout| {
        const c1_tr_id: u8 = @as(u8, @intCast(@rem(globals.state.last_touched_tr_id, 20) + 0x15 - 1)); // c1’s midi track ids go from 0x15 to 0x28
        c.MidiOut_Send(midiout, 0xb0, c1_tr_id, 0x0, -1); // turnoff currently-selected track's lights
        const new_cc = @rem(id, 20) + 0x15 - 1;
        c.MidiOut_Send(midiout, 0xb0, @as(u8, @intCast(new_cc)), 0x7f, -1); // set newly-selected to on
        globals.state.last_touched_tr_id = id;

        // TODO: update SideChain
        // set all knobs to the current track’s values
        // trk.order
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(c1.CCs.Tr_order), @intFromEnum(globals.state.fx_ctrl.order), -1);
        inline for (comptime std.enums.values(c1.CCs)) |CC| { // update params according to mappings
            if (CC == c1.CCs.Out_Vol) {
                const volume = reaper.GetMediaTrackInfo_Value(media_track, "D_VOL");
                const volint = volToU8(volume);
                c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), volint, -1);
            } else if (CC == c1.CCs.Out_Pan) {
                const pan = reaper.GetMediaTrackInfo_Value(media_track, "D_PAN");
                const val: u8 = @intFromFloat((pan + 1) / 2 * 127);
                c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), val, -1);
            } else if (CC == c1.CCs.Out_mute) {
                const mute = reaper.GetMediaTrackInfo_Value(media_track, "B_MUTE");
                c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), if (mute == 1) 0x7f else 0x0, -1);
            } else if (CC == c1.CCs.Out_solo) {
                const solo = reaper.GetMediaTrackInfo_Value(media_track, "I_SOLO");
                c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), if (solo == 1) 0x7f else 0x0, -1);
            } else {
                comptime var variant: ModulesList = undefined;
                if (comptime std.mem.eql(u8, @tagName(CC)[0..4], "Comp")) {
                    if (comptime std.mem.eql(u8, @tagName(CC)[4..8], "_Mtr")) continue;
                    variant = .COMP;
                } else if (comptime std.mem.eql(u8, @tagName(CC)[0..3], "Shp")) {
                    if (comptime std.mem.eql(u8, @tagName(CC)[3..7], "_Mtr")) continue;
                    variant = .GATE;
                } else if (comptime std.mem.eql(u8, @tagName(CC)[0..2], "Eq")) {
                    variant = .EQ;
                } else if (comptime std.mem.eql(u8, @tagName(CC)[0..4], "Inpt")) {
                    if (comptime std.mem.eql(u8, @tagName(CC)[4..8], "_Mtr")) continue;
                    variant = .INPUT;
                } else if (comptime std.mem.eql(u8, @tagName(CC)[0..5], "Outpt")) {
                    if (comptime std.mem.eql(u8, @tagName(CC)[5..9], "_Mtr")) continue;
                    variant = .OUTPT;
                } else {
                    continue;
                }
                const fxMap = @field(globals.state.fx_ctrl.fxMap, @tagName(variant));
                if (fxMap) |fx| {
                    const fxIdx = fx[0];
                    const mapping = fx[1];
                    if (mapping) |map| {
                        const fxPrm = @field(map, @tagName(CC));
                        const val = reaper.TrackFX_GetParamNormalized(
                            media_track,
                            globals.state.fx_ctrl.getSubContainerIdx(fxIdx + 1, // make it 1-based
                                reaper.TrackFX_GetByName(media_track, CONTROLLER_NAME, false) + 1, // make it 1-based
                                media_track),
                            fxPrm,
                        );
                        const conv: u8 = @intFromFloat(val * 127);
                        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), conv, -1);
                    }
                }
            }
        }
    }
}
export fn zOnTrackSelection(trackid: MediaTrack) callconv(.C) void {
    selectTrk(trackid);
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
        .MIDI_DEVICE_REMAP => {},
        .RESET => {},
        .SETAUTORECARM => {},
        .SETBPMANDPLAYRATE => {},

        // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all parms NULL=clear focused FX
        .SETFOCUSEDFX => {
            if (parm2 != null) return 1; // ignore media items' FXchains
            const trId = if (parm1) |trPtr| reaper.CSurf_TrackToID(@as(MediaTrack, @ptrCast(trPtr)), constants.g_csurf_mcpmode) else null;
            if (trId == null) return 1;
            if (parm3) |ptr| {
                const fxIdx = @as(*u8, @ptrCast(ptr));
                globals.state.fx_ctrl.display = fxIdx.*;
                logger.log(.debug, "display: {d}\n", .{globals.state.fx_ctrl.display.?}, null, globals.allocator);
            }
        },
        .SETFXCHANGE => {},
        .SETFXENABLED => {},
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
        .SETFXPARAM => {},
        .SETFXPARAM_RECFX => {},
        .SETINPUTMONITOR => {},
        .SETLASTTOUCHEDFX => {},
        .SETLASTTOUCHEDTRACK => if (parm1) |mediaTrack| selectTrk(@as(reaper.MediaTrack, @ptrCast(mediaTrack))),
        .SETMETRONOME => {},
        .SETMIXERSCROLL => {},
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
        .SETPROJECTMARKERCHANGE => {},
        .SETRECMODE => {},
        .SETRECVPAN => {},
        .SETRECVVOLUME => {},
        .SETSENDPAN => {},
        .SETSENDVOLUME => {},
        .SUPPORTS_EXTENDED_TOUCH => {},
        .TRACKFX_PRESET_CHANGED => {},
        else => {},
    }
    return 1;
}

pub inline fn DB2VAL(x: f64) f64 {
    return std.math.exp((x) * LN10_OVER_TWENTY);
}
const TWENTY_OVER_LN10 = 8.6858896380650365530225783783321;
const LN10_OVER_TWENTY = 0.11512925464970228420089957273422;
inline fn VAL2DB(x: f64) f64 {
    if (x < 0.0000000298023223876953125) return -150.0;
    const v: f64 = std.math.log(@TypeOf(x), 10, x) * TWENTY_OVER_LN10;
    return if (v < -150.0) -150.0 else v;
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
        },
        c.WM_USER + 1024 => {
            if (wParam > 1 and lParam != 0) {
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
    .desc_string = "Softube Console1",
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
