const std = @import("std");
const c1 = @import("c1.zig");
const constants = @import("constants.zig");
const reaper = @import("reaper.zig").reaper;
const MediaTrack = reaper.MediaTrack;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const SCRouting = fx_ctrl_state.SCRouting;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const Globals = @import("globals.zig").Globals;
const MidiEvts = @import("csurf/midi_events_fxctrl.zig");
const onMidiEvent_FxCtrl = MidiEvts.onMidiEvent_FxCtrl;
const actions = @import("actions.zig");
const pReaper = @import("pReaper.zig");
const csurf = @import("csurf/control_surface.zig");
const utils = @import("utils.zig");
const reaeq = @import("reaeq.zig");
const TrackState = @import("track_state.zig");

const log = std.log.scoped(.midi_input);

pub const MidiInput = @import("action_types.zig").MidiInput;
pub const WidgetInput = @import("action_types.zig").WidgetInput;
pub const FxCtrlAction = @import("action_types.zig").FxCtrlAction;

pub fn fxCtrlActions(globals: *Globals, fx_action: FxCtrlAction) void {
    switch (fx_action) {
        .midi_input => |input| {
            log.debug(
                "MIDI input: {s} -> {d} evt: {}",
                .{ @tagName(input.cc), input.value, logger.Event{ .midi_input = .{ .cc = input.cc, .value = input.value } } },
            );
            onMidiEvent_FxCtrl(input.cc, input.value, globals);
        },
        .panel_input => |input| {
            // Special handling for our three controls
            switch (input.cc) {
                .Inpt_preset => {
                    actions.dispatch(globals, .{ .change_mode = .mapping_panel });
                    actions.dispatch(globals, .{ .mapping_panel = .enter_browse });
                },
                .Inpt_phase_inv => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        actions.dispatch(globals, .{ .fx_ctrl = .{ .toggle_phase_inv = media_track } });
                    }
                },
                .Out_mute => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        reaper.CSurf_SetSurfaceMute(media_track, reaper.CSurf_OnMuteChange(media_track, -1), @ptrCast(csurf.my_csurf));
                        // Send MIDI feedback
                        actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                    }
                },
                .Out_solo => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        reaper.CSurf_SetSurfaceSolo(media_track, reaper.CSurf_OnSoloChange(media_track, -1), @ptrCast(csurf.my_csurf));
                        actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                    }
                },
                .Out_Vol => {
                    MidiEvts.setUIVal(.Out_Vol, input.value, &globals.state.fx_ctrl);
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);

                        const vol_value = utils.normalizedToVol(input.value);

                        pReaper.CSurf_SetSurfaceVolume(.{ media_track, pReaper.CSurf_OnVolumeChange(.{ media_track, vol_value, false }), @as(reaper.IReaperControlSurface, @ptrCast(csurf.my_csurf)) });
                    }
                },
                .Out_Pan => {
                    MidiEvts.setUIVal(.Out_Pan, input.value, &globals.state.fx_ctrl);
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(input.value * 127.0) } } });
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        const pan_value = utils.normalizedToPan(input.value);
                        pReaper.CSurf_SetSurfacePan(.{ media_track, pReaper.CSurf_OnPanChange(.{ media_track, pan_value, false }), @as(reaper.IReaperControlSurface, @ptrCast(csurf.my_csurf)) });
                    }
                },
                .Inpt_disp_on => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        actions.dispatch(globals, .{ .fx_ctrl = .{ .fx_win_disp = media_track } });
                    }
                },
                .Inpt_disp_mode => {
                    actions.dispatch(globals, .{ .change_mode = .transport });
                },
                .Tr_ext_sidechain => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        const routing: SCRouting = @enumFromInt(@as(u8, @intFromFloat(input.value)));
                        globals.state.fx_ctrl.validateTrack(
                            null,
                            media_track,
                            routing,
                            globals.preferences.manual_routing,
                            globals.preferences.default_fx,
                            &globals.map_store,
                            &globals.preferences,
                            globals.arena,
                            &globals.mappings_list,
                        ) catch {};
                    }
                },
                .Tr_order => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        const order: ModulesOrder = @enumFromInt(@as(u8, @intFromFloat(input.value)));
                        globals.state.fx_ctrl.validateTrack(
                            order,
                            media_track,
                            null,
                            globals.preferences.manual_routing,
                            globals.preferences.default_fx,
                            &globals.map_store,
                            &globals.preferences,
                            globals.arena,
                            &globals.mappings_list,
                        ) catch {};
                    }
                },
                .Inpt_filt_to_comp => {
                    globals.state.fx_ctrl.filter_to_comp = !globals.state.fx_ctrl.filter_to_comp;
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{
                        .cc = .Inpt_filt_to_comp,
                        .value = if (globals.state.fx_ctrl.filter_to_comp) 0x7f else 0x00,
                    } } });
                    MidiEvts.syncFilterKnobs(globals);
                },
                .Inpt_HiCut, .Inpt_LoCut => {
                    if (globals.state.fx_ctrl.filter_to_comp) {
                        const remapped: c1.CCs = if (input.cc == .Inpt_HiCut) .Comp_HiCut else .Comp_LoCut;
                        fxCtrlActions(globals, .{ .panel_input = .{ .cc = remapped, .value = input.value } });
                        // MIDI feedback to the physical CC for hardware LED sync
                        actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                        return;
                    }
                    // Fall through to the generic handler for the INPUT path
                    if (globals.state.fx_ctrl.values.getPtr(input.cc)) |value_ptr| {
                        value_ptr.param.normalized = input.value;
                    }
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        if (globals.state.fx_ctrl.track_state.forward_map.get(input.cc)) |fxp| {
                            _ = pReaper.TrackFX_SetParamNormalized(.{ media_track, fxp.fx_index, fxp.param_index, input.value });
                            var fmt_buf: [256:0]u8 = undefined;
                            if (reaper.TrackFX_GetFormattedParamValue(media_track, fxp.fx_index, @intCast(fxp.param_index), &fmt_buf, fmt_buf.len)) {
                                globals.state.fx_ctrl.track_state.label_pool.setFmtValue(input.cc, std.mem.span(@as([*:0]const u8, &fmt_buf)));
                            }
                        }
                    }
                },
                else => {
                    // Get the control value pointer
                    if (globals.state.fx_ctrl.values.getPtr(input.cc)) |value_ptr| {
                        // Check which variant is active
                        switch (value_ptr.*) {
                            .param => |*param_value| {
                                // Handle parameter type
                                param_value.normalized = input.value;
                            },
                            .button => |*button_value| {
                                // Handle button type (convert value to boolean)
                                button_value.* = input.value > 0.5;
                            },
                            .track, .meter => {
                                // These types shouldn't be handled here
                                log.warn("Unexpected control type for CC {s}", .{@tagName(input.cc)});
                            },
                        }
                    }

                    // Send MIDI feedback regardless of the control type
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        if (globals.state.fx_ctrl.track_state.forward_map.get(input.cc)) |fxp| {
                            if (input.cc.isBtn()) {
                                // Button CCs use cycling logic for discrete/toggle params
                                const new_norm = TrackState.cycleDiscreteParam(media_track, fxp.fx_index, fxp.param_index, fxp.is_toggle);
                                if (globals.state.fx_ctrl.values.getPtr(input.cc)) |vp| {
                                    vp.param.normalized = new_norm;
                                }
                            } else {
                                _ = pReaper.TrackFX_SetParamNormalized(.{ media_track, fxp.fx_index, fxp.param_index, input.value });
                            }
                            var fmt_buf: [256:0]u8 = undefined;
                            if (reaper.TrackFX_GetFormattedParamValue(media_track, fxp.fx_index, @intCast(fxp.param_index), &fmt_buf, fmt_buf.len)) {
                                globals.state.fx_ctrl.track_state.label_pool.setFmtValue(input.cc, std.mem.span(@as([*:0]const u8, &fmt_buf)));
                            }
                        } else if (input.cc == .Eq_hp_shape or input.cc == .Eq_lp_shape) {
                            // ReaEQ fallback: filter type is not a regular param, so it
                            // cannot appear in the forward map. Use SetNamedConfigParm instead.
                            var tmp: [512:0]u8 = undefined;
                            const eq_module = input.cc.toModule() orelse return;
                            switch (globals.state.fx_ctrl.track_state.mode) {
                                .multi_fx => |locs| {
                                    if (locs.get(eq_module)) |fxmap| {
                                        const hasName = reaper.TrackFX_GetNamedConfigParm(media_track, fxmap.fx_index, "original_name", &tmp, tmp.len);
                                        if (hasName and std.mem.eql(u8, std.mem.span(@as([*:0]const u8, &tmp)), "VST: ReaEQ (Cockos)")) {
                                            reaeq.cycleReaEqFilterType(media_track, fxmap.fx_index, input.cc);
                                            // Update the pool label with the new filter type name
                                            const band_key: [:0]const u8 = if (input.cc == .Eq_hp_shape) "BANDTYPE0" else "BANDTYPE3";
                                            var band_buf: [64:0]u8 = undefined;
                                            if (reaper.TrackFX_GetNamedConfigParm(media_track, fxmap.fx_index, band_key, &band_buf, band_buf.len)) {
                                                const band_str = std.mem.span(@as([*:0]const u8, &band_buf));
                                                const band_int = std.fmt.parseInt(c_int, band_str, 10) catch 0;
                                                const name = TrackState.bandTypeName(band_int);
                                                globals.state.fx_ctrl.track_state.label_pool.setPrmLabel(input.cc, name);
                                                globals.state.fx_ctrl.track_state.label_pool.setFmtValue(input.cc, name);
                                            }
                                        }
                                    }
                                },
                                .channel_strip => {},
                            }
                        }
                    }
                },
            }
        },
        .on_track_entry => |media_track| onTrackEntry(globals, media_track),
        .toggle_phase_inv => |media_track| {
            const phase = reaper.GetMediaTrackInfo_Value(media_track, "B_PHASE");
            const phase_val: f64 = if (phase == 0) 1 else 0;
            _ = pReaper.SetMediaTrackInfo_Value(.{ media_track, "B_PHASE", phase_val });
        },
        .fx_win_disp => |media_track| {
            globals.state.fx_ctrl.display = if (globals.state.fx_ctrl.display) |_| null else 1;
            handleFxWindowDisplay(globals, media_track);
        },
        .set_volume => |norm_val| {
            MidiEvts.setUIVal(.Out_Vol, norm_val, &globals.state.fx_ctrl);
        },
        .set_pan => |pan_val| {
            const norm_val = utils.panToNormalized(pan_val);
            MidiEvts.setUIVal(.Out_Pan, norm_val, &globals.state.fx_ctrl);
        },
        else => {},
        // ... other fx_ctrl actions
    }
}

/// Handles FX window visibility when switching tracks
/// Closes FX window of previous track and opens FX window of new track if display mode is active
fn handleFxWindowDisplay(globals: *Globals, media_track: MediaTrack) void {
    const count = reaper.GetNumTracks() + 1;
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const tr = reaper.CSurf_TrackFromID(i, false);
        pReaper.TrackFX_Show(.{ tr, -1, 0 }); // no valid index required for closing FX chain
    }
    if (globals.state.fx_ctrl.display) |_| {
        pReaper.TrackFX_Show(.{ media_track, 0, 1 });
    }
}

/// Main track selection handler for Console1
/// Validates track's FX chain, updates window display,
/// and synchronizes all controller feedback (LEDs, knobs) with track state
fn onTrackEntry(globals: *Globals, media_track: MediaTrack) void {
    log.debug("track entry", .{});
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);

    globals.state.fx_ctrl.validateTrack(
        null,
        media_track,
        null,
        globals.preferences.manual_routing,
        globals.preferences.default_fx,
        &globals.map_store,
        &globals.preferences,
        globals.arena,
        &globals.mappings_list,
    ) catch {
        log.err("track validation failed: track {d}", .{id});
    };

    // Update FX parameter values in the state
    updateFxParamValues(globals, media_track);

    handleFxWindowDisplay(globals, media_track);

    actions.dispatch(globals, .{ .midi_out = .{ .mode_entry = .fx_ctrl } });
}

/// Updates the FX control state with parameter values from the FX map
/// Called after track validation to ensure state reflects current FX parameters
fn updateFxParamValues(globals: *Globals, media_track: MediaTrack) void {
    // Iterate through all module parameters
    inline for (comptime std.enums.values(c1.CCs)) |cc| {
        // Skip non-parameter CCs
        switch (cc) {
            .Comp_Attack,
            .Comp_DryWet,
            .Comp_Ratio,
            .Comp_Release,
            .Comp_Thresh,
            .Comp_comp,
            .Eq_HiFrq,
            .Eq_HiGain,
            .Eq_HiMidFrq,
            .Eq_HiMidGain,
            .Eq_HiMidQ,
            .Eq_LoFrq,
            .Eq_LoGain,
            .Eq_LoMidFrq,
            .Eq_LoMidGain,
            .Eq_LoMidQ,
            .Eq_eq,
            .Eq_hp_shape,
            .Eq_lp_shape,
            .Inpt_Gain,
            .Inpt_HiCut,
            .Inpt_LoCut,
            .Out_Drive,
            .Out_DriveChar,
            .Out_Pan,
            .Out_Vol,
            .Shp_Gate,
            .Shp_GateRelease,
            .Shp_Punch,
            .Shp_hard_gate,
            .Shp_shape,
            .Shp_sustain,
            => {
                switch (globals.state.fx_ctrl.track_state.mode) {
                    .multi_fx => |locs| {
                        const module = comptime cc.toModule();
                        if (module) |mod| {
                            if (locs.get(mod)) |fxmap| {
                                const fx_idx = fxmap.fx_index;
                                if (fxmap.mapping) |map| {
                                    const param_idx = @field(@field(map, @tagName(mod)), @tagName(cc));
                                    if (param_idx) |param| {
                                        const val = reaper.TrackFX_GetParamNormalized(media_track, fx_idx, param);
                                        if (val >= 0) {
                                            if (globals.state.fx_ctrl.values.getPtr(cc)) |value_ptr| {
                                                switch (value_ptr.*) {
                                                    .param => |*param_value| param_value.normalized = val,
                                                    .button => |*button_val| button_val.* = val > 0.5,
                                                    else => {},
                                                }
                                            }
                                        } else {
                                            var buf: [512:0]u8 = undefined;
                                            const fx_name = if (reaper.TrackFX_GetNamedConfigParm(media_track, fx_idx, "original_name", &buf, buf.len))
                                                std.mem.span(@as([*:0]const u8, &buf))
                                            else
                                                "unknown";
                                            log.err("Failed to get parameter value: FX '{s}' at index {}, parameter '{s}' at index {}", .{
                                                fx_name, fx_idx, @tagName(cc), param,
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    },
                    .channel_strip => {
                        if (globals.state.fx_ctrl.track_state.forward_map.get(cc)) |fxp| {
                            const val = reaper.TrackFX_GetParamNormalized(media_track, fxp.fx_index, fxp.param_index);
                            if (val >= 0) {
                                if (globals.state.fx_ctrl.values.getPtr(cc)) |value_ptr| {
                                    switch (value_ptr.*) {
                                        .param => |*param_value| param_value.normalized = val,
                                        .button => |*button_val| button_val.* = val > 0.5,
                                        else => {},
                                    }
                                }
                            }
                        }
                    },
                }
            },
            else => {},
        }
    }
}

// Helper function to determine module from CC
// Similar to the one in midi_out.zig
