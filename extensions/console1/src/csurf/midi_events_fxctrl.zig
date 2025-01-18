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
const CONTROLLER_NAME = @import("../fx_ctrl_state.zig").CONTROLLER_NAME;
const csurf = @import("control_surface.zig");
const reaeq = @import("../internals/reaeq.zig");

var tmp: [4096:0]u8 = undefined;

pub fn onMidiEvent_FxCtrl(cc: c1.CCs, val: u8) void {
    const tr = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
    switch (cc) {
        .Comp_Mtr => {}, // meters unhandled
        .Inpt_MtrLft => {}, // meters unhandled
        .Inpt_MtrRgt => {}, // meters unhandled
        .Inpt_disp_mode => {
            globals.modifier_active = val == 127;
        },
        .Tr_tr_copy => {},
        .Tr_tr_grp => {},
        .Out_MtrLft => {}, // meters unhandled
        .Out_MtrRgt => {}, // meters unhandled
        .Inpt_disp_on => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .set_fx_ctrl_gui);
            } else {
                const mediaTrack = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
                const cntnrIdx = reaper.TrackFX_GetByName(mediaTrack, CONTROLLER_NAME, false) + 1; // make it 1-based

                if (globals.state.fx_ctrl.display != null) { // hide chain
                    reaper.TrackFX_Show(mediaTrack, cntnrIdx, 0);
                    globals.state.fx_ctrl.display = null;
                } else { // show chain
                    reaper.TrackFX_Show(mediaTrack, cntnrIdx, 1);
                    globals.state.fx_ctrl.display = 1;
                }
            }
        },
        .Inpt_filt_to_comp => {},
        .Inpt_phase_inv => {
            const phase = reaper.GetMediaTrackInfo_Value(tr, "B_PHASE");
            _ = reaper.SetMediaTrackInfo_Value(tr, "B_PHASE", if (phase == 0) 1 else 0);
        },
        .Inpt_preset => {},
        .Out_Pan => {
            setUIVal(cc, u8ToPan(val));
            const rv = reaper.CSurf_OnPanChange(tr, u8ToPan(val), false);
            reaper.CSurf_SetSurfacePan(tr, rv, null);
        },
        .Out_Vol => {
            setUIVal(cc, @as(f64, @floatFromInt(val)) / 127);
            _ = reaper.CSurf_OnVolumeChange(tr, u8ToVol(val), false);
        },
        .Out_mute => reaper.CSurf_SetSurfaceMute(tr, reaper.CSurf_OnMuteChange(tr, -1), null),
        .Out_solo => reaper.CSurf_SetSurfaceSolo(tr, reaper.CSurf_OnSoloChange(tr, -1), null),
        .Shp_Mtr => {}, // meters unhandled
        .Tr_ext_sidechain => {
            // unpin prev 3-4 of comp or gate
            switch (val) {
                0x0, 0x3f, 0x7f => globals.state.fx_ctrl.validateTrack(null, tr, @enumFromInt(val)) catch {},
                else => {},
            }
        },
        .Tr_order => {
            switch (val) {
                0x0, 0x3f, 0x7f => globals.state.fx_ctrl.validateTrack(@enumFromInt(val), tr, null) catch {},
                else => {},
            }
        },
        .Tr_pg_dn => onPgChg(.Down),
        .Tr_pg_up => onPgChg(.Up),
        .Tr_tr1 => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .INPUT } });
            } else {
                selTrck(1);
            }
        },
        .Tr_tr2 => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .GATE } });
            } else {
                selTrck(2);
            }
        },
        .Tr_tr3 => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .EQ } });
            } else {
                selTrck(3);
            }
        },
        .Tr_tr4 => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .COMP } });
            } else {
                selTrck(4);
            }
        },
        .Tr_tr5 => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } });
            } else {
                selTrck(5);
            }
        },
        .Tr_tr6 => selTrck(6),
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
        .Tr_tr20 => {
            if (globals.modifier_active) {
                actions.dispatch(&globals.state, .{ .settings = .open });
            } else {
                selTrck(20);
            }
        },
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

fn u8ToPan(val: u8) f64 {
    // Dividing by (127/2) scales the value to the range 0.0 to 2.0.
    // Subtracting 1.0 shifts the range to -1.0 to 1.0.
    return (@as(f64, @floatFromInt(val)) / (127 / 2)) - 1.0;
}

fn u8ToVol(val: u8) f64 {
    var pos = (@as(f64, @floatFromInt(val)) * 1000.0) / 127.0; // scale to 1000
    pos = reaper.SLIDER2DB(pos); // convert 0-1000 slider position to DB
    return csurf.DB2VAL(pos);
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
    if (pageCount == 0) return;
    globals.state.fx_ctrl.current_page = switch (direction) {
        .Up => @rem(globals.state.fx_ctrl.current_page + 1, pageCount),
        .Down => @as(u8, @intCast(@rem(@as(i16, @intCast(globals.state.fx_ctrl.current_page)) - 1, pageCount))),
    };
    if (globals.m_midi_out) |midi_out| {
        if (globals.state.last_touched_tr_id == -1) return;
        const selTrckOffset = @rem(globals.state.last_touched_tr_id, pageCount);
        if (globals.m_midi_out) |midiout| {
            inline for (@typeInfo(c1.Tracks).Enum.fields, 0..) |f, fieldIdx| {
                if (fieldIdx == @as(usize, @intCast(selTrckOffset))) {
                    c.MidiOut_Send(midi_out, 0xb0, f.value, 0x7f, -1);
                }
            }
            if (selTrckOffset == globals.state.fx_ctrl.current_page) {
                const new_cc = @rem(globals.state.last_touched_tr_id, 20) + 0x15 - 1;
                c.MidiOut_Send(midiout, 0xb0, @as(u8, @intCast(new_cc)), 0x7f, -1); // set newly-selected to on
            }
        }
    }
}

fn selTrck(idx: u8) void {
    if (idx == globals.state.last_touched_tr_id) return;
    const unselected: f64 = 0.0;
    const tr = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
    const success = reaper.SetMediaTrackInfo_Value(tr, "I_SELECTED", unselected); // unselect current
    if (!success) {
        logger.log(.err, "failed to unselect track\n", .{}, null, globals.allocator);
    }
    // don't set the new bank offset, let the re-entrancy deal with it
    const new_tr = reaper.CSurf_TrackFromID(idx, constants.g_csurf_mcpmode);
    reaper.SetTrackSelected(new_tr, true);
    csurf.selectTrk(new_tr);
}

/// set the fx_ctrl UI values
fn setUIVal(cc: c1.CCs, norm_val: f64) void {
    var val_ptr = globals.state.fx_ctrl.values.getPtr(cc) orelse unreachable;
    switch (val_ptr.*) {
        .param => val_ptr.param.normalized = norm_val,
        .button => val_ptr.button = norm_val != 0.0,
        else => {},
    }
}

pub fn setPrmVal(comptime cc: c1.CCs, comptime section: ModulesList, tr: reaper.MediaTrack, val: u8) void {
    const norm_val = @as(f64, @floatFromInt(val)) / 127;
    setUIVal(cc, norm_val);
    const structPrm = @tagName(cc);
    const fxMap = @field(globals.state.fx_ctrl.fxMap, @tagName(section));
    if (fxMap == null) return;
    const fxIdx = fxMap.?[0];
    const mediaTrack = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
    const subIdx = globals.state.fx_ctrl.getSubContainerIdx(
        fxIdx + 1, // make it 1-based
        reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false) + 1, // make it 1-based
        mediaTrack,
    );
    if (globals.state.fx_ctrl.display != null) { // show touched fx
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
            globals.state.fx_ctrl.getSubContainerIdx(fxIdx + 1, // make it 1-based
                reaper.TrackFX_GetByName(tr, CONTROLLER_NAME, false) + 1, // make it 1-based
                mediaTrack),
            fxPrm,
            norm_val,
        );
    }
}
