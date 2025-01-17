const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const SCRouting = fx_ctrl_state.SCRouting;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const globals = @import("globals.zig");
const onMidiEvent_FxCtrl = @import("csurf/midi_events_fxctrl.zig").onMidiEvent_FxCtrl;
const fx_sel_actions = @import("fx_sel_actions.zig");
const FxSelActions = fx_sel_actions.FxSelActions;
const Mode = statemachine.Mode;
const State = statemachine.State;
const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("../WDL/swell/swell-types.h");
    @cInclude("../WDL/swell/swell-functions.h");
    @cInclude("../WDL/win32_utf8.h");
    @cInclude("../WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});

pub const MidiInput = struct {
    cc: c1.CCs,
    value: u8,
};
pub const WidgetInput = struct {
    cc: c1.CCs,
    value: f64,
};

pub const FxCtrlAction = union(enum) {
    midi_input: MidiInput,
    panel_input: WidgetInput,
    set_volume: f64,
    set_pan: f64,
    toggle_mute,
    toggle_solo,
    set_routing_order: ModulesOrder,
    set_sidechain: SCRouting,
};

pub fn fxCtrlActions(state: *State, fx_action: FxCtrlAction) void {
    switch (fx_action) {
        .midi_input => |input| {
            logger.log(
                .debug,
                "MIDI input: {s} -> {d}",
                .{ @tagName(input.cc), input.value },
                .{ .midi_input = .{ .cc = input.cc, .value = input.value } },
                globals.allocator,
            );
            onMidiEvent_FxCtrl(input.cc, input.value);
        },
        .panel_input => |input| {
            // var prm =
            state.fx_ctrl.values.getPtr(input.cc).?.param.normalized = input.value;

            const right_midi: u8 = @intFromFloat(@min(input.value, 1.0) * 127);
            c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(input.cc), right_midi, -1);
        },
        else => {},
        // ... other fx_ctrl actions
    }
}
