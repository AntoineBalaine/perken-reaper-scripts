const std = @import("std");
const builtin = @import("builtin");
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
const c1 = @import("../c1.zig");
const Globals = @import("../globals.zig").Globals;
const actions = @import("../actions.zig");
const Unit = @import("../unit/unit.zig");
const MidiEvtsFxCtrl = @import("midi_events_fxctrl.zig");
const ModulesList = @import("../statemachine.zig").ModulesList;

pub fn OnMidiEvent(evt: *c.MIDI_event_t, globals: *Globals) void {
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
    const cc_enum: ?c1.CCs = std.enums.fromInt(c1.CCs, if (status == 0xb0) msg[1] else msg[0]);
    const val = if (status == 0xb0) msg[2] else msg[1];

    if (cc_enum) |cc| onControl(globals, cc, val);
}

/// An event of the unit in sysex mode. While nothing but the emulation of the legacy unit exists, a tick or a press ends in
/// the same call as a CC did.
pub fn onUnitEvent(globals: *Globals, event: Unit.ControlEvent) void {
    if (globals.state.current_mode == .fx_ctrl and globals.unit.shiftHeld()) {
        if (MidiEvtsFxCtrl.shiftFunction(globals, event)) return;
    }
    switch (event) {
        .tick => |tick| {
            if (globals.state.current_mode == .transport) {
                actions.dispatch(globals, .{ .transport = .{ .knob_by = .{ .cc = tick.cc, .delta = if (tick.delta > 0) 1 else -1, .fine = tick.fine } } });
                return;
            }
            if (tick.cc == .Out_Vol and scrollList(globals, if (tick.delta > 0) 1 else -1)) return;
            if (MidiEvtsFxCtrl.onTick(globals, tick)) return;
        },
        else => {},
    }
    if (globals.unit.input.legacyValue(event)) |legacy| onControl(globals, legacy.cc, legacy.value);
}

/// Volume scrolls the list of the browse modes by a row for each tick. It returns whether the mode has such a list.
fn scrollList(globals: *Globals, delta: i8) bool {
    switch (globals.state.current_mode) {
        .fx_sel => actions.dispatch(globals, .{ .fx_sel = .{ .scroll_by = delta } }),
        .default_fx_sel => actions.dispatch(globals, .{ .default_fx_sel = .{ .scroll_by = delta } }),
        .settings => actions.dispatch(globals, .{ .settings = .{ .scroll_by = delta } }),
        .presets => actions.dispatch(globals, .{ .presets = .{ .scroll_by = delta } }),
        .mapping_panel => switch (globals.state.mapping_panel.mode) {
            .browse => actions.dispatch(globals, .{ .mapping_panel = .{ .browse_scroll_by = delta } }),
            .assign => return false,
        },
        else => return false,
    }
    return true;
}

/// What the control `cc` does in the current mode, with the value that the legacy unit would have sent for it.
/// The legacy decoder above and the sysex unit both end here.
pub fn onControl(globals: *Globals, cc: c1.CCs, val: u8) void {
    mode_switch: switch (globals.state.current_mode) {
        .fx_ctrl => {
            switch (cc) {
                // The sysex unit has no mapping panel on this button: it loads a preset.
                .Inpt_preset => if (globals.unit.isReady()) {
                    actions.dispatch(globals, .{ .presets = .{ .enter = .load } });
                } else {
                    actions.dispatch(globals, .{ .change_mode = .mapping_panel });
                    actions.dispatch(globals, .{ .mapping_panel = .enter_browse });
                },
                else => actions.dispatch(globals, .{ .fx_ctrl = .{ .midi_input = .{ .cc = cc, .value = val } } }),
            }
        },
        .fx_sel => {
            switch (cc) {
                .Out_Vol => actions.dispatch(globals, .{ .fx_sel = .{ .scroll = val } }),
                .Out_solo => actions.dispatch(globals, .{ .fx_sel = .confirm }),
                .Out_mute => actions.dispatch(globals, .{ .fx_sel = .close_browser }),
                .Tr_tr1 => actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = .INPUT } }),
                .Tr_tr2 => actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = .GATE } }),
                .Tr_tr3 => actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = .EQ } }),
                .Tr_tr4 => actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = .COMP } }),
                .Tr_tr5 => actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } }),
                .Tr_tr20 => actions.dispatch(globals, .{ .settings = .open }),
                else => continue :mode_switch .fx_ctrl,
            }
        },
        .default_fx_sel => {
            switch (cc) {
                .Out_Vol => actions.dispatch(globals, .{ .default_fx_sel = .{ .scroll = val } }),
                .Out_solo => actions.dispatch(globals, .{ .default_fx_sel = .confirm }),
                .Out_mute => actions.dispatch(globals, .{ .default_fx_sel = .close_browser }),
                .Tr_tr1 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .INPUT } }),
                .Tr_tr2 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .GATE } }),
                .Tr_tr3 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .EQ } }),
                .Tr_tr4 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .COMP } }),
                .Tr_tr5 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .OUTPT } }),
                else => {},
            }
        },
        .presets => switch (cc) {
            .Out_Vol => actions.dispatch(globals, .{ .presets = .{ .scroll = val } }),
            .Out_solo => actions.dispatch(globals, .{ .presets = .confirm }),
            .Out_mute => actions.dispatch(globals, .{ .presets = .cancel }),
            else => {},
        },
        .settings => {
            switch (cc) {
                .Tr_tr20 => actions.dispatch(globals, .{ .settings = .save }),
                .Out_mute => actions.dispatch(globals, .{ .settings = .cancel }),
                .Out_solo => actions.dispatch(globals, .{ .settings = .toggle }),
                .Out_Vol => actions.dispatch(globals, .{ .settings = .{ .scroll = val } }),
                else => {},
            }
        },
        .transport => {
            switch (cc) {
                .Inpt_HiCut => actions.dispatch(globals, .{ .transport = .{ .rate = val } }),
                .Inpt_disp_mode => actions.dispatch(globals, .{ .change_mode = .fx_ctrl }),
                .Inpt_disp_on => {
                    if (globals.state.current_mode == .suspended) {
                        actions.dispatch(globals, .{ .change_mode = .fx_ctrl });
                    }
                    actions.dispatch(globals, .set_fx_ctrl_gui);
                },
                .Tr_tr1,
                .Tr_tr2,
                .Tr_tr3,
                .Tr_tr4,
                .Tr_tr5,
                => |cc_| {
                    const module: ModulesList = switch (cc_) {
                        .Tr_tr1 => .INPUT,
                        .Tr_tr2 => .GATE,
                        .Tr_tr3 => .EQ,
                        .Tr_tr4 => .COMP,
                        .Tr_tr5 => .OUTPT,
                        else => unreachable,
                    };
                    actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = module } });
                },
                .Tr_tr6 => actions.dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = .STRIP } }),
                .Tr_tr11 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .trim } }),
                .Tr_tr12 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .read } }),
                .Tr_tr13 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .latch } }),
                .Tr_tr14 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .preview } }),
                .Tr_tr15 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .write } }),
                .Tr_tr17 => actions.dispatch(globals, .{ .transport = .play }),
                .Tr_tr18 => actions.dispatch(globals, .{ .transport = .stop }),
                .Tr_tr19 => actions.dispatch(globals, .{ .transport = .rec }),
                .Tr_tr20 => actions.dispatch(globals, .{ .settings = .open }),
                .Eq_eq => actions.dispatch(globals, .{ .transport = .loop_toggle }),
                .Eq_lp_shape => actions.dispatch(globals, .{ .transport = .loop_start }),
                .Eq_hp_shape => actions.dispatch(globals, .{ .transport = .loop_end }),
                .Eq_LoGain => actions.dispatch(globals, .{ .transport = .{ .scrub = val } }),
                .Eq_LoMidGain => actions.dispatch(globals, .{ .transport = .{ .jog = val } }),
                .Eq_HiMidGain => actions.dispatch(globals, .{ .transport = .{ .jog_marker = val } }),
                .Eq_HiGain => actions.dispatch(globals, .{ .transport = .{ .jog_item = val } }),
                .Comp_comp => actions.dispatch(globals, .{ .transport = .marker_set }),
                .Out_Vol => actions.dispatch(globals, .{ .transport = .{ .tr_sel = val } }),
                .Out_Drive => actions.dispatch(globals, .{ .transport = .{ .zoom_horizontal = val } }),
                .Out_DriveChar => actions.dispatch(globals, .{ .transport = .{ .zoom_vertical = val } }),
                .Out_Pan => actions.dispatch(globals, .{ .transport = .{ .grid = val } }),
                .Out_solo => actions.dispatch(globals, .{ .transport = .snap_tgl }),
                else => {},
            }
        },
        .mapping_panel => {
            switch (globals.state.mapping_panel.mode) {
                .browse => {
                    switch (cc) {
                        .Out_Vol => actions.dispatch(globals, .{ .mapping_panel = .{ .browse_scroll = val } }),
                        .Out_solo => actions.dispatch(globals, .{ .mapping_panel = .browse_confirm }),
                        .Out_mute => actions.dispatch(globals, .{ .mapping_panel = .browse_cancel }),
                        else => continue :mode_switch .fx_ctrl,
                    }
                },
                .assign => {
                    const assign = &globals.state.mapping_panel.mode.assign;
                    const normalized: f32 = @floatFromInt(val);

                    if (cc.isFxAssignable()) {
                        actions.dispatch(globals, .{ .mapping_panel = .{ .assign_update_knob = .{ .cc = cc, .value = normalized / 127.0 } } });
                    }

                    if (assign.midi_learn_active) {
                        const current_module = std.meta.activeTag(assign.current_mappings);
                        const module_matches = if (current_module == .STRIP)
                            cc.isFxAssignable() or cc == .Tr_order or cc == .Tr_ext_sidechain
                        else if (cc.toModule()) |mod|
                            @backingInt(mod) == @backingInt(current_module)
                        else
                            false;
                        if (module_matches) {
                            actions.dispatch(globals, .{ .mapping_panel = .{ .assign_select_control = cc } });
                        }
                    } else {
                        switch (cc) {
                            .Out_mute => actions.dispatch(globals, .{ .mapping_panel = .assign_cancel }),
                            .Out_Vol, .Out_solo => {},
                            else => {},
                        }
                    }
                },
            }
        },
        else => {},
    }
}
