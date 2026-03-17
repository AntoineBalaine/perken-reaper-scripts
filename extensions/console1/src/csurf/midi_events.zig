const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cDefine("WDL_ALLOW_UNSIGNED_DEFAULT_CHAR", "1");
    if (builtin.os.tag != .windows) {
        @cDefine("SWELL_PROVIDED_BY_APP", "");
    }
    @cInclude("csurf/control_surface_wrapper.h");
    if (builtin.os.tag == .windows) {
        @cInclude("windows.h");
    } else {
        @cInclude("WDL/swell/swell-types.h");
        @cInclude("WDL/swell/swell-functions.h");
    }
    @cInclude("WDL/win32_utf8.h");
    @cInclude("WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const c1 = @import("../c1.zig");
const Globals = @import("../globals.zig").Globals;
const actions = @import("../actions.zig");
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
    const cc_enum: ?c1.CCs = std.meta.intToEnum(c1.CCs, if (status == 0xb0) msg[1] else msg[0]) catch null;
    const val = if (status == 0xb0) msg[2] else msg[1];

    if (cc_enum) |cc| {
        mode_switch: switch (globals.state.current_mode) {
            .fx_ctrl => {
                switch (cc) {
                    .Inpt_preset => {
                        actions.dispatch(globals, .{ .change_mode = .mapping_panel });
                        actions.dispatch(globals, .{ .mapping_panel = .enter_browse });
                    },
                    else => actions.dispatch(globals, .{ .fx_ctrl = .{ .midi_input = .{ .cc = cc, .value = val } } }),
                }
            },
            .fx_sel => {
                switch (cc) {
                    .Out_Vol => actions.dispatch(globals, .{ .fx_sel = .{ .scroll = val } }),
                    .Out_solo => {
                        // Solo button for selection
                        const mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
                        const fx_offset = mappings.keys()[globals.state.fx_sel.scroll_position_rel];
                        const fx_name = globals.mappings_list.strings.get(fx_offset);
                        actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = fx_name, .mapping_name = null } } });
                    },
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
                    .Out_solo => {
                        // Solo button for selection
                        const def_fx_sel_state = globals.state.default_fx_sel;
                        const mappings = globals.mappings_list.list.get(def_fx_sel_state.current_category);
                        const fx_offset = mappings.keys()[def_fx_sel_state.scroll_position_rel];
                        const fx_name = globals.mappings_list.strings.get(fx_offset);
                        actions.dispatch(globals, .{ .default_fx_sel = .{ .plugin = .{ .name = fx_name, .mapping_name = null } } });
                    },
                    .Out_mute => actions.dispatch(globals, .{ .default_fx_sel = .close_browser }),
                    .Tr_tr1 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .INPUT } }),
                    .Tr_tr2 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .GATE } }),
                    .Tr_tr3 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .EQ } }),
                    .Tr_tr4 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .COMP } }),
                    .Tr_tr5 => actions.dispatch(globals, .{ .default_fx_sel = .{ .toggle_module_browser = .OUTPT } }),
                    else => {},
                }
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
                    .Tr_tr6 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .trim } }),
                    .Tr_tr7 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .read } }),
                    .Tr_tr8 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .latch } }),
                    .Tr_tr9 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .preview } }),
                    .Tr_tr10 => actions.dispatch(globals, .{ .transport = .{ .automation_mode = .write } }),
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
                        // Because MIDI learn should only capture CCs that belong
                        // to the module currently being assigned, we check both
                        // assignability and module membership before intercepting.
                        // All other CCs pass through to fx_ctrl.
                        const assign = &globals.state.mapping_panel.mode.assign;
                        const current_module = std.meta.activeTag(assign.current_mappings);
                        switch (assign.midi_learn) {
                            .listening_cc => {
                                // we only want to capture CCs belonging to the module being assigned
                                if (cc.isFxAssignable() and cc.toModule() == current_module) {
                                    actions.dispatch(globals, .{ .mapping_panel = .{ .assign_select_control = cc } });
                                } else {
                                    continue :mode_switch .fx_ctrl;
                                }
                            },
                            .listening_param => {
                                // When waiting for the user to touch a param,
                                // block CCs from the current module to prevent feedback
                                // CCs from other modules pass through normally.
                                if (cc.isFxAssignable() and cc.toModule() == current_module) {
                                    // Swallow: do not forward to fx_ctrl
                                } else {
                                    continue :mode_switch .fx_ctrl;
                                }
                            },
                            .idle => {
                                switch (cc) {
                                    .Out_mute => actions.dispatch(globals, .{ .mapping_panel = .assign_cancel }),
                                    .Out_Vol, .Out_solo => {},
                                    else => continue :mode_switch .fx_ctrl,
                                }
                            },
                        }
                    },
                    .save => {
                        switch (cc) {
                            .Out_solo => {
                                // Because we need to pass the current name for save confirmation, we extract it from the buffer
                                const save_state = globals.state.mapping_panel.mode.save;
                                const name = std.mem.span(@as([*:0]const u8, @ptrCast(&save_state.name_buffer)));
                                actions.dispatch(globals, .{ .mapping_panel = .{ .save_confirm = name } });
                            },
                            .Out_mute => actions.dispatch(globals, .{ .mapping_panel = .save_cancel }),
                            else => continue :mode_switch .fx_ctrl,
                        }
                    },
                }
            },
            else => {},
        }
    }
}
