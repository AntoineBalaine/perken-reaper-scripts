const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("../pReaper.zig");
const MediaTrack = reaper.MediaTrack;
const c1 = @import("../c1.zig");
const Globals = @import("../globals.zig").Globals;
const constants = @import("../constants.zig");
const actions = @import("../actions.zig");
const csurf = @import("control_surface.zig");
const ids = @import("../unit/ids.zig");
const reaeq = @import("../reaeq.zig");
const log = std.log.scoped(.csurf);
const TrackList = @import("../fx_ctrl_state.zig").TrackList;
const utils = @import("utils");
const TrackState = @import("../track_state.zig");
const Unit = @import("../unit/unit.zig");
const step_size = @import("../unit/step.zig");
const ModulesList = @import("../statemachine.zig").ModulesList;
const FxCtrlState = @import("../fx_ctrl_state.zig").FxControlState;

var tmp: [4096:0]u8 = undefined;

/// Helper function to get track or return early
fn getTrack(current_tr_id: ?c_int) ?MediaTrack {
    return if (current_tr_id) |id|
        reaper.CSurf_TrackFromID(id, constants.g_csurf_mcpmode)
    else
        null;
}

/// The functions of the buttons while shift is held in the fx_ctrl mode of the sysex unit. It returns whether the event
/// was taken, so that a shifted press does not also do what the plain press does. The release of a button is never
/// taken, and shift with the knobs is the fine adjust, which the tick carries.
pub fn shiftFunction(globals: *Globals, event: Unit.ControlEvent) bool {
    switch (event) {
        .press => |cc| {
            const module: ModulesList = switch (cc) {
                .Tr_tr1 => .STRIP,
                .Tr_tr2 => .GATE,
                .Tr_tr3 => .EQ,
                .Tr_tr4 => .COMP,
                .Tr_tr5 => .INPUT,
                .Tr_tr6 => .OUTPT,
                .Tr_tr20 => {
                    actions.dispatch(globals, .{ .settings = .open });
                    return true;
                },
                .Inpt_preset => {
                    actions.dispatch(globals, .{ .presets = .{ .enter = .save } });
                    return true;
                },
                else => return false,
            };
            actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = module } });
            return true;
        },
        .tick => |tick| {
            if (tick.cc != .Out_Vol) return false;
            actions.dispatch(globals, .{ .track_list = .{ .step_track = if (tick.delta > 0) 1 else -1 } });
            return true;
        },
        .release => return false,
    }
}

/// A tick of a knob of the sysex unit in the fx_ctrl mode. The value is read from REAPER and moved by the step, so that a
/// parameter that the automation or the mouse moved does not make the knob jump. It returns whether the tick was taken.
pub fn onTick(globals: *Globals, tick: @FieldType(Unit.ControlEvent, "tick")) bool {
    if (globals.state.current_mode != .fx_ctrl) return false;
    globals.state.fx_ctrl.touchKnob(tick.cc, csurf.nowMs());
    const settings = globals.preferences.stepSettings();
    const step = step_size.size(settings, tick.delta, tick.fine);
    switch (tick.cc) {
        .Out_Vol, .Out_Pan => tickTrackKnob(globals, tick.cc, step),
        else => tickParameter(globals, tick.cc, step),
    }
    return true;
}

/// Volume and pan move in REAPER's slider scale, as the legacy position did, and not on the raw value.
fn tickTrackKnob(globals: *Globals, cc: c1.CCs, step: f64) void {
    const tr = getTrack(globals.state.current_tr_id) orelse return;
    const fx_ctrl = &globals.state.fx_ctrl;
    switch (cc) {
        .Out_Vol => {
            const current = utils.volToNormalized(reaper.GetMediaTrackInfo_Value(tr, "D_VOL"));
            const next = step_size.apply(current, step);
            setUIVal(.Out_Vol, next, fx_ctrl);
            reaper.CSurf_SetSurfaceVolume(tr, reaper.CSurf_OnVolumeChange(tr, utils.normalizedToVol(next), false), csurf.surface());
            actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = .Out_Vol, .value = normalizedToMidi(next) } } });
        },
        .Out_Pan => {
            const current = utils.panToNormalized(reaper.GetMediaTrackInfo_Value(tr, "D_PAN"));
            const next = step_size.apply(current, step);
            setUIVal(.Out_Pan, next, fx_ctrl);
            reaper.CSurf_SetSurfacePan(tr, reaper.CSurf_OnPanChange(tr, next * 2.0 - 1.0, false), csurf.surface());
            actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = .Out_Pan, .value = normalizedToMidi(next) } } });
        },
        else => unreachable,
    }
}

fn tickParameter(globals: *Globals, cc: c1.CCs, step: f64) void {
    const fx_ctrl = &globals.state.fx_ctrl;
    // The cut knobs drive the filters of the compressor while the filter is routed to it.
    const target: c1.CCs = if (fx_ctrl.filter_to_comp) switch (cc) {
        .Inpt_HiCut => .Comp_HiCut,
        .Inpt_LoCut => .Comp_LoCut,
        else => cc,
    } else cc;
    const tr = getTrack(globals.state.current_tr_id) orelse return;
    const fxp = fx_ctrl.track_state.forward_map.get(target) orelse return;
    if (fx_ctrl.display != null) pReaper.TrackFX_Show(.{ tr, fxp.fx_index, 1 });

    const current = reaper.TrackFX_GetParamNormalized(tr, fxp.fx_index, fxp.param_index);
    // REAPER reports a parameter that it cannot read as -1 or NaN.
    if (std.math.isNan(current) or current < 0) return;

    var step_size_out: f64 = undefined;
    var small: f64 = undefined;
    var large: f64 = undefined;
    var is_toggle: bool = undefined;
    const stepped = reaper.TrackFX_GetParameterStepSizes(tr, fxp.fx_index, fxp.param_index, &step_size_out, &small, &large, &is_toggle) and step_size_out >= 1.0;
    var next: f64 = current;
    if (stepped) {
        // A stepped parameter takes the ticks until they add up to one of its steps.
        _ = fx_ctrl.track_state.stepDiscreteParam(target, tr, fxp.fx_index, fxp.param_index, step);
        next = reaper.TrackFX_GetParamNormalized(tr, fxp.fx_index, fxp.param_index);
    } else {
        next = step_size.apply(current, step);
        _ = pReaper.TrackFX_SetParamNormalized(.{ tr, fxp.fx_index, fxp.param_index, next });
    }
    setUIVal(target, next, fx_ctrl);
    var fmt_buf: [256:0]u8 = undefined;
    if (reaper.TrackFX_GetFormattedParamValue(tr, fxp.fx_index, @intCast(fxp.param_index), &fmt_buf, fmt_buf.len)) {
        fx_ctrl.track_state.label_pool.setFmtValue(target, std.mem.span(@as([*:0]const u8, &fmt_buf)));
    }
    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = cc, .value = normalizedToMidi(next) } } });
}

/// How far a plugin pulls the signal down, in dB, as it says it with the name "GainReduction_dB", or null when it says
/// nothing, which is the case of the plugins that do not report their reduction to the host. The reduction is a positive
/// amount whichever sign the plugin writes it with.
fn reductionDb(track: MediaTrack, fx_index: c_int) ?f64 {
    var buf: [64:0]u8 = undefined;
    if (!reaper.TrackFX_GetNamedConfigParm(track, fx_index, "GainReduction_dB", buf[0..], buf.len)) return null;
    const value = std.fmt.parseFloat(f64, std.mem.sliceTo(&buf, 0)) catch return null;
    return @abs(value);
}

/// Which track and which plugins the meters of reduction are about. When it changes, the plugins are asked once whether they
/// report a reduction, even if the DAW is stopped, because the card has to know whether it keeps room for a meter.
fn reductionKey(globals: *Globals) u64 {
    const fx_ctrl = &globals.state.fx_ctrl;
    var gate_index: i64 = -1;
    var comp_index: i64 = -1;
    var kind: i64 = 0;
    switch (fx_ctrl.track_state.mode) {
        .multi_fx => |locations| {
            if (locations.get(.GATE)) |gate| gate_index = gate.fx_index;
            if (locations.get(.COMP)) |comp| comp_index = comp.fx_index;
        },
        .channel_strip => |strip| {
            kind = 1;
            comp_index = strip.fx_index;
        },
    }
    const track: i64 = globals.state.current_tr_id orelse -1;
    return std.hash.Wyhash.hash(0, std.mem.asBytes(&[_]i64{ track, kind, gate_index, comp_index }));
}

/// Reads how far the gate and the compressor of the selected track pull the signal down, for the meters of the panel. A
/// module whose plugin does not report it has no meter. The channel strip has one plugin for all of them, which is read for
/// the compressor only, as the unit's meter does. REAPER is asked only while the DAW plays, since nothing moves otherwise,
/// and once when the track or its plugins change, to know which plugins report.
fn readReductionMeters(globals: *Globals, playing: bool) void {
    const fx_ctrl = &globals.state.fx_ctrl;
    const key = reductionKey(globals);
    if (!playing and key == fx_ctrl.reduction_key) {
        // The meters that exist rest at no reduction.
        if (fx_ctrl.gate_reduction_db != null) fx_ctrl.gate_reduction_db = 0;
        if (fx_ctrl.comp_reduction_db != null) fx_ctrl.comp_reduction_db = 0;
        return;
    }
    fx_ctrl.reduction_key = key;
    fx_ctrl.gate_reduction_db = null;
    fx_ctrl.comp_reduction_db = null;
    const tr = getTrack(globals.state.current_tr_id) orelse return;
    switch (fx_ctrl.track_state.mode) {
        .multi_fx => |locations| {
            if (locations.get(.GATE)) |gate| fx_ctrl.gate_reduction_db = reductionDb(tr, gate.fx_index);
            if (locations.get(.COMP)) |comp| fx_ctrl.comp_reduction_db = reductionDb(tr, comp.fx_index);
        },
        .channel_strip => |strip| fx_ctrl.comp_reduction_db = reductionDb(tr, strip.fx_index),
    }
}

/// How fast the output meter falls, in dB for each frame.
const out_level_fall_db = 1.5;

/// Reads the level of the output of the selected track, for the meter of the panel, which falls slowly after a peak. REAPER is
/// asked only while the DAW plays; the meter falls to its floor when it does not.
fn readOutputLevels(globals: *Globals, playing: bool) void {
    const fx_ctrl = &globals.state.fx_ctrl;
    const floor = FxCtrlState.out_level_floor_db;
    const tr = getTrack(globals.state.current_tr_id);
    for (&fx_ctrl.out_level_db, 0..) |*level, channel| {
        var measured = floor;
        if (playing) {
            if (tr) |track| {
                const peak = reaper.Track_GetPeakInfo(track, @intCast(channel));
                if (peak > 0.000001) measured = 20.0 * std.math.log10(peak);
            }
        }
        level.* = @max(measured, level.* - out_level_fall_db, floor);
    }
}

/// Reads what the meters of the panel show, which REAPER is asked only while the DAW plays.
pub fn readMeters(globals: *Globals) void {
    const playing = globals.playState and !globals.pauseState;
    globals.state.fx_ctrl.meters_playing = playing;
    readReductionMeters(globals, playing);
    readOutputLevels(globals, playing);
}

/// Sets one of the toggles of the selected track in the state that the panel draws.
pub fn setTrackToggle(globals: *Globals, cc: c1.CCs, on: bool) void {
    const value = globals.state.fx_ctrl.values.getPtr(cc) orelse return;
    std.debug.assert(value.* == .button);
    value.* = .{ .button = on };
}

/// Reads the mute, solo and phase of a track that has just become the selected one. After that, REAPER's
/// notifications of mute and solo, and the actions of the panel itself, keep them up to date: no check is made
/// on every frame. REAPER has no notification for the phase of a track, so a phase that is changed outside of
/// the panel is seen when the track is selected again.
pub fn readTrackToggles(globals: *Globals, tr: MediaTrack) void {
    setTrackToggle(globals, .Out_mute, reaper.GetMediaTrackInfo_Value(tr, "B_MUTE") > 0.5);
    setTrackToggle(globals, .Out_solo, reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0.5);
    setTrackToggle(globals, .Inpt_phase_inv, reaper.GetMediaTrackInfo_Value(tr, "B_PHASE") > 0.5);
}

/// The color of a track as the track list shows it: the color of the track in the TCP, lightened when it is
/// too dark to be read on the dark face of the panel, as 0xRRGGBBAA. 0 is no color.
pub fn trackListColor(id: c_int) c_int {
    const track = getTrack(id) orelse return 0;
    const native = reaper.GetTrackColor(track);
    if (native & 0x1000000 == 0) return 0;
    var r: c_int = undefined;
    var g: c_int = undefined;
    var b: c_int = undefined;
    reaper.ColorFromNative(native & 0xFFFFFF, &r, &g, &b);
    std.debug.assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255);
    const luma = @divTrunc(299 * r + 587 * g + 114 * b, 1000);
    const readable_luma = 130;
    if (luma < readable_luma) {
        const t = @as(f64, @floatFromInt(readable_luma - luma)) / readable_luma * 0.7;
        r = @intFromFloat(@as(f64, @floatFromInt(r)) + @as(f64, @floatFromInt(255 - r)) * t);
        g = @intFromFloat(@as(f64, @floatFromInt(g)) + @as(f64, @floatFromInt(255 - g)) * t);
        b = @intFromFloat(@as(f64, @floatFromInt(b)) + @as(f64, @floatFromInt(255 - b)) * t);
    }
    const rgba: u32 = (@as(u32, @intCast(r)) << 24) | (@as(u32, @intCast(g)) << 16) | (@as(u32, @intCast(b)) << 8) | 0xFF;
    return @bitCast(rgba);
}

pub fn onMidiEvent_FxCtrl(io: std.Io, cc: c1.CCs, val: u8, globals: *Globals) void {
    // The legacy unit turns its knobs through here, and the sysex unit through `onTick`.
    if (ids.isKnob(cc)) globals.state.fx_ctrl.touchKnob(cc, csurf.nowMs());
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
                reaper.CSurf_SetSurfacePan(tr, reaper.CSurf_OnPanChange(tr, u8ToPan(val), false), csurf.surface());
            }
        },
        .Out_Vol => {
            setUIVal(cc, @as(f64, @floatFromInt(val)) / 127, &globals.state.fx_ctrl);
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfaceVolume(tr, reaper.CSurf_OnVolumeChange(tr, u8ToVol(val), false), csurf.surface());
            }
        },
        .Out_mute => {
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfaceMute(tr, reaper.CSurf_OnMuteChange(tr, -1), csurf.surface());
            }
        },
        .Out_solo => {
            if (getTrack(globals.state.current_tr_id)) |tr| {
                reaper.CSurf_SetSurfaceSolo(tr, reaper.CSurf_OnSoloChange(tr, -1), csurf.surface());
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
                    0x0, 0x3f, 0x7f => globals.state.fx_ctrl.routeSideChain(
                        tr,
                        @fromBackingInt(@intCast(val)),
                        globals.preferences.manual_routing,
                    ),
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
                        @fromBackingInt(@intCast(val)),
                        tr,
                        null,
                        globals.preferences.manual_routing,
                        globals.preferences.default_fx,
                        &globals.map_store,
                        &globals.preferences,
                        globals.arena_int.allocator(),
                        io,
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
                onMidiEvent_FxCtrl(io, if (cc == .Inpt_HiCut) .Comp_HiCut else .Comp_LoCut, val, globals);
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

/// Because REAPER reports a parameter that it cannot read as -1 or NaN, the value is clamped before it is
/// converted, as the conversion of a float outside the range of the integer is a panic.
fn normalizedToMidi(value: f64) u8 {
    if (std.math.isNan(value)) return 0;
    return @intFromFloat(std.math.clamp(value, 0.0, 1.0) * 127);
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
        .value = normalizedToMidi(hi),
    } } });
    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{
        .cc = .Inpt_LoCut,
        .value = normalizedToMidi(lo),
    } } });
}

inline fn getTrackIndex(cc: c1.CCs, page_offset: u8) usize {
    const button_idx = @backingInt(cc) - @backingInt(c1.CCs.Tr_tr1);
    return page_offset * TrackList.PageSize + button_idx;
}
