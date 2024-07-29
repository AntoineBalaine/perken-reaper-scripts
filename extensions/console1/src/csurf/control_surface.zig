const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;
const State = @import("../internals/state.zig").State;
const c1 = @import("../internals/c1.zig");
const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("../WDL/swell/swell-types.h");
    @cInclude("../WDL/swell/swell-functions.h");
    @cInclude("../WDL/win32_utf8.h");
    @cInclude("../WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const Conf = @import("../internals/config.zig").Conf;
const UserSettings = @import("../internals/userPrefs.zig").UserSettings;
const CONTROLLER_NAME = @import("../internals/track.zig").CONTROLLER_NAME;
// TODO: update ini module, move tests from module into project
// TODO: fix mem leak (too many bytes freed)
// TODO: fix persisting csurf selection in preferences
// TODO: OUTPUT: send feedback to controller based on changes to fx parms in container
// TODO: OUTPUT: send feedback to controller's meters (peaks, gain reductio, etc.)
// TODO: INPUT: send commands to reaper based on controller
pub var state: State = undefined;
pub var conf: Conf = undefined;
pub var userSettings: UserSettings = undefined;
pub var controller_dir: []const u8 = undefined;

const MIDI_eventlist = @import("../reaper.zig").reaper.MIDI_eventlist;
const g_csurf_mcpmode = false;
var m_midi_in_dev: ?c_int = null;
var m_midi_out_dev: ?c_int = null;
var m_midiin: ?*reaper.midi_Input = null;
var m_midiout: ?reaper.midi_Output = null;
var m_vol_lastpos: u8 = 0;
var m_bank_offset: i32 = 0; // track offset, named after Justin's code example
var m_page_offset: u8 = 1; // page offset for the controller
var tmp: [512]u8 = undefined;
var m_button_states: i32 = 0;
var my_csurf: c.C_ControlSurface = undefined;
var m_buttonstate_lastrun: c.DWORD = 0;

var testCC: u8 = 0x6d;
var testFrame: u8 = 0;
var testBlink: bool = false;
fn outW(midiout: c.midi_Output_w, status: u8, d1: u8, d2: u8, frame_offset: c_int) void {
    c.MidiOut_Send(midiout, status, d1, d2, frame_offset);
    c.MidiOut_Send(midiout, status, d1, d2, frame_offset);
}

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

        outW(m_midiout, 0x8, @intFromEnum(c1.CCs.Out_MtrRgt), onOff, -1);
        outW(m_midiout, 0x8, @intFromEnum(c1.CCs.Out_MtrLft), onOff, -1);
        outW(m_midiout, 0x8, @intFromEnum(c1.CCs.Inpt_MtrRgt), onOff, -1);
        outW(m_midiout, 0x8, @intFromEnum(c1.CCs.Inpt_MtrLft), onOff, -1);
        outW(m_midiout, 0x8, @intFromEnum(c1.CCs.Comp_Mtr), onOff, -1);
        outW(m_midiout, 0x8, @intFromEnum(c1.CCs.Shp_Mtr), onOff, -1);
        std.debug.print("0x{x}\t0x{x}\n", .{ testCC, onOff });
    }
}
fn u8ToVol(val: u8) f64 {
    var pos = (@as(f64, @floatFromInt(val)) * 1000.0) / 127.0; // scale to 1000
    pos = reaper.SLIDER2DB(pos); // convert 0-1000 slider position to DB
    return DB2VAL(pos);
}

fn u8ToPan(val: u8) f64 {
    // Dividing by (127/2) scales the value to the range 0.0 to 2.0.
    // Subtracting 1.0 shifts the range to -1.0 to 1.0.
    return (@as(f64, @floatFromInt(val)) / (127 / 2)) - 1.0;
}

pub fn init(indev: c_int, outdev: c_int, errStats: ?*c_int) c.C_ControlSurface {
    m_midi_in_dev = indev;
    m_midi_out_dev = outdev;
    m_midiin = if (indev >= 0) reaper.CreateMIDIInput(indev) else null;
    m_midiout = if (outdev >= 0) c.CreateThreadedMIDIOutput(reaper.CreateMIDIOutput(outdev, false, null)) else null;
    if (errStats) |errstats| {
        if (indev >= 0 and m_midiin == null) errstats.* |= 1;
        if (outdev >= 0 and m_midiout == null) errstats.* |= 2;
    }
    if (m_midiin) |midi_in| {
        c.MidiIn_start(midi_in);
    }
    // if (m_midiout) |midi_out| {
    //     inline for (std.meta.fields(c1.CCs)) |f| {
    //         outW(midi_out, 0x8, f.value, 0x0, -1);
    //     }
    // }
    const myCsurf: c.C_ControlSurface = c.ControlSurface_Create();
    my_csurf = myCsurf;
    return myCsurf;
}

pub fn deinit(csurf: c.C_ControlSurface) void {
    if (m_midiout) |midi_out| {
        // lights off
        inline for (std.meta.fields(c1.CCs)) |f| {
            outW(midi_out, 0x8, f.value, 0x0, -1);
        }
    }

    if (m_midiout) |midi_out| {
        c.MidiOut_Destroy(midi_out);
        m_midiout = null;
    }
    if (m_midiin) |midi_in| {
        c.MidiIn_Destroy(midi_in);
        m_midiin = null;
    }
    c.ControlSurface_Destroy(csurf);
}

pub fn setPrmVal(comptime structPrm: []const u8, comptime section: Conf.ModulesList, tr: reaper.MediaTrack, val: u8) void {
    if (state.track == null) return;
    const nm = @tagName(section);

    const fxMap = @field(state.track.?.fxMap, nm);
    if (fxMap == null) return;
    const fxIdx = fxMap.?[0];
    const mapping = fxMap.?[1];
    if (mapping) |map| {
        const fxPrm = @field(map, structPrm);

        // at fxIdx, at fxPrm, set the value
        _ = reaper.TrackFX_SetParamNormalized(
            tr,
            state.track.?.getSubContainerIdx(
                fxIdx + 1, // make it 1-based
                reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false) + 1, // make it 1-based
            ),
            fxPrm,
            @as(f64, @floatFromInt(val)) / 127,
        );
    }
}

const PgChgDirection = enum { Up, Down };

fn onPgChg(direction: PgChgDirection) void {
    // query trackCount
    // trackCount / 20  = pageCount
    const pageCount = @as(u8, @intCast(@ceil(reaper.CountTracks(0) / 20)));
    m_page_offset = switch (direction) {
        .Up => @rem(m_page_offset + 1, pageCount),
        .Down => @as(u8, @intCast(@rem(@as(i16, @intCast(m_page_offset)) - 1, pageCount))),
    };
    if (m_midiout) |midi_out| {
        inline for (std.meta.fields(c1.CCs)) |f| { // lights off
            outW(midi_out, 0xb0, f.value, 0x0, -1);
        }

        // TODO check if that's actually an idx
        const trackID = reaper.CSurf_TrackToID(reaper.GetSelectedTrack(0, 0), false);
        if (trackID == -1) return;
        const selTrkOffset = @rem(trackID, pageCount);
        if (selTrkOffset == m_page_offset) { // if trk's on current page
            // turn on the track's LED
            const f = @typeInfo(c1.Tracks).Enum.fields[@as(isize, @intCast(selTrkOffset))];
            outW(midi_out, 0xb0, f.value, 0x7f, -1);
        }
    }
}

pub fn OnMidiEvent(evt: *c.MIDI_event_t) void {
    // The console only sends cc messages, so we know that the status is always going to be 0x8,
    // except when the message is a running status (i.e. the knobs are turned faster).
    // In the case of running status, we do need to read the status byte to figure out which control is being touched.
    // 0xb0 0x1f 0x7f 0x0
    // ^    ^    ^    ^
    // |    |    |    useless for our purposes
    // |    |    value
    // |    cc number
    // status "cc message"
    // 0x6b 0x46 0x0 0xdd
    // ^    ^    ^    ^
    // |    |    |    I assume this is noise
    // |    |    empty
    // |    value
    // cc number (byte is < 0x80, so this is running status)
    const msg = c.MIDI_event_message(evt);
    const status = msg[0] & 0xf0;
    const chan = msg[0] & 0x0f;
    _ = chan;
    const cc_enum = std.meta.intToEnum(c1.CCs, if (status == 0xb0) msg[1] else msg[0]) catch null;
    const val = if (status == 0xb0) msg[2] else msg[1];

    // std.debug.print("0x{x}\t0x{x}\t0x{x}\t\t0x{x}\t0x{x}\t0x{x}\n", .{ status, msg[1], msg[2], status, if (status == 0xb0) msg[1] else msg[0], val });

    if (cc_enum) |cc| {
        const tr = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);
        switch (cc) {
            .Comp_Attack => {
                if (state.mode == .fx_ctrl) {
                    setPrmVal(@tagName(c1.CCs.Comp_Attack), .COMP, tr, val);
                }
            },
            .Comp_DryWet => setPrmVal(@tagName(c1.CCs.Comp_DryWet), .COMP, tr, val),
            .Comp_Mtr => {}, // meters unhandled
            .Comp_Ratio => setPrmVal(@tagName(c1.CCs.Comp_Ratio), .COMP, tr, val),
            .Comp_Release => setPrmVal(@tagName(c1.CCs.Comp_Release), .COMP, tr, val),
            .Comp_Thresh => setPrmVal(@tagName(c1.CCs.Comp_Thresh), .COMP, tr, val),
            .Comp_comp => setPrmVal(@tagName(c1.CCs.Comp_comp), .COMP, tr, val),
            .Eq_HiFrq => setPrmVal(@tagName(c1.CCs.Eq_HiFrq), .EQ, tr, val),
            .Eq_HiGain => setPrmVal(@tagName(c1.CCs.Eq_HiGain), .EQ, tr, val),
            .Eq_HiMidFrq => setPrmVal(@tagName(c1.CCs.Eq_HiMidFrq), .EQ, tr, val),
            .Eq_HiMidGain => setPrmVal(@tagName(c1.CCs.Eq_HiMidGain), .EQ, tr, val),
            .Eq_HiMidQ => setPrmVal(@tagName(c1.CCs.Eq_HiMidQ), .EQ, tr, val),
            .Eq_LoFrq => setPrmVal(@tagName(c1.CCs.Eq_LoFrq), .EQ, tr, val),
            .Eq_LoGain => setPrmVal(@tagName(c1.CCs.Eq_LoGain), .EQ, tr, val),
            .Eq_LoMidFrq => setPrmVal(@tagName(c1.CCs.Eq_LoMidFrq), .EQ, tr, val),
            .Eq_LoMidGain => setPrmVal(@tagName(c1.CCs.Eq_LoMidGain), .EQ, tr, val),
            .Eq_LoMidQ => setPrmVal(@tagName(c1.CCs.Eq_LoMidQ), .EQ, tr, val),
            .Eq_eq => setPrmVal(@tagName(c1.CCs.Eq_eq), .EQ, tr, val),
            .Eq_hp_shape => setPrmVal(@tagName(c1.CCs.Eq_hp_shape), .EQ, tr, val),
            .Eq_lp_shape => setPrmVal(@tagName(c1.CCs.Eq_lp_shape), .EQ, tr, val),
            .Inpt_Gain => setPrmVal(@tagName(c1.CCs.Inpt_Gain), .INPUT, tr, val),
            .Inpt_HiCut => setPrmVal(@tagName(c1.CCs.Inpt_HiCut), .INPUT, tr, val),
            .Inpt_LoCut => setPrmVal(@tagName(c1.CCs.Inpt_LoCut), .INPUT, tr, val),
            .Inpt_MtrLft => {}, // meters unhandled
            .Inpt_MtrRgt => {}, // meters unhandled
            .Inpt_disp_mode => {
                // setPrmVal(@tagName(c1.CCs.Inpt_disp_mode), .INPUT, tr, val);
            },
            .Inpt_disp_on => {
                std.debug.print("CC Inpt_disp_on\n", .{});
            },
            .Inpt_filt_to_comp => {
                std.debug.print("CC Inpt_filt_to_comp\n", .{});
            },
            .Inpt_phase_inv => {
                const phase = reaper.GetMediaTrackInfo_Value(tr, "B_PHASE");
                _ = reaper.SetMediaTrackInfo_Value(tr, "B_PHASE", if (phase == 0) 1 else 0);
            },
            .Inpt_preset => {
                std.debug.print("CC Inpt_preset\n", .{});
            },
            .Out_Drive => setPrmVal(@tagName(c1.CCs.Out_Drive), .OUTPT, tr, val),
            .Out_DriveChar => setPrmVal(@tagName(c1.CCs.Out_DriveChar), .OUTPT, tr, val),
            .Out_MtrLft => {}, // meters unhandled
            .Out_MtrRgt => {}, // meters unhandled
            .Out_Pan => {
                if (state.mode == .fx_ctrl) {
                    const rv = reaper.CSurf_OnPanChange(tr, u8ToPan(val), false);
                    reaper.CSurf_SetSurfacePan(tr, rv, null);
                }
            },
            .Out_Vol => {
                if (state.mode == .fx_ctrl) {
                    const rv = reaper.CSurf_OnVolumeChange(tr, u8ToVol(val), false);
                    reaper.CSurf_SetSurfaceVolume(tr, rv, null);
                }
            },
            .Out_mute => reaper.CSurf_SetSurfaceMute(tr, reaper.CSurf_OnMuteChange(tr, -1), null),
            .Out_solo => reaper.CSurf_SetSurfaceSolo(tr, reaper.CSurf_OnSoloChange(tr, -1), null),
            .Shp_Gate => setPrmVal(@tagName(c1.CCs.Shp_Gate), .GATE, tr, val),
            .Shp_GateRelease => setPrmVal(@tagName(c1.CCs.Shp_GateRelease), .GATE, tr, val),
            .Shp_Mtr => {}, // meters unhandled
            .Shp_Punch => setPrmVal(@tagName(c1.CCs.Shp_Punch), .GATE, tr, val),
            .Shp_hard_gate => setPrmVal(@tagName(c1.CCs.Shp_hard_gate), .GATE, tr, val),
            .Shp_shape => setPrmVal(@tagName(c1.CCs.Shp_shape), .GATE, tr, val),
            .Shp_sustain => setPrmVal(@tagName(c1.CCs.Shp_sustain), .GATE, tr, val),
            .Tr_ext_sidechain => {
                // hook track channels 3-4 to comp or gate
                std.debug.print("CC Tr_ext_sidechain\n", .{});
            },
            .Tr_order => {
                std.debug.print("CC Tr_order\n", .{});
            },
            .Tr_pg_dn => onPgChg(.Down),
            .Tr_pg_up => onPgChg(.Up),
            .Tr_tr1 => {
                std.debug.print("CC Tr_tr1\n", .{});
            },
            .Tr_tr10 => {
                std.debug.print("CC Tr_tr10\n", .{});
            },
            .Tr_tr11 => {
                std.debug.print("CC Tr_tr11\n", .{});
            },
            .Tr_tr12 => {
                std.debug.print("CC Tr_tr12\n", .{});
            },
            .Tr_tr13 => {
                std.debug.print("CC Tr_tr13\n", .{});
            },
            .Tr_tr14 => {
                std.debug.print("CC Tr_tr14\n", .{});
            },
            .Tr_tr15 => {
                std.debug.print("CC Tr_tr15\n", .{});
            },
            .Tr_tr16 => {
                std.debug.print("CC Tr_tr16\n", .{});
            },
            .Tr_tr17 => {
                std.debug.print("CC Tr_tr17\n", .{});
            },
            .Tr_tr18 => {
                std.debug.print("CC Tr_tr18\n", .{});
            },
            .Tr_tr19 => {
                std.debug.print("CC Tr_tr19\n", .{});
            },
            .Tr_tr2 => {
                std.debug.print("CC Tr_tr2\n", .{});
            },
            .Tr_tr20 => {
                std.debug.print("CC Tr_tr20\n", .{});
            },
            .Tr_tr3 => {
                std.debug.print("CC Tr_tr3\n", .{});
            },
            .Tr_tr4 => {
                std.debug.print("CC Tr_tr4\n", .{});
            },
            .Tr_tr5 => {
                std.debug.print("CC Tr_tr5\n", .{});
            },
            .Tr_tr6 => {
                std.debug.print("CC Tr_tr6\n", .{});
            },
            .Tr_tr7 => {
                std.debug.print("CC Tr_tr7\n", .{});
            },
            .Tr_tr8 => {
                std.debug.print("CC Tr_tr8\n", .{});
            },
            .Tr_tr9 => {
                std.debug.print("CC Tr_tr9\n", .{});
            },
            .Tr_tr_copy => {
                std.debug.print("CC Tr_tr_copy\n", .{});
            },
            .Tr_tr_grp => {
                std.debug.print("CC Tr_tr_grp\n", .{});
            },
        }
    }

    //     reaper.CSurf_TrackToID(trackid,g_csurf_mcpmode);
    //     reaper.CSurf_TrackFromID(idx: c_int, mcpView: bool);
    //         reaper.GetTrackInfo(track: INT_PTR, flags: *c_int)
    //         // use this when make
    // reaper.TrackList_UpdateAllExternalSurfaces
}

fn GetTypeString() callconv(.C) [*]const u8 {
    return "CONSOLE1";
}

fn GetDescString() callconv(.C) [*]const u8 {
    // example code does this weird thing:
    // descspace.SetFormatted(512,__LOCALIZE_VERFMT("PreSonus FaderPort (dev %d,%d)","csurf"),m_midi_in_dev,m_midi_out_dev);
    return reaper.LocalizeString("Softube Console1", "csurf", 1);
}

fn GetConfigString() callconv(.C) [*]const u8 {
    const buffer: []u8 = &tmp;
    _ = std.fmt.bufPrint(buffer, "0 0 {d} {d}", .{ m_midi_in_dev.?, m_midi_out_dev.? }) catch {
        std.debug.print("err: csurf console1 config string format\n", .{});
        return "0 0 0 0";
    };
    return &tmp;
}
export const zGetTypeSattring = &GetTypeString;

export const zGetDescString = &GetDescString;

export const zGetConfigString = &GetConfigString;

export fn zCloseNoReset() callconv(.C) void {
    std.debug.print("CloseNoReset\n", .{});
    deinit(my_csurf);
}
export fn zRun() callconv(.C) void {
    if (m_midiin) |midi_in| {
        c.MidiIn_SwapBufs(midi_in, c.GetTickCount.?());
        const list = c.MidiIn_GetReadBuf(midi_in);
        var l: c_int = 0;
        while (c.MDEvtLs_EnumItems(list, &l)) |evts| : (l += 1) {
            OnMidiEvent(evts);
        }
        // iterCC();
    }
    if (playState and !pauseState) {
        if (m_midiout) |midiOut| {
            const tr = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);
            const left = reaper.Track_GetPeakInfo(tr, 1);
            const right = reaper.Track_GetPeakInfo(tr, 2);
            const left_midi: u8 = @intFromFloat(left * 127);
            const right_midi: u8 = @intFromFloat(right * 127);
            outW(midiOut, 0x8, @intFromEnum(c1.CCs.Out_MtrLft), left_midi, -1);
            outW(midiOut, 0x8, @intFromEnum(c1.CCs.Out_MtrRgt), right_midi, -1);
        }
    }
}
export fn zSetTrackListChange() callconv(.C) void {}

inline fn FIXID(trackid: MediaTrack) c_int {
    const oid = reaper.CSurf_TrackToID(trackid, g_csurf_mcpmode);
    return oid - m_bank_offset;
}

export fn zSetSurfaceVolume(trackid: MediaTrack, volume: f64) callconv(.C) void {
    _ = trackid; // autofix
    // FIXME: what's the id check for in the sdk examples?
    // is meant to prevent using the csurf with the master track?
    // const id = FIXID(trackid);
    // _ = id; // autofix
    if (m_midiout) |midiout| {
        const volint: u8 = @intFromFloat((volume * 127) / 4); // tr volumes are 0.0-4.0
        if (m_vol_lastpos != volint) {
            m_vol_lastpos = volint;
            outW(midiout, 0xb, @intFromEnum(c1.CCs.Out_Vol), volint, -1);
        }
    }
}

// pan is btw -1.0 and 1.0
export fn zSetSurfacePan(trackid: *MediaTrack, pan: f64) callconv(.C) void {
    _ = trackid; // autofix
    if (m_midiout) |midiout| {
        // shift the range from [−1,1] to [0,2]
        // scale the range from [0,2] to [0,1]
        // scale the range from [0,1] to [0,127]
        const val: u8 = @intFromFloat((pan + 1) / 2 * 127);
        outW(midiout, 0x8, @intFromEnum(c1.CCs.Out_Pan), val, -1);
    }
}
export fn zSetSurfaceMute(trackid: *MediaTrack, mute: bool) callconv(.C) void {
    _ = trackid;
    if (m_midiout) |midiout| {
        outW(midiout, 0x8, @intFromEnum(c1.CCs.Out_mute), if (mute) 0x7f else 0x0, -1);
    }
}
export fn zSetSurfaceSelected(trackid: *MediaTrack, selected: bool) callconv(.C) void {
    _ = trackid;
    _ = selected;
    std.debug.print("SetSurfaceSelected\n", .{});
}
export fn zSetSurfaceSolo(trackid: *MediaTrack, solo: bool) callconv(.C) void {
    _ = trackid;
    if (m_midiout) |midiout| {
        outW(midiout, 0x8, @intFromEnum(c1.CCs.Out_solo), if (solo) 0x7f else 0x0, -1);
    }
}
export fn zSetSurfaceRecArm(trackid: *MediaTrack, recarm: bool) callconv(.C) void {
    _ = trackid;
    _ = recarm;
}
export fn zSetPlayState(play: bool, pause: bool, rec: bool) callconv(.C) void {
    _ = rec;
    playState = play;
    pauseState = pause;
    if (!playState or pauseState) {
        if (m_midiout) |midiOut| {
            // set meters to zero when not playing
            outW(midiOut, 0x8, @intFromEnum(c1.CCs.Inpt_MtrLft), 0x0, -1);
            outW(midiOut, 0x8, @intFromEnum(c1.CCs.Inpt_MtrRgt), 0x0, -1);
            outW(midiOut, 0x8, @intFromEnum(c1.CCs.Out_MtrLft), 0x0, -1);
            outW(midiOut, 0x8, @intFromEnum(c1.CCs.Out_MtrRgt), 0x0, -1);
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
    m_vol_lastpos = 0;
}
export fn zOnTrackSelection(trackid: MediaTrack) callconv(.C) void {
    std.debug.print("OnTrackSelection\n", .{});
    // QUESTION: what does mcpView param do?
    const id = reaper.CSurf_TrackToID(trackid, g_csurf_mcpmode);
    if (m_bank_offset != id) {
        state.updateTrack(trackid, &conf);
        m_bank_offset = id;

        if (m_midiout) |midiout| {
            const c1_tr_id: u8 = @as(u8, @intCast(@rem(m_bank_offset, 20) + 0x15 - 1)); // c1’s midi track ids go from 0x15 to 0x28
            outW(midiout, 0x8, c1_tr_id, 0x0, -1); // turnoff currently-selected track's lights
            const new_cc = @rem(m_bank_offset, 20) + 0x15 - 1;
            outW(midiout, 0x8, @as(u8, @intCast(new_cc)), 0x7f, -1); // set newly-selected to on
        }
    }
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
    _ = parm1;
    _ = parm2;
    _ = parm3;
    switch (call) {
        .MIDI_DEVICE_REMAP => std.debug.print("MIDI_DEVICE_REMAP\n", .{}),
        .RESET => std.debug.print("RESET\n", .{}),
        .SETAUTORECARM => std.debug.print("SETAUTORECARM\n", .{}),
        .SETBPMANDPLAYRATE => std.debug.print("SETBPMANDPLAYRATE\n", .{}),
        .SETFOCUSEDFX => std.debug.print("SETFOCUSEDFX\n", .{}),
        .SETFXCHANGE => std.debug.print("SETFXCHANGE\n", .{}),
        .SETFXENABLED => std.debug.print("SETFXENABLED\n", .{}),
        .SETFXOPEN => std.debug.print("SETFXOPEN\n", .{}),
        .SETFXPARAM => std.debug.print("SETFXPARAM\n", .{}),
        .SETFXPARAM_RECFX => std.debug.print("SETFXPARAM_RECFX\n", .{}),
        .SETINPUTMONITOR => std.debug.print("SETINPUTMONITOR\n", .{}),
        .SETLASTTOUCHEDFX => std.debug.print("SETLASTTOUCHEDFX\n", .{}),
        .SETLASTTOUCHEDTRACK => std.debug.print("SETLASTTOUCHEDTRACK\n", .{}),
        .SETMETRONOME => std.debug.print("SETMETRONOME\n", .{}),
        .SETMIXERSCROLL => std.debug.print("SETMIXERSCROLL\n", .{}),
        .SETPAN_EX => std.debug.print("SETPAN_EX\n", .{}),
        .SETPROJECTMARKERCHANGE => std.debug.print("SETPROJECTMARKERCHANGE\n", .{}),
        .SETRECMODE => std.debug.print("SETRECMODE\n", .{}),
        .SETRECVPAN => std.debug.print("SETRECVPAN\n", .{}),
        .SETRECVVOLUME => std.debug.print("SETRECVVOLUME\n", .{}),
        .SETSENDPAN => std.debug.print("SETSENDPAN\n", .{}),
        .SETSENDVOLUME => std.debug.print("SETSENDVOLUME\n", .{}),
        .SUPPORTS_EXTENDED_TOUCH => std.debug.print("SUPPORTS_EXTENDED_TOUCH\n", .{}),
        .TRACKFX_PRESET_CHANGED => std.debug.print("TRACKFX_PRESET_CHANGED\n", .{}),
        else => {},
    }
    return 0;
}

inline fn DB2VAL(x: f64) f64 {
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
    std.debug.print("configFunc\n", .{});
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
