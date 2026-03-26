const std = @import("std");
const imgui = @import("reaper_imgui");
const mapping_actions = @import("action_types.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const AssignState = statemachine.AssignState;
const c1 = @import("c1.zig");
const tr = @import("translations.zig").tr;
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const Translations = @import("translations.zig");
const TranslationStore = Translations.TranslationStore;
const TranslationKey = Translations.TranslationKey;
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");

const constants = @import("constants.zig");
const Theme = @import("theme/Theme.zig");

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
                // Skip non-parameter fields because they are not optional u16 values
                if (comptime std.mem.eql(u8, field.name, "version")) continue;
                if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;

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
                // Skip non-parameter fields because they are not optional u16 values
                if (comptime std.mem.eql(u8, field.name, "version")) continue;
                if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;

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
    var text_buf: [256:0]u8 = undefined;

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
                    if (module != .STRIP) {
                        const phys: PhysicalModule = @enumFromInt(@intFromEnum(module));
                        if (assign_state.module_fx_names.get(phys)) |fx_name| {
                            break :blk std.fmt.bufPrintZ(&dropdown_buf, "{s}    [{s}]", .{ module_name, fx_name }) catch module_name;
                        }
                    }
                    break :blk std.fmt.bufPrintZ(&dropdown_buf, "{s}    {s}", .{ module_name, tr(translations, .mapping_no_fx) }) catch module_name;
                };

                if (try imgui.Selectable(.{ ctx, display_text })) {
                    rv = .{ .assign_change_module = module };
                }
            }
        }
    }

    // Preset dropdown -- only shown when user presets are available for this FX.
    // Because preset_name_offsets can only be non-empty after initPresetStrings
    // has been called, checking its length is a sufficient guard for accessing
    // preset_strings safely.
    if (assign_state.preset_name_offsets.len > 0) {
        try imgui.PushItemWidth(.{ ctx, 200.0 });
        defer imgui.PopItemWidth(.{ctx}) catch {};

        const current_label: [:0]const u8 = if (assign_state.selected_preset) |offset|
            assign_state.preset_strings.get(offset)
        else
            tr(translations, .mapping_preset_none);

        if (try imgui.BeginCombo(.{ ctx, "##preset_selection", current_label, null })) {
            defer imgui.EndCombo(.{ctx}) catch {};

            // "None" option to clear the preset association
            if (try imgui.Selectable(.{ ctx, tr(translations, .mapping_preset_none) })) {
                rv = .{ .assign_set_preset = null };
            }

            for (assign_state.preset_name_offsets) |offset| {
                const name = assign_state.preset_strings.get(offset);
                if (try imgui.Selectable(.{ ctx, name })) {
                    rv = .{ .assign_set_preset = offset };
                }
            }
        }

        // Because the checkbox should remain visible but inactive when no preset
        // is selected, we disable it rather than hiding it
        const no_preset_selected = assign_state.selected_preset == null;
        if (no_preset_selected) {
            try imgui.BeginDisabled(.{ctx});
        }
        defer if (no_preset_selected) {
            imgui.EndDisabled(.{ctx}) catch {};
        };

        var store_preset = assign_state.store_preset_data;
        if (try imgui.Checkbox(.{ ctx, tr(translations, .mapping_store_preset), &store_preset })) {
            rv = .{ .assign_toggle_store_preset = {} };
        }
    }

    const midi_learn_text = if (assign_state.midi_learn_active)
        tr(translations, .mapping_midi_learn_listening)
    else
        tr(translations, .mapping_midi_learn);

    if (try imgui.Button(.{ ctx, midi_learn_text })) {
        rv = .{ .assign_toggle_midi_learn = {} };
    }

    if (assign_state.midi_learn_active) {
        const has_cc = assign_state.selected_control != null;
        const has_param = assign_state.learned_param != null;

        if (has_cc and !has_param) {
            const text = std.fmt.bufPrintZ(&text_buf, "CC: {s} -- {s}", .{
                @tagName(assign_state.selected_control.?),
                tr(translations, .mapping_midi_learn_touch_param),
            }) catch "";
            try imgui.Text(.{ ctx, @as([*:0]const u8, @ptrCast(text.ptr)) });
        } else if (has_param and !has_cc) {
            const param_name = if (assign_state.learned_param.? < assign_state.param_store.len())
                assign_state.param_store.getName(@intCast(assign_state.learned_param.?))
            else
                "?";
            const text = std.fmt.bufPrintZ(&text_buf, "Param: {s} (#{d}) -- {s}", .{
                param_name,
                assign_state.learned_param.?,
                tr(translations, .mapping_midi_learn_move_control),
            }) catch "";
            try imgui.Text(.{ ctx, @as([*:0]const u8, @ptrCast(text.ptr)) });
        } else {
            try imgui.Text(.{ ctx, tr(translations, .mapping_midi_learn_waiting) });
        }
    }

    try imgui.SetCursorPosY(.{ ctx, try imgui.GetCursorPosY(.{ctx}) + 10 });
    try imgui.Separator(.{ctx});
    try imgui.SetCursorPosY(.{ ctx, try imgui.GetCursorPosY(.{ctx}) + 10 });
    if (try assignmentList(ctx, assign_state, translations, &text_buf)) |action| {
        rv = action;
    }
    try imgui.SetCursorPosY(.{ ctx, try imgui.GetCursorPosY(.{ctx}) + 10 });
    try imgui.Separator(.{ctx});
    try imgui.SetCursorPosY(.{ ctx, try imgui.GetCursorPosY(.{ctx}) + 10 });

    if (try imgui.Button(.{ ctx, tr(translations, .mapping_save) })) {
        rv = .{ .assign_request_save = {} };
    }
    try imgui.SameLine(.{ctx});
    if (try imgui.Button(.{ ctx, tr(translations, .mapping_cancel) })) {
        rv = .{ .assign_cancel = {} };
    }

    if (assign_state.save_error) |err_key| {
        try imgui.TextColored(.{ ctx, try imgui.GetStyleColor(.{ ctx, imgui.Col_PlotHistogram }), tr(translations, err_key) });
    }

    return rv;
}

fn assignmentList(
    ctx: imgui.ContextPtr,
    assign_state: *const AssignState,
    translations: *TranslationStore,
    buf: *[256:0]u8,
) !?mapping_actions.MappingPanelAction {
    _ = translations;
    var rv: ?mapping_actions.MappingPanelAction = null;

    switch (assign_state.current_mappings) {
        inline else => |mapping| {
            inline for (std.meta.fields(@TypeOf(mapping))) |field| {
                if (comptime std.mem.eql(u8, field.name, "version")) continue;
                if (comptime !@hasField(c1.CCs, field.name)) continue;

                if (@field(mapping, field.name)) |param_idx| {
                    const param_name = if (param_idx < assign_state.param_store.len())
                        assign_state.param_store.getName(@intCast(param_idx))
                    else
                        "?";
                    const label = std.fmt.bufPrintZ(buf, "{s} -> {s} (#{d})", .{
                        field.name,
                        param_name,
                        param_idx,
                    }) catch "";
                    try imgui.Text(.{ ctx, @as([*:0]const u8, @ptrCast(label.ptr)) });

                    try imgui.SameLine(.{ctx});
                    {
                        try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
                        defer imgui.PopFont(.{ctx}) catch {};
                        const btn_label = std.fmt.bufPrintZ(buf, "{s}##rm_{s}", .{
                            Theme.Icons.get(.close), field.name,
                        }) catch "x";
                        if (try imgui.SmallButton(.{ ctx, @as([*:0]const u8, @ptrCast(btn_label.ptr)) })) {
                            rv = .{ .assign_remove_mapping = @field(c1.CCs, field.name) };
                        }
                    }
                }
            }
        },
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
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    // Get current mapping
    const assignment = getControlMapping(state, cc);
    const assignment_label: [:0]const u8 = if (assignment) |assgnmnt|
        assign_state.param_store.getName(@intCast(assgnmnt))
    else
        tr(translations, .mapping_none);

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
            translations,
        ),
        .knob => blk: {
            const label_id = @import("components/knob.zig").LabelId{
                .label = label,
                .id = @tagName(cc),
            };
            const knob_value = assign_state.knob_values[@intFromEnum(cc)];
            break :blk try @import("components/mappingKnob.zig").drawWidget(ctx, knob_value, label_id, .{ .disabled = disabled, .knob_bg = try imgui.GetStyleColor(.{ ctx, imgui.Col_FrameBg }) }, cc, assignment_label, &assign_state.param_store, translations);
        },
    };

    if (mVal) |val| {
        switch (val) {
            .click => rv = .{ .assign_select_control = cc },
            .param_idx => |i| rv = .{ .assign_add_mapping = .{ .param = @intCast(i), .control = cc } },
            .remove_mapping => rv = .{ .assign_remove_mapping = cc },
            .value_changed => |new_val| rv = .{ .assign_update_knob = .{ .cc = cc, .value = new_val } },
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

        if (try mappingWidget(ctx, state, assign_state, .Inpt_Gain, gain_label, .knob, disabled, translations)) |act| {
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
        if (try mappingWidget(ctx, state, assign_state, .Inpt_HiCut, hicut_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // LoCut knob
        if (try mappingWidget(ctx, state, assign_state, .Inpt_LoCut, locut_label, .knob, disabled, translations)) |act| {
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

    if (try mappingWidget(ctx, state, assign_state, .Shp_shape, shp_shape_label, .button, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Shp_Gate, gate_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Hard gate button
        const hard_gate_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_hard_gate,
            else => null,
        };
        const hard_gate_label = if (hard_gate_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_hard_gate, hard_gate_label, .button, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Shp_GateRelease, release_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Sustain knob
        const sustain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_sustain,
            else => null,
        };
        const sustain_label = if (sustain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_sustain, sustain_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Punch knob
        const punch_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Shp_Punch,
            else => null,
        };
        const punch_label = if (punch_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Shp_Punch, punch_label, .knob, disabled, translations)) |act| {
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

    if (try mappingWidget(ctx, state, assign_state, .Eq_eq, eq_eq_label, .button, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Eq_lp_shape, lp_shape_label, .button, disabled, translations)) |act| {
            rv = act;
        }

        // LoFreq knob
        const lofreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoFrq,
            else => null,
        };
        const lofreq_label = if (lofreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoFrq, lofreq_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // LoGain knob
        const logain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoGain,
            else => null,
        };
        const logain_label = if (logain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoGain, logain_label, .knob, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoMidQ, lomidq_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // LoMidFreq knob
        const lomidfreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoMidFrq,
            else => null,
        };
        const lomidfreq_label = if (lomidfreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoMidFrq, lomidfreq_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // LoMidGain knob
        const lomidgain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_LoMidGain,
            else => null,
        };
        const lomidgain_label = if (lomidgain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_LoMidGain, lomidgain_label, .knob, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiMidQ, himidq_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // HiMidFreq knob
        const himidfreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiMidFrq,
            else => null,
        };
        const himidfreq_label = if (himidfreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiMidFrq, himidfreq_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // HiMidGain knob
        const himidgain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiMidGain,
            else => null,
        };
        const himidgain_label = if (himidgain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiMidGain, himidgain_label, .knob, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Eq_hp_shape, hp_shape_label, .button, disabled, translations)) |act| {
            rv = act;
        }

        // HiFreq knob
        const hifreq_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiFrq,
            else => null,
        };
        const hifreq_label = if (hifreq_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiFrq, hifreq_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // HiGain knob
        const higain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Eq_HiGain,
            else => null,
        };
        const higain_label = if (higain_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Eq_HiGain, higain_label, .knob, disabled, translations)) |act| {
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

    if (try mappingWidget(ctx, state, assign_state, .Comp_comp, comp_comp_label, .button, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Comp_Ratio, ratio_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // DryWet knob
        const drywet_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_DryWet,
            else => null,
        };
        const drywet_label = if (drywet_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_DryWet, drywet_label, .knob, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Comp_Attack, attack_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Release knob
        const release_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_Release,
            else => null,
        };
        const release_label = if (release_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_Release, release_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Thresh knob
        const thresh_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_Thresh,
            else => null,
        };
        const thresh_label = if (thresh_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_Thresh, thresh_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Comp HiCut knob
        const comp_hicut_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_HiCut,
            else => null,
        };
        const comp_hicut_label = if (comp_hicut_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_HiCut, comp_hicut_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Comp LoCut knob
        const comp_locut_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Comp_LoCut,
            else => null,
        };
        const comp_locut_label = if (comp_locut_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Comp_LoCut, comp_locut_label, .knob, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Out_Drive, drive_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // DriveChar knob
        const char_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_DriveChar,
            else => null,
        };
        const char_label = if (char_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_DriveChar, char_label, .knob, disabled, translations)) |act| {
            rv = act;
        }

        // Pan knob
        const pan_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_Pan,
            else => null,
        };
        const pan_label = if (pan_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_Pan, pan_label, .knob, disabled, translations)) |act| {
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

        if (try mappingWidget(ctx, state, assign_state, .Out_solo, out_solo_label, .button, disabled, translations)) |act| {
            rv = act;
        }

        try imgui.SameLine(.{ctx});

        // Mute button
        const out_mute_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_mute,
            else => null,
        };
        const out_mute_label = if (out_mute_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_mute, out_mute_label, .button, disabled, translations)) |act| {
            rv = act;
        }

        // Volume knob
        const vol_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Out_Vol,
            else => null,
        };
        const vol_label = if (vol_key) |key| tr(translations, key) else "-";

        if (try mappingWidget(ctx, state, assign_state, .Out_Vol, vol_label, .knob, disabled, translations)) |act| {
            rv = act;
        }
    }

    return rv;
}
