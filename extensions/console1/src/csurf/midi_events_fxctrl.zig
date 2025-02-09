const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const pReaper = @import("../pReaper.zig");
const MediaTrack = reaper.MediaTrack;
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
const CONTROLLER_NAME = constants.CONTROLLER_NAME;
const csurf = @import("control_surface.zig");
const reaeq = @import("../reaeq.zig");
const log = std.log.scoped(.csurf);
const track_list = @import("../tracklist_actions.zig");
const TrackListAction = track_list.TrackListAction;
const PgDirection = track_list.PgDirection;
const TrackList = @import("../fx_ctrl_state.zig").TrackList;
const utils = @import("../utils.zig");

var tmp: [4096:0]u8 = undefined;

/// Helper function to get track or return early
fn getTrack() ?MediaTrack {
    return if (globals.state.current_tr_id) |id|
        reaper.CSurf_TrackFromID(id, constants.g_csurf_mcpmode)
    else
        null;
}

pub fn onMidiEvent_FxCtrl(cc: c1.CCs, val: u8) void {
    switch (cc) {
        .Inpt_disp_mode => {
            actions.dispatch(&globals.state, .{ .change_mode = .transport });
        },
        .Tr_tr_copy, .Tr_tr_grp => {},
        .Comp_Mtr, .Inpt_MtrLft, .Inpt_MtrRgt, .Out_MtrLft, .Out_MtrRgt => {}, // meters unhandled
        .Inpt_disp_on => {
            if (getTrack()) |mediaTrack| {
                globals.state.fx_ctrl.display = if (globals.state.fx_ctrl.display) |_| null else 1;
                actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .fx_win_disp = mediaTrack } });
            }
        },
        .Inpt_filt_to_comp => {},
        .Inpt_phase_inv => {
            if (getTrack()) |tr| {
                const phase = reaper.GetMediaTrackInfo_Value(tr, "B_PHASE");
                const phase_val: f64 = if (phase == 0) 1 else 0;
                _ = pReaper.SetMediaTrackInfo_Value(.{ tr, "B_PHASE", phase_val });
            }
        },
        .Inpt_preset => {},
        .Out_Pan => {
            if (getTrack()) |tr| {
                setUIVal(cc, u8ToPan(val));
                reaper.CSurf_SetSurfacePan(tr, reaper.CSurf_OnPanChange(tr, u8ToPan(val), false), @ptrCast(csurf.my_csurf));
            }
        },
        .Out_Vol => {
            if (getTrack()) |tr| {
                setUIVal(cc, @as(f64, @floatFromInt(val)) / 127);
                reaper.CSurf_SetSurfaceVolume(tr, reaper.CSurf_OnVolumeChange(tr, u8ToVol(val), false), @ptrCast(csurf.my_csurf));
            }
        },
        .Out_mute => {
            if (getTrack()) |tr| {
                reaper.CSurf_SetSurfaceMute(tr, reaper.CSurf_OnMuteChange(tr, -1), @ptrCast(csurf.my_csurf));
            }
        },
        .Out_solo => {
            if (getTrack()) |tr| {
                reaper.CSurf_SetSurfaceSolo(tr, reaper.CSurf_OnSoloChange(tr, -1), @ptrCast(csurf.my_csurf));
            }
        },
        .Shp_Mtr => {}, // meters unhandled
        .Tr_ext_sidechain => {
            if (getTrack()) |tr| {
                switch (val) {
                    0x0, 0x3f, 0x7f => globals.state.fx_ctrl.validateTrack(null, tr, @enumFromInt(val)) catch {},
                    else => {},
                }
            }
        },
        .Tr_order => {
            if (getTrack()) |tr| {
                switch (val) {
                    0x0, 0x3f, 0x7f => globals.state.fx_ctrl.validateTrack(@enumFromInt(val), tr, null) catch {},
                    else => {},
                }
            }
        },
        .Tr_pg_up => {
            actions.dispatch(&globals.state, .{ .track_list = .{ .page_change = .up } });
            actions.dispatch(&globals.state, .{ .midi_out = .page_change });
        },
        .Tr_pg_dn => {
            actions.dispatch(&globals.state, .{ .track_list = .{ .page_change = .down } });
            actions.dispatch(&globals.state, .{ .midi_out = .page_change });
        },
        .Tr_tr1,
        .Tr_tr2,
        .Tr_tr3,
        .Tr_tr4,
        .Tr_tr5,
        => |cc_| {
            const track_idx = getTrackIndex(cc_, globals.state.fx_ctrl.current_page);
            actions.dispatch(&globals.state, .{ .track_list = .{ .track_select = @intCast(track_idx) } });
        },
        .Tr_tr6,
        .Tr_tr7,
        .Tr_tr8,
        .Tr_tr9,
        .Tr_tr10,
        .Tr_tr11,
        .Tr_tr12,
        .Tr_tr13,
        .Tr_tr14,
        .Tr_tr15,
        .Tr_tr16,
        .Tr_tr17,
        .Tr_tr18,
        .Tr_tr19,
        => |cc_| {
            const track_idx = getTrackIndex(cc_, globals.state.fx_ctrl.current_page);
            actions.dispatch(&globals.state, .{ .track_list = .{ .track_select = @intCast(track_idx) } });
        },
        .Tr_tr20 => {
            const track_idx = getTrackIndex(.Tr_tr20, globals.state.fx_ctrl.current_page);
            actions.dispatch(&globals.state, .{ .track_list = .{ .track_select = @intCast(track_idx) } });
        },
        inline else => |cc_| {
            if (getTrack()) |tr| {
                setPrmVal(cc_, switch (cc_) {
                    .Comp_Attack, .Comp_DryWet, .Comp_Ratio, .Comp_Release, .Comp_Thresh, .Comp_comp => .COMP,
                    .Eq_HiFrq, .Eq_HiGain, .Eq_HiMidFrq, .Eq_HiMidGain, .Eq_HiMidQ, .Eq_LoFrq, .Eq_LoGain, .Eq_LoMidFrq, .Eq_LoMidGain, .Eq_LoMidQ, .Eq_eq, .Eq_hp_shape, .Eq_lp_shape => .EQ,
                    .Inpt_Gain, .Inpt_HiCut, .Inpt_LoCut => .INPUT,
                    .Out_Drive, .Out_DriveChar => .OUTPT,
                    .Shp_GateRelease, .Shp_Gate, .Shp_Punch, .Shp_hard_gate, .Shp_shape, .Shp_sustain => .GATE,
                    else => unreachable,
                }, tr, val);
            }
        },
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
    return utils.DB2VAL(pos);
}

const PgChgDirection = enum { Up, Down };

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
    const fxMap = globals.state.fx_ctrl.track_state.module_locations.get(section);
    if (fxMap == null) return;
    const fxIdx = fxMap.?.fx_index;
    if (globals.state.fx_ctrl.display != null) { // show touched fx
        pReaper.TrackFX_Show(.{ tr, fxIdx, 1 });
    }
    // if setting filter types on reaeq
    if ((cc == c1.CCs.Eq_hp_shape or cc == c1.CCs.Eq_lp_shape)) {
        const hasName = reaper.TrackFX_GetFXName(tr, fxIdx, &tmp, tmp.len);
        if (hasName and std.mem.eql(u8, std.mem.span(@as([*:0]const u8, &tmp)), "VST: ReaEQ (Cockos)"))
            reaeq.setReaEqFilterType(tr, fxIdx, cc, val);
        return;
    }

    const mapping = fxMap.?.mapping;
    if (mapping) |map| { // handle mapping
        const fxPrm = @field(@field(map, @tagName(section)), structPrm);

        // at fxIdx, at fxPrm, set the value
        if (fxPrm) |param| {
            log.info("set param\n", .{});
            _ = pReaper.TrackFX_SetParamNormalized(.{ tr, fxIdx, param, norm_val });
        }
    }
}

inline fn getTrackIndex(cc: c1.CCs, page_offset: u8) usize {
    const button_idx = @intFromEnum(cc) - @intFromEnum(c1.CCs.Tr_tr1);
    return page_offset * TrackList.PageSize + button_idx;
}
