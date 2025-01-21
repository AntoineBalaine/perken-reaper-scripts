const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const globals = @import("globals.zig");
const constants = @import("constants.zig");
const log = std.log.scoped(.midi_output);
const utils = @import("utils.zig");
const Preferences = @import("settings.zig");
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
const SettingsValUpdate = @import("settings_panel.zig").SettingsValUpdate;
const TrackList = @import("fx_ctrl_state.zig").TrackList;

pub const MidiOutAction = union(enum) {
    /// Set initial feedback for mode
    /// also used when validating tracks
    mode_entry: Mode,
    clear_all, // Zero all feedback
    // fx_ctrl actions
    track_select: reaper.MediaTrack, // Update track selection feedback
    page_change,
    set_param: struct { cc: c1.CCs, value: u8 },
    blink,
    reset_meters,
    queryMeters,
    // settings
    settings_changed: SettingsValUpdate, // preference field name
};

pub fn sendMidiFeedback(action: MidiOutAction) void {
    if (globals.m_midi_out) |midi_out| {
        switch (action) {
            .mode_entry => |mode| onModeEntry(mode, midi_out),
            .clear_all => clearAllLEDs(midi_out),
            .track_select => handleTrackSelectFeedback(midi_out),
            .page_change => handlePageChangeFeedback(midi_out),
            .set_param => |param| setParamLED(param.cc, param.value, midi_out),
            .blink => blinkSelectedTrks(midi_out),
            .reset_meters => resetMeters(midi_out),
            .queryMeters => queryMeters(midi_out),
            .settings_changed => prefsEntry(midi_out),
        }
    }
}

/// Updates track selection feedback on Console1's track buttons.
/// Only turns on the LED for the last touched track if it's on the current page.
/// First clears all track button LEDs, then sets the appropriate LED.
///
/// This is distinct from handlePageChangeFeedback() which handles multiple selected tracks:
/// - handleTrackSelectFeedback: last touched track only
/// - handlePageChangeFeedback: all selected tracks plus last touched
///
/// Parameters:
///   midi_out: MIDI output handle for sending feedback
fn handleTrackSelectFeedback(midi_out: reaper.midi_Output) void {
    const page_start = globals.state.fx_ctrl.current_page * TrackList.PageSize;

    // Clear existing track selection LEDs
    inline for (comptime std.enums.values(c1.CCs)) |cc| {
        switch (cc) {
            .Tr_tr1, .Tr_tr2, .Tr_tr3, .Tr_tr4, .Tr_tr5, .Tr_tr6, .Tr_tr7, .Tr_tr8, .Tr_tr9, .Tr_tr10, .Tr_tr11, .Tr_tr12, .Tr_tr13, .Tr_tr14, .Tr_tr15, .Tr_tr16, .Tr_tr17, .Tr_tr18, .Tr_tr19, .Tr_tr20 => setButtonLED(cc, false, midi_out),
            else => {},
        }
    }

    // Set LED for last touched track if it's on current page
    const track_id = globals.state.last_touched_tr_id;
    if (track_id >= page_start and track_id < page_start + TrackList.PageSize) {
        const button_idx = track_id - page_start;
        const cc = @intFromEnum(c1.CCs.Tr_tr1) + @as(u8, @intCast(button_idx));
        setButtonLED(@enumFromInt(cc), true, midi_out);
    }
}

fn onModeEntry(mode: Mode, midi_out: reaper.midi_Output) void {
    switch (mode) {
        .fx_ctrl => fxCtrlEntry(midi_out),
        .fx_sel => fxSelEntry(midi_out),
        .mapping_panel => MappingsEntry(midi_out),
        .settings => prefsEntry(midi_out),
        .suspended => clearAllLEDs(midi_out),
        else => clearAllLEDs(midi_out),
        // etc.
    }
}

fn clearAllLEDs(midi_out: reaper.midi_Output) void {
    inline for (comptime std.enums.values(c1.CCs)) |f| {
        if (f == c1.CCs.Comp_Mtr or f == c1.CCs.Shp_Mtr) {
            c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(f), 0x7f, -1);
        } else {
            c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(f), 0x0, -1);
        }
    }
}

fn setButtonLED(cc: c1.CCs, is_on: bool, midi_out: reaper.midi_Output) void {
    const value: u8 = if (is_on) 0x7f else 0x0;
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(cc), value, -1);
}

// Add these to track feedback state
var blink_frame: u8 = 0;
var blink_state: bool = false;

// TODO: handleTrackSelectFeedback and handlePageChangeFeedback have overlapping functionality
// Could be consolidated or clearly differentiated
pub fn handlePageChangeFeedback(midi_out: reaper.midi_Output) void {

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
                c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(cc), 0x0, -1);
            },
            else => {},
        }
    }

    // Then set LEDs for selected tracks in current page
    const page_start = globals.state.fx_ctrl.current_page * 20;
    var it = globals.state.selectedTracks.iterator();
    while (it.next()) |entry| {
        const track_idx = entry.key_ptr.*;
        if (track_idx >= page_start and track_idx < page_start + 20) {
            const button_idx = track_idx - page_start;
            const cc = @intFromEnum(c1.CCs.Tr_tr1) + @as(u8, @intCast(button_idx));
            c.MidiOut_Send(midi_out, 0xb0, cc, 0x7f, -1);
        }
    }

    // Always light up last touched track if it's on this page
    const last_touched = globals.state.last_touched_tr_id;
    if (last_touched >= page_start and last_touched < page_start + 20) {
        const button_idx = last_touched - page_start;
        const cc = @intFromEnum(c1.CCs.Tr_tr1) + @as(u8, @intCast(button_idx));
        c.MidiOut_Send(midi_out, 0xb0, cc, 0x7f, -1);
    }
}

// Add these additional functions:
// FIXME: this is duplicate from the control surface
pub fn blinkSelectedTrks(midi_out: reaper.midi_Output) void {
    if (globals.state.current_mode != .fx_ctrl) return;

    blink_frame +%= 1;
    if (blink_frame == 30) {
        blink_frame = 0;
        blink_state = !blink_state;

        const page_start = globals.state.fx_ctrl.current_page * 20;
        var it = globals.state.selectedTracks.iterator();
        while (it.next()) |entry| {
            const track_idx = entry.key_ptr.*;
            // Skip last touched track
            if (track_idx == globals.state.last_touched_tr_id) continue;

            if (track_idx >= page_start and track_idx < page_start + 20) {
                const button_idx = track_idx - page_start;
                const cc = @intFromEnum(c1.CCs.Tr_tr1) + @as(u8, @intCast(button_idx));
                c.MidiOut_Send(midi_out, 0xb0, cc, if (blink_state) 0x7f else 0x0, -1);
            }
        }
    }
}

pub inline fn setParamLED(cc: c1.CCs, value: u8, midi_out: reaper.midi_Output) void {
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(cc), value, -1);
}

pub fn resetMeters(midi_out: reaper.midi_Output) void {
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrLft), 0x0, -1);
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(c1.CCs.Inpt_MtrRgt), 0x0, -1);
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(c1.CCs.Out_MtrLft), 0x0, -1);
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(c1.CCs.Out_MtrRgt), 0x0, -1);
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(c1.CCs.Comp_Mtr), 0x7f, -1);
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(c1.CCs.Shp_Mtr), 0x7f, -1);
}

test {
    std.testing.refAllDecls(@This());
}

fn fxCtrlEntry(midi_out: reaper.midi_Output) void {
    // First clear everything
    clearAllLEDs(midi_out);

    // If no track selected, we're done
    // if (globals.state.last_touched_tr_id == null) return;

    // 1. Set track selection LEDs
    handleTrackSelectFeedback(midi_out);

    // 2. Set track controls (vol, pan, mute, solo, phase inv.)
    sendTrkCtrlFdb(midi_out);

    // 3. Set module order LED
    setParamLED(c1.CCs.Tr_order, @intFromEnum(globals.state.fx_ctrl.order), midi_out);

    // 4. Set all module parameters based on mappings
    updateAllModuleParams(midi_out);
}

/// Set track controls’ LEDs (vol, pan, mute, solo, phase inv.)
/// Queries reaper ap
pub fn sendTrkCtrlFdb(midi_out: reaper.midi_Output) void {
    const track = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
    // Preserve volume/pan/mute/solo state
    const volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL");
    const pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN");
    const mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") > 0.5;
    const solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0.5;
    const phase = reaper.GetMediaTrackInfo_Value(track, "B_PHASE") > 0.5;

    setParamLED(c1.CCs.Out_Vol, @as(u8, @intFromFloat(volume * 127)), midi_out);
    setParamLED(c1.CCs.Out_Pan, @as(u8, @intFromFloat((pan + 1.0) * 63.5)), midi_out);
    setParamLED(c1.CCs.Out_mute, if (mute) 0x7f else 0, midi_out);
    setParamLED(c1.CCs.Out_solo, if (solo) 0x7f else 0, midi_out);
    setParamLED(c1.CCs.Inpt_phase_inv, if (phase) 0x7f else 0, midi_out);
}
fn fxSelEntry(midi_out: reaper.midi_Output) void {
    // Clear everything first
    clearAllLEDs(midi_out);
}

fn MappingsEntry(midi_out: reaper.midi_Output) void {
    // Clear everything first
    clearAllLEDs(midi_out);

    // Light up module selection button
    const module_btn = switch (globals.state.mapping.current_mappings) {
        .INPUT => c1.CCs.Tr_tr1,
        .GATE => c1.CCs.Tr_tr2,
        .EQ => c1.CCs.Tr_tr3,
        .COMP => c1.CCs.Tr_tr4,
        .OUTPT => c1.CCs.Tr_tr5,
    };
    setButtonLED(module_btn, true, midi_out);
}

/// Updates Console1's module parameters based on FX mapping
fn updateAllModuleParams(midi_out: reaper.midi_Output) void {
    const track = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, false);

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
                // Determine module and get mapping
                const module = comptime getModuleForCC(cc);
                if (module) |mod| {
                    const fx_map = @field(globals.state.fx_ctrl.fxMap, @tagName(mod));
                    if (fx_map) |fxmap| {
                        const fx_idx = fxmap[0];
                        const mapping = fxmap[1];
                        if (mapping) |map| {
                            // Get parameter index from mpng
                            const param_idx = @field(map, @tagName(cc));
                            const val = reaper.TrackFX_GetParamNormalized(
                                track,
                                globals.state.fx_ctrl.getSubContainerIdx(fx_idx + 1, reaper.TrackFX_GetByName(track, constants.CONTROLLER_NAME, false) + 1, track),
                                param_idx,
                            );
                            const conv: u8 = @intFromFloat(val * 127);
                            setParamLED(cc, conv, midi_out);
                        }
                    }
                }
            },
            else => {},
        }
    }
}

// Helper function to determine module from CC
// TODO: we should probably hard code these.
fn getModuleForCC(comptime cc: c1.CCs) ?statemachine.ModulesList {
    const cc_name = @tagName(cc);
    return if (std.mem.startsWith(u8, cc_name, "Comp"))
        .COMP
    else if (std.mem.startsWith(u8, cc_name, "Eq"))
        .EQ
    else if (std.mem.startsWith(u8, cc_name, "Inpt"))
        .INPUT
    else if (std.mem.startsWith(u8, cc_name, "Out"))
        .OUTPT
    else if (std.mem.startsWith(u8, cc_name, "Shp"))
        .GATE
    else
        null;
}

fn queryMeters(midiOut: reaper.midi_Output) void {
    var tmp: [512:0]u8 = undefined;
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
                reaper.TrackFX_GetByName(mediaTrack, constants.CONTROLLER_NAME, false) + 1, // make it 1-based
                mediaTrack),
            "GainReduction_dB",
            tmp[0..],
            tmp.len,
        );
        if (!success) {
            log.err("failed to get gain reduction", .{});
        } else {
            const slice = std.mem.sliceTo(&tmp, 0);
            const gainReduction = std.fmt.parseFloat(f64, slice) catch null;

            if (gainReduction) |GR| {
                // not quite 1:1 with the console's meter, but good enough for jazz
                const conv: u8 = @intFromFloat(utils.DB2VAL(GR) * 127);
                c.MidiOut_Send(midiOut, 0xb0, @intFromEnum(c1.CCs.Comp_Mtr), conv, -1);
            } else {
                log.err("failed to parse gain reduction", .{});
            }
        }
    }
}

// Define the preference button mappings at module level
const PreferenceButton = struct {
    preference: []const u8,
    button: c1.CCs,
};

// Then the function could be written as:
fn prefsEntry(midi_out: reaper.midi_Output) void {
    clearAllLEDs(midi_out);
    const preferences = globals.preferences;
    setButtonLED(c1.CCs.Tr_tr6, preferences.show_startup_message, midi_out);
    setButtonLED(c1.CCs.Tr_tr7, preferences.show_feedback_window, midi_out);
    setButtonLED(c1.CCs.Tr_tr8, preferences.show_plugin_ui, midi_out);
    setButtonLED(c1.CCs.Tr_tr9, preferences.manual_routing, midi_out);
    setButtonLED(c1.CCs.Tr_tr10, preferences.log_to_file, midi_out);
    setButtonLED(c1.CCs.Tr_tr11, preferences.start_suspended, midi_out);
    setButtonLED(c1.CCs.Tr_tr12, preferences.show_track_list, midi_out);
    setButtonLED(c1.CCs.Tr_tr13, preferences.focus_page_tracks, midi_out);

    // Settings mode indicator
    setButtonLED(c1.CCs.Tr_tr20, true, midi_out);
}

fn settingsChanged(update: SettingsValUpdate, midi_out: reaper.midi_Output) void {
    if (std.mem.eql(u8, "show_startup_message", update.field)) {
        setButtonLED(c1.CCs.Tr_tr6, update.val, midi_out);
    } else if (std.mem.eql(u8, "show_feedback_window", update.field)) {
        setButtonLED(c1.CCs.Tr_tr7, update.val, midi_out);
    } else if (std.mem.eql(u8, "show_plugin_ui", update.field)) {
        setButtonLED(c1.CCs.Tr_tr8, update.val, midi_out);
    } else if (std.mem.eql(u8, "manual_routing", update.field)) {
        setButtonLED(c1.CCs.Tr_tr9, update.val, midi_out);
    } else if (std.mem.eql(u8, "log_to_file", update.field)) {
        setButtonLED(c1.CCs.Tr_tr10, update.val, midi_out);
    } else if (std.mem.eql(u8, "start_suspended", update.field)) {
        setButtonLED(c1.CCs.Tr_tr11, update.val, midi_out);
    } else if (std.mem.eql(u8, "show_track_list", update.field)) {
        setButtonLED(c1.CCs.Tr_tr12, update.val, midi_out);
    } else if (std.mem.eql(u8, "focus_page_tracks", update.field)) {
        setButtonLED(c1.CCs.Tr_tr13, update.val, midi_out);
    }
}
