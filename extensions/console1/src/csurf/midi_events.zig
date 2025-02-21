const std = @import("std");
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
const c1 = @import("../c1.zig");
const globals = @import("../console1_extension.zig").globals;
const actions = @import("../actions.zig");
const ModulesList = @import("../statemachine.zig").ModulesList;

pub fn OnMidiEvent(evt: *c.MIDI_event_t) void {
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
        switch (globals.state.current_mode) {
            .fx_ctrl => {
                actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .midi_input = .{ .cc = cc, .value = val } } });
            },
            .fx_sel => {
                switch (cc) {
                    .Out_Vol => actions.dispatch(&globals.state, .{ .fx_sel = .{ .scroll = val } }),
                    .Out_solo => {
                        // Solo button for selection
                        const mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
                        const fx_name = mappings.unmanaged.keys()[globals.state.fx_sel.scroll_position_rel];
                        actions.dispatch(&globals.state, .{ .fx_sel = .{ .plugin = .{ .name = @ptrCast(fx_name) } } });
                    },
                    .Out_mute => actions.dispatch(&globals.state, .{ .fx_sel = .close_browser }),
                    .Tr_tr1 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .INPUT } }),
                    .Tr_tr2 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .GATE } }),
                    .Tr_tr3 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .EQ } }),
                    .Tr_tr4 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .COMP } }),
                    .Tr_tr5 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } }),
                    .Tr_tr20 => actions.dispatch(&globals.state, .{ .settings = .open }),
                    else => {},
                }
            },
            .default_fx_sel => {
                switch (cc) {
                    .Out_Vol => actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .scroll = val } }),
                    .Out_solo => {
                        // Solo button for selection
                        const def_fx_sel_state = globals.state.default_fx_sel;
                        const mappings = globals.mappings_list.list.get(def_fx_sel_state.current_category);
                        const fx_name = mappings.unmanaged.keys()[def_fx_sel_state.scroll_position_rel];
                        actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .plugin = .{ .name = @ptrCast(fx_name) } } });
                    },
                    .Out_mute => actions.dispatch(&globals.state, .{ .default_fx_sel = .close_browser }),
                    .Tr_tr1 => actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .toggle_module_browser = .INPUT } }),
                    .Tr_tr2 => actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .toggle_module_browser = .GATE } }),
                    .Tr_tr3 => actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .toggle_module_browser = .EQ } }),
                    .Tr_tr4 => actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .toggle_module_browser = .COMP } }),
                    .Tr_tr5 => actions.dispatch(&globals.state, .{ .default_fx_sel = .{ .toggle_module_browser = .OUTPT } }),
                    else => {},
                }
            },
            .settings => {
                switch (cc) {
                    .Tr_tr20 => actions.dispatch(&globals.state, .{ .settings = .save }),
                    .Out_mute => actions.dispatch(&globals.state, .{ .settings = .cancel }),
                    .Out_solo => actions.dispatch(&globals.state, .{ .settings = .toggle }),
                    .Out_Vol => actions.dispatch(&globals.state, .{ .settings = .{ .scroll = val } }),
                    else => {},
                }
            },
            .transport => {
                switch (cc) {
                    .Inpt_HiCut => actions.dispatch(&globals.state, .{ .transport = .{ .rate = val } }),
                    .Inpt_disp_mode => actions.dispatch(&globals.state, .{ .change_mode = .fx_ctrl }),
                    .Inpt_disp_on => actions.dispatch(&globals.state, .set_fx_ctrl_gui),
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
                        actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = module } });
                    },
                    .Tr_tr6 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .trim } }),
                    .Tr_tr7 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .read } }),
                    .Tr_tr8 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .latch } }),
                    .Tr_tr9 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .preview } }),
                    .Tr_tr10 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .write } }),
                    .Tr_tr17 => actions.dispatch(&globals.state, .{ .transport = .play }),
                    .Tr_tr18 => actions.dispatch(&globals.state, .{ .transport = .stop }),
                    .Tr_tr19 => actions.dispatch(&globals.state, .{ .transport = .rec }),
                    .Tr_tr20 => actions.dispatch(&globals.state, .{ .settings = .open }),
                    .Eq_eq => actions.dispatch(&globals.state, .{ .transport = .loop_toggle }),
                    .Eq_lp_shape => actions.dispatch(&globals.state, .{ .transport = .loop_start }),
                    .Eq_hp_shape => actions.dispatch(&globals.state, .{ .transport = .loop_end }),
                    .Eq_LoGain => actions.dispatch(&globals.state, .{ .transport = .{ .scrub = val } }),
                    .Eq_LoMidGain => actions.dispatch(&globals.state, .{ .transport = .{ .jog = val } }),
                    .Eq_HiMidGain => actions.dispatch(&globals.state, .{ .transport = .{ .jog_marker = val } }),
                    .Eq_HiGain => actions.dispatch(&globals.state, .{ .transport = .{ .jog_item = val } }),
                    .Comp_comp => actions.dispatch(&globals.state, .{ .transport = .marker_set }),
                    .Out_Vol => actions.dispatch(&globals.state, .{ .transport = .{ .tr_sel = val } }),
                    .Out_Drive => actions.dispatch(&globals.state, .{ .transport = .{ .zoom_horizontal = val } }),
                    .Out_DriveChar => actions.dispatch(&globals.state, .{ .transport = .{ .zoom_vertical = val } }),
                    .Out_Pan => actions.dispatch(&globals.state, .{ .transport = .{ .grid = val } }),
                    .Out_solo => actions.dispatch(&globals.state, .{ .transport = .snap_tgl }),
                    else => {},
                }
            },
            else => {},
        }
    }
}
