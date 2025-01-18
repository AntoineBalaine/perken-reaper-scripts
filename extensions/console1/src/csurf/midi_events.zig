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
const globals = @import("../globals.zig");
const actions = @import("../actions.zig");

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
    const cc_enum = std.meta.intToEnum(c1.CCs, if (status == 0xb0) msg[1] else msg[0]) catch null;
    const val = if (status == 0xb0) msg[2] else msg[1];

    if (cc_enum) |cc| {
        switch (globals.state.current_mode) {
            .fx_ctrl => {
                actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .midi_input = .{ .cc = cc, .value = val } } });
            },
            .fx_sel => {
                switch (cc) {
                    .Out_Vol => {
                        // Volume knob for scrolling
                        actions.dispatch(&globals.state, .{ .fx_sel = .{ .scroll = val } });
                    },
                    .Out_solo => {
                        // Solo button for selection
                        // if (val > 0) { // On button press
                        //     const mappings = globals.map_store.getMappingsForModule(globals.state.fx_sel.current_category);
                        //     if (mappings) |m| {
                        //         var iterator = m.iterator();
                        //         var i: usize = 0;
                        //         while (iterator.next()) |entry| : (i += 1) {
                        //             if (i == globals.state.fx_sel.scroll_position) {
                        //                 actions.dispatch(&globals.state, .{ .fx_sel = .{ .select_mapped_fx = .{
                        //                     .fx_name = entry.key_ptr.*,
                        //                     .module = globals.state.fx_sel.current_category,
                        //                 } } });
                        //                 break;
                        //             }
                        //         }
                        //     }
                        // }
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
            .settings => {
                switch (cc) {
                    .Out_solo => actions.dispatch(&globals.state, .{ .settings = .save }),
                    .Out_mute, .Tr_tr20 => actions.dispatch(&globals.state, .{ .settings = .cancel }),
                    else => {},
                }
            },
            else => {},
        }
    }
}
