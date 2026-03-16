const std = @import("std");
const imgui = @import("reaper_imgui");
const mapping_actions = @import("action_types.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const AssignState = statemachine.AssignState;
const c1 = @import("c1.zig");
const tr = @import("translations.zig").tr;
const ModulesList = statemachine.ModulesList;
const Translations = @import("translations.zig");
const TranslationStore = Translations.TranslationStore;
const TranslationKey = Translations.TranslationKey;
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");
const constants = @import("constants.zig");

// Function to handle the parameters column
fn params(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    for (0..assign_state.param_store.len()) |i| {
        const param_name = assign_state.param_store.getName(i);
        var is_selected = if (assign_state.selected_parameter) |sel|
            sel == i
        else
            false;

        if (try imgui.Selectable(.{
            ctx,
            param_name,
            &is_selected,
            null,
            0.0, // full width
        })) {
            rv = .{ .assign_select_parameter = @intCast(i) };
        }

        if (isParamMapped(state, i)) {
            try imgui.SameLine(.{ctx});
            try imgui.TextDisabled(.{ ctx, tr(translations, .mapping_mapped) });
        }
    }

    return rv;
}

pub fn drawMappingPanel(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (try controls(ctx, state, assign_state, translations)) |action| {
        rv = action;
    }
    try imgui.SameLine(.{ctx});
    if (try formControls(ctx, assign_state, translations)) |action| {
        rv = action;
    }
    return rv;
}

// Function to handle the controls column
fn controls(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    // Define an array of panel functions and their corresponding modules
    const panels = [_]struct { module: ModulesList, panel_fn: @TypeOf(inputMappingPanel) }{
        .{ .module = .INPUT, .panel_fn = inputMappingPanel },
        .{ .module = .GATE, .panel_fn = gateMappingPanel },
        .{ .module = .EQ, .panel_fn = eqMappingPanel },
        .{ .module = .COMP, .panel_fn = compMappingPanel },
        .{ .module = .OUTPT, .panel_fn = outputMappingPanel },
    };

    // Call each panel function, but only process actions from the active one
    inline for (panels) |panel_info| {
        const is_active = assign_state.current_mappings == panel_info.module;

        if (!is_active) {
            try imgui.BeginDisabled(.{ctx});
        }
        defer if (!is_active) {
            imgui.EndDisabled(.{ctx}) catch {};
        };

        if (try panel_info.panel_fn(ctx, state, assign_state, translations, !is_active)) |act| {
            if (is_active) {
                rv = act;
            }
        }

        // Add sectional divider between panels (except after the last one)
        try fx_ctrl_panel.sectional(ctx);
    }

    return rv;
}

fn isParamMapped(state: *const State, param_idx: usize) bool {
    const param: u16 = @intCast(param_idx);
    const current_mappings = switch (state.mapping_panel.mode) {
        .assign => |s| s.current_mappings,
        else => return false,
    };
    switch (current_mappings) {
        inline else => |mapping| {
            inline for (std.meta.fields(@TypeOf(mapping))) |field| {
                // Skip the version field because it is not optional
                if (comptime std.mem.eql(u8, field.name, "version")) continue;

                if (@field(mapping, field.name)) |mapped_param| {
                    if (mapped_param == param) return true;
                }
            }
        },
    }
    return false;
}

fn getControlMapping(state: *const State, cc: c1.CCs) ?u32 {
    const cc_name = @tagName(cc);
    const current_mappings = switch (state.mapping_panel.mode) {
        .assign => |s| s.current_mappings,
        else => return null,
    };
    switch (current_mappings) {
        inline else => |mapping| {
            inline for (std.meta.fields(@TypeOf(mapping))) |field| {
                // Skip the version field because it is not optional
                if (comptime std.mem.eql(u8, field.name, "version")) continue;

                if (std.mem.eql(u8, field.name, cc_name)) {
                    if (@field(mapping, field.name)) |param| {
                        return @intCast(param);
                    }
                }
            }
            return null;
        },
    }
}

// Function to handle the bottom panel with buttons
fn formControls(
    ctx: imgui.ContextPtr,
    assign_state: *const AssignState,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};
    {
        try imgui.PushItemWidth(.{ ctx, 100.0 });
        defer imgui.PopItemWidth(.{ctx}) catch {};

        if (try imgui.BeginCombo(.{ ctx, "##module_selection", @tagName(assign_state.current_mappings), null })) {
            defer imgui.EndCombo(.{ctx}) catch {};

            var dropdown_buf: [512:0]u8 = undefined;
            inline for (comptime std.enums.values(ModulesList)) |module| {
                const module_name = @tagName(module);
                const display_text: [:0]const u8 = blk: {
                    if (assign_state.module_fx_names.get(module)) |fx_name| {
                        break :blk std.fmt.bufPrintZ(&dropdown_buf, "{s}    [{s}]", .{ module_name, fx_name }) catch module_name;
                    }
                    break :blk std.fmt.bufPrintZ(&dropdown_buf, "{s}    [No FX]", .{module_name}) catch module_name;
                };

                if (try imgui.Selectable(.{ ctx, display_text })) {
                    rv = .{ .assign_change_module = module };
                }
            }
        }
    }

    // Because the button label should reflect whether a learn operation is
    // in progress (either phase), we check both listening states.
    const midi_learn_text = switch (assign_state.midi_learn) {
        .listening_cc, .listening_param => tr(translations, .mapping_midi_learn_listening),
        .idle => tr(translations, .mapping_midi_learn),
    };

    if (try imgui.Button(.{ ctx, midi_learn_text })) {
        rv = .{ .assign_toggle_midi_learn = {} };
    }

    // Because the user needs to know the current state of the MIDI learn flow,
    // we display a status message below the button.
    switch (assign_state.midi_learn) {
        .listening_cc => {
            try imgui.Text(.{ ctx, tr(translations, .mapping_midi_learn_move_control) });
        },
        .listening_param => {
            if (assign_state.selected_control) |control| {
                var status_buf: [128:0]u8 = undefined;
                _ = std.fmt.bufPrint(&status_buf, "{s} -- {s}", .{
                    @tagName(control),
                    tr(translations, .mapping_midi_learn_touch_param),
                }) catch {};
                try imgui.Text(.{ ctx, @as([*:0]const u8, &status_buf) });
            }
        },
        .idle => {},
    }

    if (try imgui.Button(.{ ctx, tr(translations, .mapping_save) })) {
        rv = .{ .assign_request_save = {} };
    }

    if (try imgui.Button(.{ ctx, tr(translations, .mapping_cancel) })) {
        rv = .{ .assign_cancel = {} };
    }

    return rv;
}

fn mappingWidget(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    comptime cc: c1.CCs,
    label: [:0]const u8,
    variant: enum { button, knob },
    disabled: bool,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    // Get current mapping
    const assignment = getControlMapping(state, cc);
    const assignment_label: [:0]const u8 = if (assignment) |assgnmnt|
        assign_state.param_store.getName(@intCast(assgnmnt))
    else
        "none";

    const mVal = switch (variant) {
        .button => try @import("components/mappingButton.zig").mappingButton(
            ctx,
            label,
            "##" ++ @tagName(cc),
            null,
            null,
            .right,
            false,
            cc,
            assignment_label,
            &assign_state.param_store,
        ),
        .knob => blk: {
            const label_id = @import("components/knob.zig").LabelId{
                .label = label,
                .id = @tagName(cc),
            };
            break :blk try @import("components/mappingKnob.zig").drawWidget(ctx, 0.5, label_id, .{ .disabled = disabled }, cc, assignment_label, &assign_state.param_store);
        },
    };

    if (mVal) |val| {
        switch (val) {
            .click => rv = .{ .assign_select_control = cc },
            .param_idx => |i| rv = .{ .assign_add_mapping = .{ .param = @intCast(i), .control = cc } },
            .remove_mapping => rv = .{ .assign_remove_mapping = cc },
        }
    }

    return rv;
}

fn inputMappingPanel(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
    disabled: bool,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const mode = .fx_ctrl; // Always use fx_ctrl mode for labels

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (assign_state.module_fx_names.get(.INPUT)) |fx_name| {
        try imgui.TextDisabled(.{ ctx, fx_name });
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Dummy(.{ ctx, 0, constants.knob_size * 2 });

        // Gain knob
        const gain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_Gain,
            else => null,
        };
        const gain_label = if (gain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Inpt_Gain, gain_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Calculate max width for this column's knobs
        const hicut_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_HiCut,
            .transport => .trsprt_Inpt_HiCut,
            else => null,
        };
        const hicut_label = if (hicut_key) |key| tr(translations, key) else "-";

        const locut_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_LoCut,
            else => null,
        };
        const locut_label = if (locut_key) |key| tr(translations, key) else "-";

        // HiCut knob
        if (try mappingWidget(ctx, state, assign_state, .Inpt_HiCut, hicut_label, .knob, disabled)) |act| {
            rv = act;
        }

        // LoCut knob
        if (try mappingWidget(ctx, state, assign_state, .Inpt_LoCut, locut_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    return rv;
}

fn gateMappingPanel(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
    disabled: bool,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const mode = .fx_ctrl; // Always use fx_ctrl mode for labels

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (assign_state.module_fx_names.get(.GATE)) |fx_name| {
        try imgui.TextDisabled(.{ ctx, fx_name });
    }

    // Shape button at the top
    const shp_shape_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Shp_shape,
        else => null,
    };
    const shp_shape_label = if (shp_shape_key) |key| tr(translations, key) else "-";

    if (try mappingWidget(ctx, state, assign_state, .Shp_shape, shp_shape_label, .button, disabled)) |act| {
        rv = act;
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Dummy(.{ ctx, 0, constants.knob_size * 0.75 });

        // Gate knob
        const gate_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_Gate,
            else => null,
        };
        const gate_label = if (gate_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_Gate, gate_label, .knob, disabled)) |act| {
            rv = act;
        }

        // Hard gate button
        const hard_gate_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_hard_gate,
            else => null,
        };
        const hard_gate_label = if (hard_gate_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_hard_gate, hard_gate_label, .button, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Release knob
        const release_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_GateRelease,
            else => null,
        };
        const release_label = if (release_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_GateRelease, release_label, .knob, disabled)) |act| {
            rv = act;
        }

        // Sustain knob
        const sustain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_sustain,
            else => null,
        };
        const sustain_label = if (sustain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_sustain, sustain_label, .knob, disabled)) |act| {
            rv = act;
        }

        // Punch knob
        const punch_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_Punch,
            else => null,
        };
        const punch_label = if (punch_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_Punch, punch_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    return rv;
}

fn eqMappingPanel(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
    disabled: bool,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const mode = .fx_ctrl; // Always use fx_ctrl mode for labels

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (assign_state.module_fx_names.get(.EQ)) |fx_name| {
        try imgui.TextDisabled(.{ ctx, fx_name });
    }

    // EQ button at the top
    const eq_eq_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Eq_eq,
        else => null,
    };
    const eq_eq_label = if (eq_eq_key) |key| tr(translations, key) else "-";

    if (try mappingWidget(ctx, state, assign_state, .Eq_eq, eq_eq_label, .button, disabled)) |act| {
        rv = act;
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Dummy(.{ ctx, 0, constants.knob_size * 0.5 });

        // LP Shape button
        const lp_shape_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_lp_shape,
            else => null,
        };
        const lp_shape_label = if (lp_shape_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_lp_shape, lp_shape_label, .button, disabled)) |act| {
            rv = act;
        }

        // LoFreq knob
        const lofreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoFrq,
            else => null,
        };
        const lofreq_label = if (lofreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoFrq, lofreq_label, .knob, disabled)) |act| {
            rv = act;
        }

        // LoGain knob
        const logain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoGain,
            else => null,
        };
        const logain_label = if (logain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoGain, logain_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // LoMidQ knob
        const lomidq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoMidQ,
            else => null,
        };
        const lomidq_label = if (lomidq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoMidQ, lomidq_label, .knob, disabled)) |act| {
            rv = act;
        }

        // LoMidFreq knob
        const lomidfreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoMidFrq,
            else => null,
        };
        const lomidfreq_label = if (lomidfreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoMidFrq, lomidfreq_label, .knob, disabled)) |act| {
            rv = act;
        }

        // LoMidGain knob
        const lomidgain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoMidGain,
            else => null,
        };
        const lomidgain_label = if (lomidgain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoMidGain, lomidgain_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Third column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // HiMidQ knob
        const himidq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiMidQ,
            else => null,
        };
        const himidq_label = if (himidq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiMidQ, himidq_label, .knob, disabled)) |act| {
            rv = act;
        }

        // HiMidFreq knob
        const himidfreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiMidFrq,
            else => null,
        };
        const himidfreq_label = if (himidfreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiMidFrq, himidfreq_label, .knob, disabled)) |act| {
            rv = act;
        }

        // HiMidGain knob
        const himidgain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiMidGain,
            else => null,
        };
        const himidgain_label = if (himidgain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiMidGain, himidgain_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Fourth column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Dummy(.{ ctx, 0, constants.knob_size * 0.5 });

        // HP Shape button
        const hp_shape_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_hp_shape,
            else => null,
        };
        const hp_shape_label = if (hp_shape_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_hp_shape, hp_shape_label, .button, disabled)) |act| {
            rv = act;
        }

        // HiFreq knob
        const hifreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiFrq,
            else => null,
        };
        const hifreq_label = if (hifreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiFrq, hifreq_label, .knob, disabled)) |act| {
            rv = act;
        }

        // HiGain knob
        const higain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiGain,
            else => null,
        };
        const higain_label = if (higain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiGain, higain_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    return rv;
}

fn compMappingPanel(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
    disabled: bool,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const mode = .fx_ctrl; // Always use fx_ctrl mode for labels

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (assign_state.module_fx_names.get(.COMP)) |fx_name| {
        try imgui.TextDisabled(.{ ctx, fx_name });
    }

    // Comp button at the top
    const comp_comp_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Comp_comp,
        else => null,
    };
    const comp_comp_label = if (comp_comp_key) |key| tr(translations, key) else "-";

    if (try mappingWidget(ctx, state, assign_state, .Comp_comp, comp_comp_label, .button, disabled)) |act| {
        rv = act;
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Dummy(.{ ctx, 0, constants.knob_size * 0.5 });

        // Ratio knob
        const ratio_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_Ratio,
            else => null,
        };
        const ratio_label = if (ratio_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_Ratio, ratio_label, .knob, disabled)) |act| {
            rv = act;
        }

        // DryWet knob
        const drywet_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_DryWet,
            else => null,
        };
        const drywet_label = if (drywet_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_DryWet, drywet_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Attack knob
        const attack_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_Attack,
            else => null,
        };
        const attack_label = if (attack_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_Attack, attack_label, .knob, disabled)) |act| {
            rv = act;
        }

        // Release knob
        const release_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_Release,
            else => null,
        };
        const release_label = if (release_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_Release, release_label, .knob, disabled)) |act| {
            rv = act;
        }

        // Thresh knob
        const thresh_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_Thresh,
            else => null,
        };
        const thresh_label = if (thresh_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_Thresh, thresh_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    return rv;
}

fn outputMappingPanel(
    ctx: imgui.ContextPtr,
    state: *const State,
    assign_state: *const AssignState,
    translations: *TranslationStore,
    disabled: bool,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const mode = .fx_ctrl; // Always use fx_ctrl mode for labels

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (assign_state.module_fx_names.get(.OUTPT)) |fx_name| {
        try imgui.TextDisabled(.{ ctx, fx_name });
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Drive knob
        const drive_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_Drive,
            else => null,
        };
        const drive_label = if (drive_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_Drive, drive_label, .knob, disabled)) |act| {
            rv = act;
        }

        // DriveChar knob
        const char_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_DriveChar,
            else => null,
        };
        const char_label = if (char_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_DriveChar, char_label, .knob, disabled)) |act| {
            rv = act;
        }

        // Pan knob
        const pan_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_Pan,
            else => null,
        };
        const pan_label = if (pan_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_Pan, pan_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Dummy(.{ ctx, constants.knob_size * 2, constants.knob_size * 2 });

        // Solo button
        const out_solo_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_solo,
            else => null,
        };
        const out_solo_label = if (out_solo_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_solo, out_solo_label, .button, disabled)) |act| {
            rv = act;
        }

        try imgui.SameLine(.{ctx});

        // Mute button
        const out_mute_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_mute,
            else => null,
        };
        const out_mute_label = if (out_mute_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_mute, out_mute_label, .button, disabled)) |act| {
            rv = act;
        }

        // Volume knob
        const vol_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_Vol,
            else => null,
        };
        const vol_label = if (vol_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_Vol, vol_label, .knob, disabled)) |act| {
            rv = act;
        }
    }

    return rv;
}
