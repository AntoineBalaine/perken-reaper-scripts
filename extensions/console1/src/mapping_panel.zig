const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const fx_parser = @import("fx_parser.zig");
const safePrint = @import("debug_panel.zig").safePrint;
const globals = @import("globals.zig");
const mapping_actions = @import("mapping_actions.zig");
const State = @import("statemachine.zig").State;
const c1 = @import("c1.zig");
const actions = @import("actions.zig");

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

pub fn drawMappingPanel(ctx: imgui.ContextPtr, state: *State) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    try imgui.Text(.{ ctx, "Mapping Panel" });
    // Main table for two-column layout

    if (try imgui.BeginTable(.{ ctx, "mapping_table", 2, imgui.TableFlags_Resizable + imgui.TableFlags_Borders + imgui.TableFlags_BordersInnerH })) {
        defer imgui.EndTable(.{ctx}) catch {};

        // Setup columns
        try imgui.TableSetupColumn(.{ ctx, "FX Parameters" });
        try imgui.TableSetupColumn(.{ ctx, "Console Controls" });
        try imgui.TableHeadersRow(.{ctx});

        // // Parameters column
        try imgui.TableNextRow(.{ctx});
        if (try imgui.TableNextColumn(.{ctx})) {
            if (globals.mapping_panel) |panel| {
                for (panel.fx_params.items, 0..) |param, i| {
                    var is_selected = if (state.mapping.selected_parameter) |sel|
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

                    if (isParamMapped(state, i)) {
                        try imgui.SameLine(.{ctx});
                        try imgui.TextDisabled(.{ ctx, "(Mapped)" });
                    }
                }
            }
        }
        //
        // // Controls column
        //
        if (try imgui.TableNextColumn(.{ctx})) {
            const module_type = @tagName(state.mapping.current_mappings);
            try imgui.Text(.{ ctx, "Module: {s}", .{module_type} });
            try imgui.Separator(.{ctx});
            switch (state.mapping.current_mappings) {
                .INPUT => {
                    if (try drawModuleControls(ctx, state, &input_controls)) |act| rv = act;
                },
                .GATE => {
                    if (try drawModuleControls(ctx, state, &gate_controls)) |act| rv = act;
                },
                .EQ => {
                    if (try drawModuleControls(ctx, state, &eq_controls)) |act| rv = act;
                },
                .COMP => {
                    if (try drawModuleControls(ctx, state, &compressor_controls)) |act| rv = act;
                },
                .OUTPT => {
                    if (try drawModuleControls(ctx, state, &output_controls)) |act| rv = act;
                },
            }

            // if (try drawModuleControls(ctx, state, switch (state.mapping.current_mappings) {
            //     .INPUT => &input_controls,
            //     .GATE => &gate_controls,
            //     .EQ => &eq_controls,
            //     .COMP => &compressor_controls,
            //     .OUTPT => &output_controls,
            // })) |map_action| rv = map_action;
        }
    }
    // Bottom panel with buttons
    try imgui.Separator(.{ctx});
    {
        const midi_learn_text = if (state.mapping.midi_learn_active)
            "MIDI Learn (Active)"
        else
            "MIDI Learn";

        if (try imgui.Button(.{ ctx, midi_learn_text })) {
            rv = .{ .toggle_midi_learn = {} };
        }

        try imgui.SameLine(.{ctx});

        if (try imgui.Button(.{ ctx, "Save Mapping" })) {
            rv = .{ .save_mapping = {} };
        }

        try imgui.SameLine(.{ctx});

        if (try imgui.Button(.{ ctx, "Cancel" })) {
            rv = .{ .cancel_mapping = {} };
        }
    }
    return rv;
}

// Helper function to draw module-specific controls
fn drawModuleControls(
    ctx: imgui.ContextPtr,
    state: *State,
    comptime controls: []const c1.CCs,
) !?mapping_actions.MappingAction {
    var rv: ?mapping_actions.MappingAction = null;
    inline for (controls) |cc| {
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
            try imgui.TextDisabled(.{ ctx, "(-> Param {d})", .{param_idx} });
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
