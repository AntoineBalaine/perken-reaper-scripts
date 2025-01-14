const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c_void = anyopaque;
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
const ModulesList = @import("../statemachine.zig").ModulesList;
const globals = @import("../globals.zig");
const Track = @import("../internals/track.zig").Track;

const CONTROLLER_NAME = @import("../internals/track.zig").CONTROLLER_NAME;
const reaeq = @import("../internals/reaeq.zig");
// TODO: update ini module, move tests from module into project
// TODO: fix persisting csurf selection in preferences
// TODO: OUTPUT: send feedback to controller based on changes to fx parms in container
// TODO: OUTPUT: send feedback to controller's meters (peaks, gain reductio, etc.)
pub var controller_dir: [*:0]const u8 = undefined;

const MIDI_eventlist = @import("../reaper.zig").reaper.MIDI_eventlist;
const g_csurf_mcpmode = false;
var m_vol_lastpos: u8 = 0;
var m_bank_offset: i32 = 0; // track offset, named after Justin's code example
var m_page_offset: u8 = 1; // page offset for the controller
var tmp: [4096:0]u8 = undefined;
var m_button_states: i32 = 0;
var playState = false;
var pauseState = false;
var display: ?u8 = null;

var my_csurf: c.C_ControlSurface = undefined;
var m_buttonstate_lastrun: c.DWORD = 0;

var testCC: u8 = 0x6d;
var testFrame: u8 = 0;
var testBlink: bool = false;
var trck: ?Track = null;

pub fn updateTrack(
    trackid: reaper.MediaTrack,
) void {
    // update track
    // validate channel strip
    // load channel strip

    if (trck) |*tr| {
        tr.order = .@"S-EQ-C";
    }

    trck = Track{};

    trck.?.checkTrackState(
        null,
        trackid,
        null,
    ) catch {};
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

        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Out_MtrRgt), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Out_MtrLft), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrRgt), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrLft), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Comp_Mtr), onOff, -1);
        c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(c1.CCs.Shp_Mtr), onOff, -1);
        std.debug.print("0x{x}\t0x{x}\n", .{ testCC, onOff });
    }
}

fn volToU8(vol: f64) u8 {
    var d: f64 = (reaper.DB2SLIDER(VAL2DB(vol)) * 127.0 / 1000.0);
    d = if (d < 0.0) 0.0 else if (d > 127.0) 127.0 else d;
    const t: u8 = @intFromFloat(d + 0.5);
    return t;
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

pub fn setPrmVal(comptime cc: c1.CCs, comptime section: ModulesList, tr: reaper.MediaTrack, val: u8) void {
    const structPrm = @tagName(cc);
    if (trck == null) return;
    const nm = @tagName(section);

    const fxMap = @field(trck.?.fxMap, nm);
    if (fxMap == null) return;
    const fxIdx = fxMap.?[0];
    const mediaTrack = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);
    const subIdx = trck.?.getSubContainerIdx(
        fxIdx + 1, // make it 1-based
        reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false) + 1, // make it 1-based
        mediaTrack,
    );
    if (display != null) { // show touched fx
        reaper.TrackFX_Show(mediaTrack, subIdx, 1);
    }
    // if setting filter types on reaeq
    if ((cc == c1.CCs.Eq_hp_shape or cc == c1.CCs.Eq_lp_shape)) {
        const hasName = reaper.TrackFX_GetFXName(mediaTrack, subIdx, &tmp, tmp.len);
        if (hasName and std.mem.eql(u8, std.mem.span(@as([*:0]const u8, &tmp)), "VST: ReaEQ (Cockos)"))
            reaeq.setReaEqFilterType(mediaTrack, subIdx, cc, val);
        return;
    }

    const mapping = fxMap.?[1];
    if (mapping) |map| { // handle mapping
        const fxPrm = @field(map, structPrm);

        // at fxIdx, at fxPrm, set the value
        _ = reaper.TrackFX_SetParamNormalized(
            tr,
            trck.?.getSubContainerIdx(fxIdx + 1, // make it 1-based
                reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false) + 1, // make it 1-based
                mediaTrack),
            fxPrm,
            @as(f64, @floatFromInt(val)) / 127,
        );
    }
}

const PgChgDirection = enum { Up, Down };

fn onPgChg(direction: PgChgDirection) void {
    // select tracks in page
    // sws: VertZoomRange
    const btn = if (direction == .Up) c1.CCs.Tr_pg_up else c1.CCs.Tr_pg_dn;
    c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(btn), 0x0, -1); // don't light up the pgup/pgdn buttons
    // query trackCount
    // trackCount / 20  = pageCount
    const idx: u8 = 0;
    const pgCnt64: f64 = @ceil(@as(f64, @floatFromInt(reaper.CountTracks(idx))) / @as(f64, @floatCast(20)));
    const pageCount = @as(u8, @intFromFloat(pgCnt64));
    m_page_offset = switch (direction) {
        .Up => @rem(m_page_offset + 1, pageCount),
        .Down => @as(u8, @intCast(@rem(@as(i16, @intCast(m_page_offset)) - 1, pageCount))),
    };
    if (globals.m_midi_out) |midi_out| {
        if (m_bank_offset == -1) return;
        const selTrckOffset = @rem(m_bank_offset, pageCount);
        if (globals.m_midi_out) |midiout| {
            inline for (@typeInfo(c1.Tracks).Enum.fields, 0..) |f, fieldIdx| {
                if (fieldIdx == @as(usize, @intCast(selTrckOffset))) {
                    c.MidiOut_Send(midi_out, 0xb0, f.value, 0x7f, -1);
                }
            }
            if (selTrckOffset == m_page_offset) {
                const new_cc = @rem(m_bank_offset, 20) + 0x15 - 1;
                c.MidiOut_Send(midiout, 0xb0, @as(u8, @intCast(new_cc)), 0x7f, -1); // set newly-selected to on
            }
        }
    }
}
fn selTrck(idx: u8) void {
    if (idx == m_bank_offset) return;
    const unselected: f64 = 0.0;
    const tr = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);
    const success = reaper.SetMediaTrackInfo_Value(tr, "I_SELECTED", unselected); // unselect current
    if (!success) {
        std.debug.print("failed to unselect track\n", .{});
    }
    // don't set the new bank offset, let the re-entrancy deal with it
    const new_tr = reaper.CSurf_TrackFromID(idx, g_csurf_mcpmode);
    reaper.SetTrackSelected(new_tr, true);
    zOnTrackSelection(new_tr);
}

pub fn OnMidiEvent(evt: *c.MIDI_event_t) void {
    // The console only sends cc messages, so we know that the status is always going to be 0xb0,
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
    // cc number (byte is < 0xb0, so this is running status)
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
            .Comp_Mtr => {}, // meters unhandled
            .Inpt_MtrLft => {}, // meters unhandled
            .Inpt_MtrRgt => {}, // meters unhandled
            .Inpt_disp_mode => {},
            .Tr_tr_copy => {},
            .Tr_tr_grp => {},
            .Out_MtrLft => {}, // meters unhandled
            .Out_MtrRgt => {}, // meters unhandled
            .Inpt_disp_on => {
                const mediaTrack = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);
                const cntnrIdx = reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1; // make it 1-based

                if (display != null) { // hide chain
                    // else use TrackFX_SetNamedConfigParm
                    // _ = reaper.TrackFX_SetNamedConfigParm(mediaTrack, cntnrIdx, "focused", "1");
                    reaper.TrackFX_Show(mediaTrack, cntnrIdx, 0);
                    display = null;
                } else { // show chain
                    reaper.TrackFX_Show(mediaTrack, cntnrIdx, 1);
                    display = 1;
                }
            },
            .Inpt_filt_to_comp => {},
            .Inpt_phase_inv => {
                const phase = reaper.GetMediaTrackInfo_Value(tr, "B_PHASE");
                _ = reaper.SetMediaTrackInfo_Value(tr, "B_PHASE", if (phase == 0) 1 else 0);
            },
            .Inpt_preset => {},
            .Out_Pan => {
                const rv = reaper.CSurf_OnPanChange(tr, u8ToPan(val), false);
                reaper.CSurf_SetSurfacePan(tr, rv, null);
            },
            .Out_Vol => {
                _ = reaper.CSurf_OnVolumeChange(tr, u8ToVol(val), false);
            },
            .Out_mute => reaper.CSurf_SetSurfaceMute(tr, reaper.CSurf_OnMuteChange(tr, -1), null),
            .Out_solo => reaper.CSurf_SetSurfaceSolo(tr, reaper.CSurf_OnSoloChange(tr, -1), null),
            .Shp_Mtr => {}, // meters unhandled
            .Tr_ext_sidechain => {
                // unpin prev 3-4 of comp or gate
                if (trck) |*track| {
                    switch (val) {
                        0x0, 0x3f, 0x7f => track.checkTrackState(null, tr, @enumFromInt(val)) catch {},
                        else => {},
                    }
                }
            },
            .Tr_order => {
                if (trck) |*track| {
                    switch (val) {
                        0x0, 0x3f, 0x7f => track.checkTrackState(@enumFromInt(val), tr, null) catch {},
                        else => {},
                    }
                }
            },
            .Tr_pg_dn => onPgChg(.Down),
            .Tr_pg_up => onPgChg(.Up),
            .Tr_tr1 => selTrck(1),
            .Tr_tr10 => selTrck(10),
            .Tr_tr11 => selTrck(11),
            .Tr_tr12 => selTrck(12),
            .Tr_tr13 => selTrck(13),
            .Tr_tr14 => selTrck(14),
            .Tr_tr15 => selTrck(15),
            .Tr_tr16 => selTrck(16),
            .Tr_tr17 => selTrck(17),
            .Tr_tr18 => selTrck(18),
            .Tr_tr19 => selTrck(19),
            .Tr_tr20 => selTrck(20),
            .Tr_tr2 => selTrck(2),
            .Tr_tr3 => selTrck(3),
            .Tr_tr4 => selTrck(4),
            .Tr_tr5 => selTrck(5),
            .Tr_tr6 => selTrck(6),
            .Tr_tr7 => selTrck(7),
            .Tr_tr8 => selTrck(8),
            .Tr_tr9 => selTrck(9),
            inline else => |cc_| setPrmVal(cc_, switch (cc_) {
                .Comp_Attack, .Comp_DryWet, .Comp_Ratio, .Comp_Release, .Comp_Thresh, .Comp_comp => .COMP,
                .Eq_HiFrq, .Eq_HiGain, .Eq_HiMidFrq, .Eq_HiMidGain, .Eq_HiMidQ, .Eq_LoFrq, .Eq_LoGain, .Eq_LoMidFrq, .Eq_LoMidGain, .Eq_LoMidQ, .Eq_eq, .Eq_hp_shape, .Eq_lp_shape => .EQ,
                .Inpt_Gain, .Inpt_HiCut, .Inpt_LoCut => .INPUT,
                .Out_Drive, .Out_DriveChar => .OUTPT,
                .Shp_GateRelease, .Shp_Gate, .Shp_Punch, .Shp_hard_gate, .Shp_shape, .Shp_sustain => .GATE,
                else => unreachable,
            }, tr, val),
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
    // descspace.SetFormatted(512,__LOCALIZE_VERFMT("PreSonus FaderPort (dev %d,%d)","csurf"),globals.m_midi_in_dev,globals.m_midi_out_dev);
    return reaper.LocalizeString("Softube Console1", "csurf", 1);
}

fn GetConfigString() callconv(.C) [*]const u8 {
    const buffer: []u8 = &tmp;
    _ = std.fmt.bufPrint(buffer, "0 0 {d} {d}", .{ globals.m_midi_in_dev.?, globals.m_midi_out_dev.? }) catch {
        std.debug.print("err: csurf console1 config string format\n", .{});
        return "0 0 0 0";
    };
    return &tmp;
}
export const zGetTypeString = &GetTypeString;

export const zGetDescString = &GetDescString;

export const zGetConfigString = &GetConfigString;

export fn zCloseNoReset() callconv(.C) void {
    std.debug.print("CloseNoReset\n", .{});
    deinit(my_csurf);
}
export fn zRun() callconv(.C) void {
    if (globals.m_midi_in) |midi_in| {
        c.MidiIn_SwapBufs(midi_in, c.GetTickCount.?());
        const list = c.MidiIn_GetReadBuf(midi_in);
        var l: c_int = 0;
        while (c.MDEvtLs_EnumItems(list, &l)) |evts| : (l += 1) {
            OnMidiEvent(evts);
        }
        // iterCC();
    }
    if (playState and !pauseState) {
        if (globals.m_midi_out) |midiOut| {
            const mediaTrack = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);
            const left = reaper.Track_GetPeakInfo(mediaTrack, 0);
            const right = reaper.Track_GetPeakInfo(mediaTrack, 1);
            const left_midi: u8 = if (left > 1.0) 127 else @intFromFloat(left * 127);
            const right_midi: u8 = if (right > 1.0) 127 else @intFromFloat(right * 127);
            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Out_MtrLft), left_midi, -1);
            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Out_MtrRgt), right_midi, -1);
            if (trck) |*track| {
                if (track.fxMap.COMP) |comp| {
                    const success = reaper.TrackFX_GetNamedConfigParm(
                        mediaTrack,
                        track.getSubContainerIdx(comp[0] + 1, // make it 1-based
                            reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1, // make it 1-based
                            mediaTrack),
                        "GainReduction_dB",
                        tmp[0..],
                        tmp.len,
                    );
                    if (!success) {
                        std.debug.print("failed to get gain reduction\n", .{});
                    } else {
                        const slice = std.mem.sliceTo(&tmp, 0);
                        const gainReduction = std.fmt.parseFloat(f64, slice) catch null;

                        if (gainReduction) |GR| {
                            // not quite 1:1 with the console's meter, but good enough for jazz
                            const conv: u8 = @intFromFloat(DB2VAL(GR) * 127);
                            c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Comp_Mtr), conv, -1);
                        } else {
                            std.debug.print("failed to parse gain reduction\n", .{});
                        }
                    }
                }
            }
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
    if (globals.m_midi_out) |midiout| {
        const volint = volToU8(volume);
        if (m_vol_lastpos != volint) {
            m_vol_lastpos = volint;
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
    playState = play;
    pauseState = pause;
    if (!playState or pauseState) {
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
    m_vol_lastpos = 0;
}
fn selectTrk(trackid: MediaTrack) void {
    // QUESTION: what does mcpView param do?
    const id = reaper.CSurf_TrackToID(trackid, g_csurf_mcpmode);

    if (m_bank_offset == id) {
        return;
    }
    updateTrack(trackid);
    if (display != null) { // display fxChain windows
        const prevTr = reaper.CSurf_TrackFromID(m_bank_offset, g_csurf_mcpmode);

        const currentFX = reaper.TrackFX_GetChainVisible(prevTr);
        reaper.TrackFX_Show(prevTr, currentFX, if (currentFX == -2 or currentFX >= 0) 0 else 1);
        if (trck) |_| {
            const cntnrIdx = reaper.TrackFX_GetByName(trackid, CONTROLLER_NAME, false) + 1; // make it 1-based
            reaper.TrackFX_Show(trackid, cntnrIdx, 1); // close window
        }
    }
    if (globals.m_midi_out) |midiout| {
        const c1_tr_id: u8 = @as(u8, @intCast(@rem(m_bank_offset, 20) + 0x15 - 1)); // c1’s midi track ids go from 0x15 to 0x28
        c.MidiOut_Send(midiout, 0xb0, c1_tr_id, 0x0, -1); // turnoff currently-selected track's lights
        const new_cc = @rem(id, 20) + 0x15 - 1;
        c.MidiOut_Send(midiout, 0xb0, @as(u8, @intCast(new_cc)), 0x7f, -1); // set newly-selected to on
        m_bank_offset = id;
        // TODO: update SideChain
        // set all knobs to the current track’s values
        if (trck) |*trk| {
            // trk.order
            c.MidiOut_Send(midiout, 0xb0, @intFromEnum(c1.CCs.Tr_order), @intFromEnum(trk.order), -1);
            inline for (comptime std.enums.values(c1.CCs)) |CC| { // update params according to mappings
                if (CC == c1.CCs.Out_Vol) {
                    const volume = reaper.GetMediaTrackInfo_Value(trackid, "D_VOL");
                    const volint = volToU8(volume);
                    c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), volint, -1);
                } else if (CC == c1.CCs.Out_Pan) {
                    const pan = reaper.GetMediaTrackInfo_Value(trackid, "D_PAN");
                    const val: u8 = @intFromFloat((pan + 1) / 2 * 127);
                    c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), val, -1);
                } else if (CC == c1.CCs.Out_mute) {
                    const mute = reaper.GetMediaTrackInfo_Value(trackid, "B_MUTE");
                    c.MidiOut_Send(midiout, 0xb0, @intFromEnum(CC), if (mute == 1) 0x7f else 0x0, -1);
                } else if (CC == c1.CCs.Out_solo) {
                    const solo = reaper.GetMediaTrackInfo_Value(trackid, "I_SOLO");
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
                    const fxMap = @field(trk.fxMap, @tagName(variant));
                    if (fxMap) |fx| {
                        const fxIdx = fx[0];
                        const mapping = fx[1];
                        if (mapping) |map| {
                            const fxPrm = @field(map, @tagName(CC));
                            const val = reaper.TrackFX_GetParamNormalized(
                                trackid,
                                trk.getSubContainerIdx(fxIdx + 1, // make it 1-based
                                    reaper.TrackFX_GetByName(trackid, CONTROLLER_NAME, false) + 1, // make it 1-based
                                    trackid),
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
}
export fn zOnTrackSelection(trackid: MediaTrack) callconv(.C) void {
    std.debug.print("OnTrackSelection\n", .{});
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
        .MIDI_DEVICE_REMAP => std.debug.print("MIDI_DEVICE_REMAP\n", .{}),
        .RESET => std.debug.print("RESET\n", .{}),
        .SETAUTORECARM => std.debug.print("SETAUTORECARM\n", .{}),
        .SETBPMANDPLAYRATE => std.debug.print("SETBPMANDPLAYRATE\n", .{}),

        // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all parms NULL=clear focused FX
        .SETFOCUSEDFX => {
            std.debug.print("SETFOCUSEDFX\n", .{});
            if (parm2 != null) return 1; // ignore media items' FXchains
            const trId = if (parm1) |trPtr| reaper.CSurf_TrackToID(@as(MediaTrack, @ptrCast(trPtr)), g_csurf_mcpmode) else null;
            if (trId == null) return 1;
            if (parm3) |ptr| {
                const fxIdx = @as(*u8, @ptrCast(ptr));
                display = fxIdx.*;
                std.debug.print("display: {d}\n", .{display.?});
            }
        },
        .SETFXCHANGE => std.debug.print("SETFXCHANGE\n", .{}),
        .SETFXENABLED => std.debug.print("SETFXENABLED\n", .{}),
        // TODO: sync with controller and state

        // #define CSURF_EXT_SETFXOPEN 0x00010012 // parm1=(MediaTrack*)track, parm2=(int*)fxidx, parm3=0 if UI closed, !0 if open
        .SETFXOPEN => {
            // const mediaTrack =  @as(MediaTrack, @ptrCast(parm1.?));
            if (parm3) |ptr| {
                const isOpen = @intFromPtr(ptr);
                // const isOpen = @as(*u8, @ptrCast(ptr));
                if (isOpen == 0) { // UI closed
                    display = null;
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
                display = null;
            }
        },
        .SETFXPARAM => std.debug.print("SETFXPARAM\n", .{}),
        .SETFXPARAM_RECFX => std.debug.print("SETFXPARAM_RECFX\n", .{}),
        .SETINPUTMONITOR => std.debug.print("SETINPUTMONITOR\n", .{}),
        .SETLASTTOUCHEDFX => std.debug.print("SETLASTTOUCHEDFX\n", .{}),
        .SETLASTTOUCHEDTRACK => if (parm1) |mediaTrack| selectTrk(@as(reaper.MediaTrack, @ptrCast(mediaTrack))),
        .SETMETRONOME => std.debug.print("SETMETRONOME\n", .{}),
        .SETMIXERSCROLL => std.debug.print("SETMIXERSCROLL\n", .{}),
        .SETPAN_EX => {
            // csurf doesn't have means of checking if fx get re-ordered.
            // SETPAN_EX does get called if the fx chain is open and the user re-orders the fx, though.
            if (trck) |*track| {
                if (parm1) |mediaTrack| {
                    _ = track.checkTrackState(
                        null,
                        @as(MediaTrack, @ptrCast(mediaTrack)),
                        null,
                    ) catch {};
                }
            }
        },
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
    return 1;
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
