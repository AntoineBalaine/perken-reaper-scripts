const std = @import("std");
const c1 = @import("c1.zig");
const constants = @import("constants.zig");
const reaper = @import("reaper").reaper;
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
const utils = @import("utils");
const reaeq = @import("reaeq.zig");
const TrackState = @import("track_state.zig");
const param_text = @import("param_text.zig");
const log = std.log.scoped(.midi_input);

pub const MidiInput = @import("action_types.zig").MidiInput;
pub const WidgetInput = @import("action_types.zig").WidgetInput;
pub const FxCtrlAction = @import("action_types.zig").FxCtrlAction;

pub fn fxCtrlActions(globals: *Globals, fx_action: FxCtrlAction) void {
    const io = Globals.hostIo();
    switch (fx_action) {
        .midi_input => |input| {
            log.debug(
                "MIDI input: {s} -> {d} evt: {}",
                .{ @tagName(input.cc), input.value, logger.Event{ .midi_input = .{ .cc = input.cc, .value = input.value } } },
            );
            onMidiEvent_FxCtrl(io, input.cc, input.value, globals);
        },
        .panel_input => |panel| {
            var input = panel;
            // A value that was typed is read as the plugin writes its values, and a text that is not one is dropped.
            if (panel.text) |text| {
                input.value = typedValue(globals, panel.cc, text) orelse return;
                input.text = null;
            }
            // Special handling for our three controls
            switch (input.cc) {
                // Because the controller opens the screen of the presets when the unit is in the sysex mode, the button of
                // the panel opens the same screen, and only the legacy unit has the mapping panel on this button.
                .Inpt_preset => if (globals.unit.isReady()) {
                    actions.dispatch(globals, .{ .presets = .{ .enter = .load } });
                } else {
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
                        const muted = reaper.CSurf_OnMuteChange(media_track, -1);
                        reaper.CSurf_SetSurfaceMute(media_track, muted, @ptrCast(csurf.my_csurf));
                        MidiEvts.setTrackToggle(globals, .Out_mute, muted);
                        // Send MIDI feedback
                        actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
                    }
                },
                .Out_solo => {
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        const soloed = reaper.CSurf_OnSoloChange(media_track, -1);
                        reaper.CSurf_SetSurfaceSolo(media_track, soloed, @ptrCast(csurf.my_csurf));
                        MidiEvts.setTrackToggle(globals, .Out_solo, soloed);
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
                    if (globals.state.fx_ctrl.track_state.mode == .channel_strip) {
                        handlePanelParamInput(globals, input);
                        return;
                    }
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        const routing: SCRouting = @fromBackingInt(@intCast(@as(u8, @intFromFloat(input.value))));
                        globals.state.fx_ctrl.routeSideChain(media_track, routing, globals.preferences.manual_routing);
                    }
                },
                .Tr_order => {
                    if (globals.state.fx_ctrl.track_state.mode == .channel_strip) {
                        handlePanelParamInput(globals, input);
                        return;
                    }
                    if (globals.state.current_tr_id) |tr_id| {
                        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
                        const order: ModulesOrder = @fromBackingInt(@intCast(@as(u8, @intFromFloat(input.value))));
                        globals.state.fx_ctrl.validateTrack(
                            order,
                            media_track,
                            null,
                            globals.preferences.manual_routing,
                            globals.preferences.default_fx,
                            &globals.map_store,
                            &globals.preferences,
                            globals.arena_int.allocator(),
                            io,
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
                else => handlePanelParamInput(globals, input),
            }
        },
        .on_track_entry => |media_track| onTrackEntry(globals, media_track),
        .toggle_phase_inv => |media_track| {
            const phase = reaper.GetMediaTrackInfo_Value(media_track, "B_PHASE");
            const phase_val: f64 = if (phase == 0) 1 else 0;
            _ = pReaper.SetMediaTrackInfo_Value(.{ media_track, "B_PHASE", phase_val });
            MidiEvts.setTrackToggle(globals, .Inpt_phase_inv, phase_val != 0);
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

/// Where the text of a parameter is asked for, for `param_text.solve`.
const TypedParam = struct { track: reaper.MediaTrack, fx: c_int, param: c_int };

fn formatNormalized(context: ?*anyopaque, normalized: f64, buf: *[64:0]u8) bool {
    const target: *const TypedParam = @ptrCast(@alignCast(context.?));
    return reaper.TrackFX_FormatParamValueNormalized(target.track, target.fx, target.param, normalized, @ptrCast(buf), buf.len);
}

/// The normalized value for the text that was typed on a knob: the value that the plugin writes with that number, or the
/// text itself as a normalized number when the plugin writes no numbers. It is null for a text that is neither.
fn typedValue(globals: *Globals, cc: c1.CCs, text: [24]u8) ?f64 {
    const typed = std.mem.sliceTo(&text, 0);
    if (globals.state.current_tr_id) |tr_id| {
        if (globals.state.fx_ctrl.track_state.forward_map.get(cc)) |fxp| {
            if (fxp.param_index != TrackState.FxParam.SYNTHETIC) {
                var target: TypedParam = .{
                    .track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode),
                    .fx = fxp.fx_index,
                    .param = @intCast(fxp.param_index),
                };
                if (param_text.solve(typed, .{ .context = &target, .format = formatNormalized })) |value| return value;
            }
        }
    }
    const parsed = std.fmt.parseFloat(f64, std.mem.trim(u8, typed, " \t")) catch return null;
    return std.math.clamp(parsed, 0.0, 1.0);
}

fn handlePanelParamInput(globals: *Globals, input: WidgetInput) void {
    // Read the current value before updating, because discrete
    // stepping needs to compare the old value to determine direction.
    const prev_norm = if (globals.state.fx_ctrl.values.getPtr(input.cc)) |vp| switch (vp.*) {
        .param => |p| p.normalized,
        else => 0.0,
    } else 0.0;

    // Update the stored value for continuous params. For discrete
    // params, the stepping logic below will set the correct value.
    if (globals.state.fx_ctrl.values.getPtr(input.cc)) |value_ptr| {
        switch (value_ptr.*) {
            .param => |*param_value| {
                param_value.normalized = input.value;
            },
            .button => |*button_value| {
                button_value.* = input.value > 0.5;
            },
            .track, .meter => {
                log.warn("Unexpected control type for CC {s}", .{@tagName(input.cc)});
            },
        }
    }

    // Send MIDI feedback regardless of the control type
    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
    if (globals.state.current_tr_id) |tr_id| {
        const media_track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
        if (globals.state.fx_ctrl.track_state.forward_map.get(input.cc)) |fxp| {
            if (fxp.param_index == TrackState.FxParam.SYNTHETIC) {
                // Synthetic entry (e.g. ReaEQ filter types via SetNamedConfigParm)
                reaeq.cycleReaEqFilterType(media_track, fxp.fx_index, input.cc);
                const band_key: [:0]const u8 = if (input.cc == .Eq_lp_shape) "BANDTYPE0" else "BANDTYPE3";
                var band_buf: [64:0]u8 = undefined;
                if (reaper.TrackFX_GetNamedConfigParm(media_track, fxp.fx_index, band_key, &band_buf, band_buf.len)) {
                    const band_str = std.mem.span(@as([*:0]const u8, &band_buf));
                    const band_int = std.fmt.parseInt(c_int, band_str, 10) catch 0;
                    const name = TrackState.bandTypeName(band_int);
                    globals.state.fx_ctrl.track_state.label_pool.setPrmLabel(input.cc, name);
                    globals.state.fx_ctrl.track_state.label_pool.setFmtValue(input.cc, name);
                }
                return;
            } else if (input.cc.isBtn()) {
                // Button CCs use cycling logic for discrete/toggle params
                const new_norm = TrackState.cycleDiscreteParam(media_track, fxp.fx_index, fxp.param_index, fxp.is_toggle);
                if (globals.state.fx_ctrl.values.getPtr(input.cc)) |vp| {
                    vp.param.normalized = new_norm;
                }
            } else {
                // For knob CCs, accumulate the normalized delta and step
                // when a boundary is crossed. Falls back to SetParamNormalized
                // for continuous params.
                const norm_delta = input.value - prev_norm;
                if (globals.state.fx_ctrl.track_state.stepDiscreteParam(input.cc, media_track, fxp.fx_index, fxp.param_index, norm_delta)) |new_norm| {
                    if (globals.state.fx_ctrl.values.getPtr(input.cc)) |vp| {
                        vp.param.normalized = new_norm;
                    }
                } else {
                    _ = pReaper.TrackFX_SetParamNormalized(.{ media_track, fxp.fx_index, fxp.param_index, input.value });
                }
            }

            var fmt_buf: [256:0]u8 = undefined;
            if (reaper.TrackFX_GetFormattedParamValue(media_track, fxp.fx_index, @intCast(fxp.param_index), &fmt_buf, fmt_buf.len)) {
                globals.state.fx_ctrl.track_state.label_pool.setFmtValue(input.cc, std.mem.span(@as([*:0]const u8, &fmt_buf)));
            }
        }
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

fn onTrackEntry(globals: *Globals, media_track: MediaTrack) void {
    const io = Globals.hostIo();
    log.debug("track entry", .{});
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);
    MidiEvts.readTrackToggles(globals, media_track);

    globals.state.fx_ctrl.validateTrack(
        null,
        media_track,
        null,
        globals.preferences.manual_routing,
        globals.preferences.default_fx,
        &globals.map_store,
        &globals.preferences,
        globals.arena_int.allocator(),
        io,
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
