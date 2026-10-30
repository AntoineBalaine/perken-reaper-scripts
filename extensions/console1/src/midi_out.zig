const std = @import("std");
const reaper = @import("reaper").reaper;
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const Globals = @import("globals.zig").Globals;
const constants = @import("constants.zig");
const log = std.log.scoped(.midi_output);
const utils = @import("utils");
const builtin = @import("builtin");
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const Unit = @import("unit/unit.zig");
const SettingsValUpdate = @import("action_types.zig").SettingsValUpdate;
pub const MidiOutAction = @import("action_types.zig").MidiOutAction;

pub fn sendMidiFeedback(globals: *Globals, action: MidiOutAction) void {
    log.debug("send midi feedback: {s}", .{@tagName(action)});
    if (globals.m_midi_out) |midi_out| {
        const unit = &globals.unit;
        // Because the unit sends through the output that the control surface opened, tests that set only the
        // output get the legacy CCs without starting a handshake.
        if (unit.sender == null) unit.sender = .reaper(midi_out);
        switch (action) {
            .mode_entry => |mode| onModeEntry(globals, mode, unit),
            .clear_all => clearAllLEDs(unit),
            .track_select => updateTrackListLEDs(globals, unit),
            .page_change => updateTrackListLEDs(globals, unit),
            .set_param => |param| setParamLED(param.cc, param.value, unit),
            .blink => blinkSelectedTrks(globals, unit),
            .reset_meters => resetMeters(unit),
            .queryMeters => queryMeters(globals, unit),
            .settings_changed => prefsEntry(globals, unit),
        }
    } else {
        const config = @import("config");
        const is_test = @hasDecl(config, "test") and @field(config, "test");
        if (!is_test) {
            log.err("no midi feedback available", .{});
        }
    }
}

fn onModeEntry(globals: *Globals, mode: Mode, unit: *Unit) void {
    log.debug("on mode entry: {s}", .{@tagName(mode)});
    switch (mode) {
        .fx_ctrl => fxCtrlEntry(globals, unit),
        .fx_sel => fxSelEntry(unit),
        .mapping_panel => MappingsEntry(globals, unit),
        .settings => prefsEntry(globals, unit),
        .suspended => clearAllLEDs(unit),
        .transport => transportEntry(unit),
        else => clearAllLEDs(unit),
        // etc.
    }
}

fn transportEntry(unit: *Unit) void {
    clearAllLEDs(unit);
    setParamLED(c1.CCs.Inpt_disp_mode, 0x7f, unit);
}

fn clearAllLEDs(unit: *Unit) void {
    unit.clearAll();
}

fn setButtonLED(cc: c1.CCs, is_on: bool, unit: *Unit) void {
    const value: u8 = if (is_on) 0x7f else 0x0;
    unit.setLed(cc, value);
}

// Add these to track feedback state
var blink_frame: u8 = 0;
var blink_state: bool = false;

// TODO: handleTrackSelectFeedback and handlePageChangeFeedback have overlapping functionality
// Could be consolidated or clearly differentiated
pub fn updateTrackListLEDs(globals: *Globals, unit: *Unit) void {
    // First clear all track button LEDs
    inline for (comptime std.enums.values(c1.CCs)) |cc| {
        switch (cc) {
            .Tr_tr1,
            .Tr_tr2,
            .Tr_tr3,
            .Tr_tr4,
            .Tr_tr5,
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
            .Tr_tr20,
            .Tr_pg_dn,
            .Tr_pg_up,
            => {
                unit.setLed(cc, 0x0);
            },
            else => {},
        }
    }

    // Then set LEDs for selected tracks in current page
    const page_start = globals.state.fx_ctrl.current_page * 20;
    var it = globals.state.selectedTracks.iterator();
    while (it.next()) |entry| {
        const track_id = entry.key_ptr.*;
        if (track_id >= page_start and track_id < page_start + 20) {
            const button_idx = track_id - page_start;
            const cc = @backingInt(c1.CCs.Tr_tr1) + @as(u8, @intCast(button_idx));
            unit.setLed(@fromBackingInt(@intCast(cc)), 0x7f);
        }
    }
}

// Add these additional functions:
// FIXME: this is duplicate from the control surface
pub fn blinkSelectedTrks(globals: *Globals, unit: *Unit) void {
    if (globals.state.current_mode != .fx_ctrl) return;

    blink_frame +%= 1;
    if (blink_frame == 30) {
        blink_frame = 0;
        blink_state = !blink_state;

        const page_start = globals.state.fx_ctrl.current_page * 20;
        var it = globals.state.selectedTracks.iterator();
        while (it.next()) |entry| {
            const track_idx = entry.key_ptr.*;

            if (track_idx >= page_start and track_idx < page_start + 20) {
                const button_idx = track_idx - page_start;
                const cc = @backingInt(c1.CCs.Tr_tr1) + @as(u8, @intCast(button_idx));
                unit.setLed(@fromBackingInt(@intCast(cc)), if (blink_state) 0x7f else 0x0);
            }
        }
    }
}

pub inline fn setParamLED(cc: c1.CCs, value: u8, unit: *Unit) void {
    unit.setLed(cc, value);
}

pub fn resetMeters(unit: *Unit) void {
    unit.setLed(c1.CCs.Inpt_MtrLft, 0x0);
    unit.setLed(c1.CCs.Inpt_MtrRgt, 0x0);
    unit.setLed(c1.CCs.Out_MtrLft, 0x0);
    unit.setLed(c1.CCs.Out_MtrRgt, 0x0);
    unit.setLed(c1.CCs.Comp_Mtr, 0x7f);
    unit.setLed(c1.CCs.Shp_Mtr, 0x7f);
}

test {
    std.testing.refAllDecls(@This());
}

fn fxCtrlEntry(globals: *Globals, unit: *Unit) void {
    clearAllLEDs(unit);
    updateTrackListLEDs(globals, unit);

    if (globals.state.current_tr_id) |tr_id| {
        const track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
        sendTrkCtrlFdb(unit, track);
        setParamLED(c1.CCs.Tr_order, @backingInt(globals.state.fx_ctrl.track_state.getModulesOrder()), unit);
        updateAllModuleParams(globals, unit, track);
    }

    setParamLED(c1.CCs.Inpt_filt_to_comp, if (globals.state.fx_ctrl.filter_to_comp) 0x7f else 0x00, unit);
}
/// Set track controls' LEDs (vol, pan, mute, solo, phase inv.)
/// Queries reaper ap
fn sendTrkCtrlFdb(unit: *Unit, track: reaper.MediaTrack) void {
    // Preserve volume/pan/mute/solo state
    const volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL");
    const pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN");
    const mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0.5;
    const solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0.5;
    const phase = reaper.GetMediaTrackInfo_Value(track, "B_PHASE") > 0.5;

    setParamLED(c1.CCs.Out_Vol, @as(u8, @intFromFloat(std.math.clamp(volume * 127, 0, 127))), unit);
    setParamLED(c1.CCs.Out_Pan, @as(u8, @intFromFloat(std.math.clamp((pan + 1.0) * 63.5, 0, 127))), unit);
    setParamLED(c1.CCs.Out_mute, if (mute) 0x7f else 0, unit);
    setParamLED(c1.CCs.Out_solo, if (solo) 0x7f else 0, unit);
    setParamLED(c1.CCs.Inpt_phase_inv, if (phase) 0x7f else 0, unit);
}
fn fxSelEntry(unit: *Unit) void {
    // Clear everything first
    clearAllLEDs(unit);
    setParamLED(c1.CCs.Inpt_disp_mode, 0x7f, unit);
}
fn MappingsEntry(globals: *Globals, unit: *Unit) void {
    // Clear everything first
    clearAllLEDs(unit);

    // Light up module selection button
    const current_mappings = switch (globals.state.mapping_panel.mode) {
        .assign => |state| state.current_mappings,
        else => return,
    };
    const module_btn = switch (current_mappings) {
        .INPUT => c1.CCs.Tr_tr1,
        .GATE => c1.CCs.Tr_tr2,
        .EQ => c1.CCs.Tr_tr3,
        .COMP => c1.CCs.Tr_tr4,
        .OUTPT => c1.CCs.Tr_tr5,
        .STRIP => c1.CCs.Tr_tr6,
    };
    setButtonLED(module_btn, true, unit);
}

/// Updates Console1's module parameters based on FX mapping
fn updateAllModuleParams(globals: *Globals, unit: *Unit, track: reaper.MediaTrack) void {

    // Module Parameters
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
                                if (fxmap.mapping) |map| {
                                    const param_idx = @field(@field(map, @tagName(mod)), @tagName(cc));
                                    if (param_idx) |param| {
                                        const val = reaper.TrackFX_GetParamNormalized(track, fxmap.fx_index, param);
                                        if (val < 0) {
                                            var buf: [512:0]u8 = undefined;
                                            const fx_name = if (reaper.TrackFX_GetNamedConfigParm(track, fxmap.fx_index, "original_name", &buf, buf.len))
                                                std.mem.span(@as([*:0]const u8, &buf))
                                            else
                                                "unknown";
                                            log.err("Failed to get parameter value: FX '{s}' at index {}, parameter '{s}' at index {}", .{
                                                fx_name, fxmap.fx_index, @tagName(cc), param,
                                            });
                                        } else {
                                            const conv: u8 = @intFromFloat(val * 127);
                                            setParamLED(cc, conv, unit);
                                        }
                                    }
                                }
                            }
                        }
                    },
                    .channel_strip => {
                        if (globals.state.fx_ctrl.track_state.forward_map.get(cc)) |fxp| {
                            const val = reaper.TrackFX_GetParamNormalized(track, fxp.fx_index, fxp.param_index);
                            if (val >= 0) {
                                const conv: u8 = @intFromFloat(val * 127);
                                setParamLED(cc, conv, unit);
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
// TODO: we should probably hard code these.

fn queryMeters(globals: *Globals, unit: *Unit) void {
    if (globals.state.current_tr_id == null) return;
    var tmp: [512:0]u8 = undefined;
    const mediaTrack = reaper.CSurf_TrackFromID(globals.state.current_tr_id.?, constants.g_csurf_mcpmode);
    const left = reaper.Track_GetPeakInfo(mediaTrack, 0);
    const right = reaper.Track_GetPeakInfo(mediaTrack, 1);
    const left_midi: u8 = if (left > 1.0) 127 else @intFromFloat(left * 127);
    const right_midi: u8 = if (right > 1.0) 127 else @intFromFloat(right * 127);
    unit.setLed(c1.CCs.Out_MtrLft, left_midi);
    unit.setLed(c1.CCs.Out_MtrRgt, right_midi);
    const meter_fx_index: ?c_int = switch (globals.state.fx_ctrl.track_state.mode) {
        .multi_fx => |locs| if (locs.get(.COMP)) |comp| comp.fx_index else null,
        .channel_strip => |strip| strip.fx_index,
    };
    if (meter_fx_index) |fx_idx| {
        const success = reaper.TrackFX_GetNamedConfigParm(mediaTrack, fx_idx, "GainReduction_dB", tmp[0..], tmp.len);
        if (!success) {
            log.err("failed to get gain reduction", .{});
        } else {
            const slice = std.mem.sliceTo(&tmp, 0);
            const gainReduction = std.fmt.parseFloat(f64, slice) catch null;

            if (gainReduction) |GR| {
                // not quite 1:1 with the console's meter, but good enough for jazz
                const conv: u8 = @intFromFloat(utils.DB2VAL(GR) * 127);
                unit.setLed(c1.CCs.Comp_Mtr, conv);
            } else {
                log.err("failed to parse gain reduction", .{});
            }
        }
    }
}

// Then the function could be written as:
fn prefsEntry(globals: *Globals, unit: *Unit) void {
    if (globals.settings_panel) |settings_panel| {
        const temp_settings = settings_panel.temp_settings;
        clearAllLEDs(unit);
        setButtonLED(c1.CCs.Tr_tr6, temp_settings.show_startup_message, unit);
        setButtonLED(c1.CCs.Tr_tr7, temp_settings.show_feedback_window, unit);
        setButtonLED(c1.CCs.Tr_tr8, temp_settings.show_plugin_ui, unit);
        setButtonLED(c1.CCs.Tr_tr9, temp_settings.manual_routing, unit);
        setButtonLED(c1.CCs.Tr_tr10, temp_settings.log_to_file, unit);
        setButtonLED(c1.CCs.Tr_tr11, temp_settings.start_suspended, unit);
        setButtonLED(c1.CCs.Tr_tr12, temp_settings.show_track_list, unit);
        setButtonLED(c1.CCs.Tr_tr13, temp_settings.focus_page_tracks, unit);

        // Settings mode indicator
        setButtonLED(c1.CCs.Tr_tr20, true, unit);
    }
}

fn settingsChanged(update: SettingsValUpdate, unit: *Unit) void {
    switch (update) {
        .bool_val => |bool_update| {
            if (std.mem.eql(u8, "show_startup_message", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr6, bool_update.val, unit);
            } else if (std.mem.eql(u8, "show_feedback_window", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr7, bool_update.val, unit);
            } else if (std.mem.eql(u8, "show_plugin_ui", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr8, bool_update.val, unit);
            } else if (std.mem.eql(u8, "manual_routing", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr9, bool_update.val, unit);
            } else if (std.mem.eql(u8, "log_to_file", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr10, bool_update.val, unit);
            } else if (std.mem.eql(u8, "start_suspended", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr11, bool_update.val, unit);
            } else if (std.mem.eql(u8, "show_track_list", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr12, bool_update.val, unit);
            } else if (std.mem.eql(u8, "focus_page_tracks", bool_update.field)) {
                setButtonLED(c1.CCs.Tr_tr13, bool_update.val, unit);
            }
        },
        .string_val => |string_update| {
            // Handle string updates (like language)
            // No LED feedback needed for language changes
            _ = string_update;
        },
    }
}
