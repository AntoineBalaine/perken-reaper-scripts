const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const fx_parser = @import("fx_parser.zig");
const safePrint = @import("debug_panel.zig").safePrint;
const Globals = @import("globals.zig").Globals;
const mapping_actions = @import("mapping_actions.zig");
const State = @import("statemachine.zig").State;
const c1 = @import("c1.zig");
const actions = @import("actions.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;

pub const FxParameter = struct {
    index: u32,
    name: [:0]const u8,
};

pub const MappingPanel = struct {
    fx_params: std.ArrayList(FxParameter),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MappingPanel {
        return .{
            .fx_params = std.ArrayList(FxParameter).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        // Free parameter names
        for (self.fx_params.items) |param| {
            self.allocator.free(param.name);
        }
        self.fx_params.deinit();
    }

    pub fn loadParameters(
        self: *@This(),
        track: reaper.MediaTrack,
        fx_number: i32,
    ) !void {
        // Clear existing parameters
        self.deinit();
        self.fx_params = std.ArrayList(FxParameter).init(self.allocator);

        const params_length: usize = @intCast(reaper.TrackFX_GetNumParams(track, fx_number));
        try self.fx_params.ensureTotalCapacity(params_length);

        var prm_name_buf: [256:0]u8 = undefined;
        for (0..params_length) |i| {
            const prm_idx: i32 = @intCast(i);
            if (reaper.TrackFX_GetParamName(track, fx_number, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                const param_name = try self.allocator.dupeZ(u8, std.mem.span(@as([*:0]const u8, &prm_name_buf)));
                try self.fx_params.append(.{
                    .index = @intCast(i),
                    .name = param_name,
                });
            }
        }
    }
};

// Function to handle the parameters column
fn params(
    ctx: imgui.ContextPtr,
    globals: *Globals,
    translations: *TranslationStore,
) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;

    if (globals.mapping_panel) |panel| {
        for (panel.fx_params.items, 0..) |param, i| {
            var is_selected = if (globals.state.mapping.selected_parameter) |sel|
                sel == i
            else
                false;

            if (try imgui.Selectable(.{
                ctx,
                param.name,
                &is_selected,
                null,
                0.0, // full width
            })) {
                rv = .{ .select_parameter = @intCast(i) };
            }

            if (isParamMapped(&globals.state, i)) {
                try imgui.SameLine(.{ctx});
                try imgui.TextDisabled(.{ ctx, tr(translations, .mapping_mapped) });
            }
        }
    }

    return rv;
}

pub fn mappingPanel(ctx: imgui.ContextPtr, globals: *Globals, translations: *TranslationStore) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    try imgui.Text(.{ ctx, tr(translations, .mapping_title) });
    // Main table for two-column layout

    if (try imgui.BeginTable(.{ ctx, "mapping_table", 2, imgui.TableFlags_Resizable + imgui.TableFlags_Borders + imgui.TableFlags_BordersInnerH })) {
        defer imgui.EndTable(.{ctx}) catch {};

        // Setup columns
        try imgui.TableSetupColumn(.{ ctx, tr(translations, .mapping_fx_parameters) });
        try imgui.TableSetupColumn(.{ ctx, tr(translations, .mapping_console_controls) });
        try imgui.TableHeadersRow(.{ctx});

        // Parameters column
        try imgui.TableNextRow(.{ctx});
        if (try imgui.TableNextColumn(.{ctx})) {
            if (try params(ctx, globals, translations)) |action| {
                rv = action;
            }
        }

        // Controls column
        if (try imgui.TableNextColumn(.{ctx})) {
            if (try controls(ctx, globals, translations)) |action| {
                rv = action;
            }
        }
    }
    // Bottom panel with buttons
    try imgui.Separator(.{ctx});
    if (try formControls(ctx, globals, translations)) |action| {
        rv = action;
    }
    return rv;
}

// Function to handle the controls column
fn controls(
    ctx: imgui.ContextPtr,
    globals: *Globals,
    translations: *TranslationStore,
) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;

    const module_type = @tagName(globals.state.mapping.current_mappings);
    try imgui.Text(.{ ctx, tr(translations, .mapping_module_prefix), .{module_type} });
    try imgui.Separator(.{ctx});

    switch (globals.state.mapping.current_mappings) {
        .INPUT => {
            if (try moduleCCs(ctx, &globals.state, &input_controls, translations)) |act| rv = act;
        },
        .GATE => {
            if (try moduleCCs(ctx, &globals.state, &gate_controls, translations)) |act| rv = act;
        },
        .EQ => {
            if (try moduleCCs(ctx, &globals.state, &eq_controls, translations)) |act| rv = act;
        },
        .COMP => {
            if (try moduleCCs(ctx, &globals.state, &compressor_controls, translations)) |act| rv = act;
        },
        .OUTPT => {
            if (try moduleCCs(ctx, &globals.state, &output_controls, translations)) |act| rv = act;
        },
    }

    return rv;
}

// Helper function to draw module-specific controls
fn moduleCCs(
    ctx: imgui.ContextPtr,
    state: *State,
    comptime ccs: []const c1.CCs,
    translations: *TranslationStore,
) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;
    inline for (ccs) |cc| {
        var is_selected = if (state.mapping.selected_control) |sel|
            sel == cc
        else
            false;

        if (try imgui.Selectable(.{
            ctx,
            @tagName(cc),
            &is_selected,
            null,
            -1.0,
        })) {
            rv = .{ .select_control = cc };
        }

        // Show mapped parameter if any
        if (getControlMapping(state, cc)) |param_idx| {
            try imgui.SameLine(.{ctx});
            try imgui.TextDisabled(.{ ctx, tr(translations, .mapping_param_mapped), .{param_idx} });
        }
    }
    return rv;
}

fn isParamMapped(state: *State, param_idx: usize) bool {
    const param: u8 = @intCast(param_idx);
    switch (state.mapping.current_mappings) {
        inline else => |mapping| {
            inline for (std.meta.fields(@TypeOf(mapping))) |field| {
                if (@field(mapping, field.name)) |mapped_param| {
                    if (mapped_param == param) return true;
                }
            }
        },
    }
    return false;
}

fn getControlMapping(state: *State, cc: c1.CCs) ?u32 {
    const cc_name = @tagName(cc);
    switch (state.mapping.current_mappings) {
        inline else => |mapping| {
            inline for (std.meta.fields(@TypeOf(mapping))) |field| {
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

const compressor_controls = [_]c1.CCs{
    .Comp_Attack,
    .Comp_Release,
    .Comp_Thresh,
    .Comp_Ratio,
    .Comp_DryWet,
    .Comp_comp,
};

const eq_controls = [_]c1.CCs{
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
};

const input_controls = [_]c1.CCs{
    .Inpt_Gain,
    .Inpt_HiCut,
    .Inpt_LoCut,
    .Inpt_disp_mode,
    .Inpt_disp_on,
    .Inpt_filt_to_comp,
    .Inpt_phase_inv,
    .Inpt_preset,
};

const output_controls = [_]c1.CCs{
    .Out_Drive,
    .Out_DriveChar,
    .Out_Pan,
    .Out_Vol,
};

const gate_controls = [_]c1.CCs{
    .Shp_Gate,
    .Shp_GateRelease,
    .Shp_Punch,
    .Shp_hard_gate,
    .Shp_shape,
    .Shp_sustain,
};

// Function to handle the bottom panel with buttons
fn formControls(
    ctx: imgui.ContextPtr,
    globals: *Globals,
    translations: *TranslationStore,
) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;

    const midi_learn_text = if (globals.state.mapping.midi_learn_active)
        tr(translations, .mapping_midi_learn_active)
    else
        tr(translations, .mapping_midi_learn);

    if (try imgui.Button(.{ ctx, midi_learn_text })) {
        rv = .{ .toggle_midi_learn = {} };
    }

    try imgui.SameLine(.{ctx});

    if (try imgui.Button(.{ ctx, tr(translations, .mapping_save) })) {
        rv = .{ .save_mapping = {} };
    }

    try imgui.SameLine(.{ctx});

    if (try imgui.Button(.{ ctx, tr(translations, .mapping_cancel) })) {
        rv = .{ .cancel_mapping = {} };
    }

    return rv;
}
