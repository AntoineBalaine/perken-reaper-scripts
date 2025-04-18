const std = @import("std");
const rapidcheck = @cImport({
    @cInclude("rapidcheck_wrapper.h");
});
const models = @import("../../models/models.zig");
const statemachine = @import("../../statemachine.zig");
const actions = @import("../../actions.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const ModeAction = actions.ModeAction;
const Globals = models.Globals.initMinimalGlobals;

// Model for generating random state transitions
pub const ModeTransition = struct {
    from: Mode,
    to: Mode,

    pub fn generate(ctx: *rapidcheck.RC_TestContext) ModeTransition {
        // Get the set of all modes
        const modes = std.enums.values(Mode);

        // Generate a random 'from' mode
        const from_idx = rapidcheck.rc_generate_int(ctx, 0, modes.len - 1);
        const from = modes[from_idx];

        // Get valid transitions for 'from'
        const valid = statemachine.valid_transitions.get(from) orelse &[_]Mode{};

        // If no valid transitions, reuse 'from' as 'to'
        var to = from;
        if (valid.len > 0) {
            const to_idx = rapidcheck.rc_generate_int(ctx, 0, valid.len - 1);
            to = valid[to_idx];
        }

        return .{ .from = from, .to = to };
    }
};

// Generate a random specific action for a given mode
pub fn generateModeSpecificAction(ctx: *rapidcheck.RC_TestContext, mode: Mode) ModeAction {
    return switch (mode) {
        .fx_ctrl => .{ .fx_ctrl = generateFxCtrlAction(ctx) },
        .fx_sel => .{ .fx_sel = generateFxSelAction(ctx) },
        .transport => .{ .transport = generateTransportAction(ctx) },
        .mapping_panel => .{ .mapping = generateMappingAction(ctx) },
        .settings => .{ .settings = generateSettingsAction(ctx) },
        .default_fx_sel => .{ .default_fx_sel = generateFxSelAction(ctx) },
        .midi_learn => .{ .mapping = generateMappingAction(ctx) },
        .suspended => .{ .change_mode = .fx_ctrl }, // Always transition to fx_ctrl from suspended
    };
}

// Generate a random FX control action
fn generateFxCtrlAction(ctx: *rapidcheck.RC_TestContext) actions.FxCtrlAction {
    // Generate one of the possible FX control actions
    const action_types = std.enums.values(actions.FxCtrlAction);
    const type_idx = rapidcheck.rc_generate_int(ctx, 0, action_types.len - 1);

    // Return a random action of the selected type
    return action_types[type_idx];
}

// Generate a random FX selection action
fn generateFxSelAction(ctx: *rapidcheck.RC_TestContext) actions.FxSelActions {
    const action_types = std.enums.values(actions.FxSelActions);
    const type_idx = rapidcheck.rc_generate_int(ctx, 0, action_types.len - 1);
    return action_types[type_idx];
}

// Generate a random Transport action
fn generateTransportAction(ctx: *rapidcheck.RC_TestContext) actions.TransportAction {
    const action_types = std.enums.values(actions.TransportAction);
    const type_idx = rapidcheck.rc_generate_int(ctx, 0, action_types.len - 1);
    return action_types[type_idx];
}

// Generate a random Mapping action
fn generateMappingAction(ctx: *rapidcheck.RC_TestContext) actions.MappingAction {
    const action_types = std.enums.values(actions.MappingAction);
    const type_idx = rapidcheck.rc_generate_int(ctx, 0, action_types.len - 1);
    return action_types[type_idx];
}

// Generate a random Settings action
fn generateSettingsAction(ctx: *rapidcheck.RC_TestContext) actions.SettingsActions {
    const action_types = std.enums.values(actions.SettingsActions);
    const type_idx = rapidcheck.rc_generate_int(ctx, 0, action_types.len - 1);
    return action_types[type_idx];
}

// Generate a sequence of random actions to apply to the state machine
pub fn generateActionSequence(ctx: *rapidcheck.RC_TestContext, sequence_length: usize) ![]ModeAction {
    var allocator = std.heap.c_allocator;
    var actions_array = try allocator.alloc(ModeAction, sequence_length);

    // Always start with a change_mode action to ensure we're in a good state
    actions_array[0] = .{ .change_mode = .fx_ctrl };

    // Generate the rest of the actions
    var current_mode = Mode.fx_ctrl;

    for (1..sequence_length) |i| {
        // Occasionally generate a mode transition (20% chance)
        const should_transition = rapidcheck.rc_generate_int(ctx, 0, 4) == 0;

        if (should_transition) {
            const transition = ModeTransition.generate(ctx);
            // Only use the generated transition if current_mode matches from
            if (transition.from == current_mode) {
                actions_array[i] = .{ .change_mode = transition.to };
                current_mode = transition.to;
            } else {
                // Otherwise generate a mode-specific action
                actions_array[i] = generateModeSpecificAction(ctx, current_mode);
            }
        } else {
            // Generate a mode-specific action
            actions_array[i] = generateModeSpecificAction(ctx, current_mode);
        }
    }

    return actions_array;
}
