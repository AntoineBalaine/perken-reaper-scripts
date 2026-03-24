const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const pReaper = @import("../pReaper.zig");
const MediaTrack = reaper.MediaTrack;
const c1 = @import("../c1.zig");
const Globals = @import("../globals.zig").Globals;
const constants = @import("../constants.zig");
const actions = @import("../actions.zig");
const csurf = @import("control_surface.zig");
const reaeq = @import("../reaeq.zig");
const log = std.log.scoped(.csurf);
const TrackList = @import("../fx_ctrl_state.zig").TrackList;
const utils = @import("../utils.zig");
const TrackState = @import("../track_state.zig");
const FxCtrlState = @import("../fx_ctrl_state.zig").FxControlState;

var tmp: [4096:0]u8 = undefined;

/// Helper function to get track or return early
fn getTrack(current_tr_id: ?c_int) ?MediaTrack {
    return if (current_tr_id) |id|
        reaper.CSurf_TrackFromID(id, constants.g_csurf_mcpmode)
    else
        null;
}

pub fn onMidiEvent_FxCtrl(cc: c1.CCs, val: u8, globals: *Globals) void {
    switch (cc) {
        .Inpt_disp_mode => {
            actions.dispatch(globals, .{ .change_mode = .transport });
        },
        .Tr_tr_copy, .Tr_tr_grp => {},
        .Comp_Mtr, .Inpt_MtrLft, .Inpt_MtrRgt, .Out_MtrLft, .Out_MtrRgt => {}, // meters unhandled
        .Inpt_disp_on => {
            if (getTrack(globals.state.current_tr_id)) |mediaTrack| {
                actions.dispatch(globals, .{ .fx_ctrl = .{ .fx_win_disp = mediaTrack } });
            }
        },
        .Inpt_filt_to_comp => {
            globals.state.fx_ctrl.filter_to_comp = !globals.state.fx_ctrl.filter_to_comp;
            actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{
                .cc = .Inpt_filt_to_comp,
                .value = if (globals.state.fx_ctrl.filter_to_comp) 0x7f else 0x00,
            } } });
            syncFilterKnobs(globals);
        },
        .Inpt_phase_inv => {
            if (getTrack(globals.state.current_tr_id)) |tr| {
                actions.dispatch(globals, .{ .fx_ctrl = .{ .toggle_phase_inv = tr } });
            }
        },
        .Inpt_preset => {},
        .Out_Pan => {
            const norm_val = @as(f64, @floatFromInt(val)) / 127.0;
            setUIVal(cc, norm_val, &globals.state.fx_ctrl);
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfacePan(tr, reaper.CSurf_OnPanChange(tr, u8ToPan(val), false), @ptrCast(csurf.my_csurf));
            }
        },
        .Out_Vol => {
            setUIVal(cc, @as(f64, @floatFromInt(val)) / 127, &globals.state.fx_ctrl);
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfaceVolume(tr, reaper.CSurf_OnVolumeChange(tr, u8ToVol(val), false), @ptrCast(csurf.my_csurf));
            }
        },
        .Out_mute => {
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfaceMute(tr, reaper.CSurf_OnMuteChange(tr, -1), @ptrCast(csurf.my_csurf));
            }
        },
        .Out_solo => {
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfaceSolo(tr, reaper.CSurf_OnSoloChange(tr, -1), @ptrCast(csurf.my_csurf));
            }
        },
        .Shp_Mtr => {}, // meters unhandled
        .Tr_ext_sidechain => {
            if (globals.state.fx_ctrl.track_state.mode == .channel_strip) {
                if (getTrack(globals.state.current_tr_id)) |tr| {
                    setPrmVal(.Tr_ext_sidechain, tr, val, &globals.state.fx_ctrl);
                }
                return;
            }
            if (getTrack(globals.state.current_tr_id)) |tr| {
                switch (val) {
                    0x0, 0x3f, 0x7f => globals.state.fx_ctrl.validateTrack(
                        null,
                        tr,
                        @enumFromInt(val),
                        globals.preferences.manual_routing,
                        globals.preferences.default_fx,
                        &globals.map_store,
                        &globals.preferences,
                        globals.arena,
                        &globals.mappings_list,
                    ) catch {},
                    else => {},
                }
            }
        },
        .Tr_order => {
            if (globals.state.fx_ctrl.track_state.mode == .channel_strip) {
                if (getTrack(globals.state.current_tr_id)) |tr| {
                    setPrmVal(.Tr_order, tr, val, &globals.state.fx_ctrl);
                }
                return;
            }
            if (getTrack(globals.state.current_tr_id)) |tr| {
                switch (val) {
                    0x0, 0x3f, 0x7f => globals.state.fx_ctrl.validateTrack(
                        @enumFromInt(val),
                        tr,
                        null,
                        globals.preferences.manual_routing,
                        globals.preferences.default_fx,
                        &globals.map_store,
                        &globals.preferences,
                        globals.arena,
                        &globals.mappings_list,
                    ) catch {},
                    else => {},
                }
            }
        },
        .Tr_pg_up => {
            actions.dispatch(globals, .{ .track_list = .{ .page_change = .up } });
            actions.dispatch(globals, .{ .midi_out = .page_change });
        },
        .Tr_pg_dn => {
            actions.dispatch(globals, .{ .track_list = .{ .page_change = .down } });
            actions.dispatch(globals, .{ .midi_out = .page_change });
        },
        .Tr_tr1,
        .Tr_tr2,
        .Tr_tr3,
        .Tr_tr4,
        .Tr_tr5,
        => |cc_| {
            const track_idx = getTrackIndex(cc_, globals.state.fx_ctrl.current_page);
            actions.dispatch(globals, .{ .track_list = .{ .track_select = @intCast(track_idx) } });
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
            actions.dispatch(globals, .{ .track_list = .{ .track_select = @intCast(track_idx) } });
        },
        .Tr_tr20 => {
            const track_idx = getTrackIndex(.Tr_tr20, globals.state.fx_ctrl.current_page);
            actions.dispatch(globals, .{ .track_list = .{ .track_select = @intCast(track_idx) } });
        },
        .Inpt_HiCut, .Inpt_LoCut => {
            if (globals.state.fx_ctrl.filter_to_comp) {
                onMidiEvent_FxCtrl(if (cc == .Inpt_HiCut) .Comp_HiCut else .Comp_LoCut, val, globals);
            } else {
                if (getTrack(globals.state.current_tr_id)) |tr| {
                    if (cc == .Inpt_HiCut) {
                        setPrmVal(.Inpt_HiCut, tr, val, &globals.state.fx_ctrl);
                    } else {
                        setPrmVal(.Inpt_LoCut, tr, val, &globals.state.fx_ctrl);
                    }
                }
            }
        },
        else => {
            if (getTrack(globals.state.current_tr_id)) |tr| {
                setPrmVal(cc, tr, val, &globals.state.fx_ctrl);
            }
        },
    }
}

fn u8ToPan(val: u8) f64 {
    // Dividing by (127/2) scales the value to the range 0.0 to 2.0.
    // Subtracting 1.0 shifts the range to -1.0 to 1.0.
    return (@as(f64, @floatFromInt(val)) / (127 / 2)) - 1.0;
}

pub fn u8ToVol(val: u8) f64 {
    var pos = (@as(f64, @floatFromInt(val)) * 1000.0) / 127.0; // scale to 1000
    pos = reaper.SLIDER2DB(pos); // convert 0-1000 slider position to DB
    return utils.DB2VAL(pos);
}

/// set the fx_ctrl UI values
pub fn setUIVal(cc: c1.CCs, norm_val: f64, fx_ctrl: *FxCtrlState) void {
    var val_ptr = fx_ctrl.values.getPtr(cc) orelse unreachable;
    switch (val_ptr.*) {
        .param => val_ptr.param.normalized = norm_val,
        .button => val_ptr.button = norm_val != 0.0,
        else => {},
    }
}

pub fn setPrmVal(cc: c1.CCs, tr: reaper.MediaTrack, val: u8, fx_ctrl: *FxCtrlState) void {
    const norm_val = @as(f64, @floatFromInt(val)) / 127;
    // Capture the previous value before updating, because discrete
    // stepping needs it to determine direction.
    const prev_norm = if (fx_ctrl.values.getPtr(cc)) |vp| switch (vp.*) {
        .param => |p| p.normalized,
        else => 0.0,
    } else 0.0;
    setUIVal(cc, norm_val, fx_ctrl);
    const fxp = fx_ctrl.track_state.forward_map.get(cc) orelse return;

    if (fx_ctrl.display != null) {
        pReaper.TrackFX_Show(.{ tr, fxp.fx_index, 1 });
    }

    // ReaEQ filter types are synthetic params handled via SetNamedConfigParm
    if ((cc == c1.CCs.Eq_hp_shape or cc == c1.CCs.Eq_lp_shape) and fxp.param_index == TrackState.FxParam.SYNTHETIC) {
        reaeq.cycleReaEqFilterType(tr, fxp.fx_index, cc);
        const band_key: [:0]const u8 = if (cc == c1.CCs.Eq_lp_shape) "BANDTYPE0" else "BANDTYPE3";
        var band_buf: [64:0]u8 = undefined;
        if (reaper.TrackFX_GetNamedConfigParm(tr, fxp.fx_index, band_key, &band_buf, band_buf.len)) {
            const band_str = std.mem.span(@as([*:0]const u8, &band_buf));
            const band_int = std.fmt.parseInt(c_int, band_str, 10) catch 0;
            const name = TrackState.bandTypeName(band_int);
            fx_ctrl.track_state.label_pool.setPrmLabel(cc, name);
            fx_ctrl.track_state.label_pool.setFmtValue(cc, name);
        }
        return;
    }

    if (cc.isBtn()) {
        const new_norm = TrackState.cycleDiscreteParam(tr, fxp.fx_index, fxp.param_index, fxp.is_toggle);
        setUIVal(cc, new_norm, fx_ctrl);
    } else {
        const norm_delta = norm_val - prev_norm;
        if (fx_ctrl.track_state.stepDiscreteParam(cc, tr, fxp.fx_index, fxp.param_index, norm_delta)) |new_norm| {
            setUIVal(cc, new_norm, fx_ctrl);
        } else {
            _ = pReaper.TrackFX_SetParamNormalized(.{ tr, fxp.fx_index, fxp.param_index, norm_val });
        }
    }
    var fmt_buf: [256:0]u8 = undefined;
    if (reaper.TrackFX_GetFormattedParamValue(tr, fxp.fx_index, @intCast(fxp.param_index), &fmt_buf, fmt_buf.len)) {
        fx_ctrl.track_state.label_pool.setFmtValue(cc, std.mem.span(@as([*:0]const u8, &fmt_buf)));
    }
}

pub fn syncFilterKnobs(globals: *Globals) void {
    const tr = getTrack(globals.state.current_tr_id) orelse return;
    const fx_ctrl = &globals.state.fx_ctrl;
    var lo: f64 = 0.0;
    var hi: f64 = 0.0;

    const filter_locs = fx_ctrl.track_state.getModuleLocations() orelse return;
    if (fx_ctrl.filter_to_comp) {
        if (filter_locs.get(.COMP)) |comp_loc| {
            if (comp_loc.mapping) |mapping| {
                if (mapping.COMP.Comp_HiCut) |param|
                    hi = reaper.TrackFX_GetParamNormalized(tr, comp_loc.fx_index, param);
                if (mapping.COMP.Comp_LoCut) |param|
                    lo = reaper.TrackFX_GetParamNormalized(tr, comp_loc.fx_index, param);
            }
        }
    } else {
        if (filter_locs.get(.INPUT)) |input_loc| {
            if (input_loc.mapping) |mapping| {
                if (mapping.INPUT.Inpt_HiCut) |param|
                    hi = reaper.TrackFX_GetParamNormalized(tr, input_loc.fx_index, param);
                if (mapping.INPUT.Inpt_LoCut) |param|
                    lo = reaper.TrackFX_GetParamNormalized(tr, input_loc.fx_index, param);
            }
        }
    }
    const hicut_cc: c1.CCs = if (fx_ctrl.filter_to_comp) .Comp_HiCut else .Inpt_HiCut;
    const locut_cc: c1.CCs = if (fx_ctrl.filter_to_comp) .Comp_LoCut else .Inpt_LoCut;
    setUIVal(hicut_cc, hi, fx_ctrl);
    setUIVal(locut_cc, lo, fx_ctrl);
    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{
        .cc = .Inpt_HiCut,
        .value = @intFromFloat(@min(hi, 1.0) * 127),
    } } });
    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{
        .cc = .Inpt_LoCut,
        .value = @intFromFloat(@min(lo, 1.0) * 127),
    } } });
}

inline fn getTrackIndex(cc: c1.CCs, page_offset: u8) usize {
    const button_idx = @intFromEnum(cc) - @intFromEnum(c1.CCs.Tr_tr1);
    return page_offset * TrackList.PageSize + button_idx;
}
