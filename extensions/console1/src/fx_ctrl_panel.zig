const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const State = @import("statemachine.zig").State;
const c1 = @import("internals/c1.zig");
const ModuleLayout = @import("fx_ctrl_panel_layout.zig");
// Layout constants
// const section_spacing = 10.0;
const knob_size = 40.0;

var input_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Inpt_Gain), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Inpt_Gain) },
    .{ .id = @tagName(c1.CCs.Inpt_HiCut), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Inpt_HiCut) },
    .{ .id = @tagName(c1.CCs.Inpt_LoCut), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Inpt_LoCut) },
};

var shape_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Shp_Gate), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Shp_Gate) },
    .{ .id = @tagName(c1.CCs.Shp_GateRelease), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Shp_GateRelease) },
    .{ .id = @tagName(c1.CCs.Shp_hard_gate), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Shp_hard_gate) },
};

var eq_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Eq_LoFrq), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Eq_LoFrq) },
    .{ .id = @tagName(c1.CCs.Eq_LoGain), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Eq_LoGain) },
    .{ .id = @tagName(c1.CCs.Eq_LoMidFrq), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Eq_LoMidFrq) },
    .{ .id = @tagName(c1.CCs.Eq_LoMidGain), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Eq_LoMidGain) },
};

var comp_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Comp_Thresh), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Comp_Thresh) },
    .{ .id = @tagName(c1.CCs.Comp_Ratio), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Comp_Ratio) },
    .{ .id = @tagName(c1.CCs.Comp_Attack), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Comp_Attack) },
    .{ .id = @tagName(c1.CCs.Comp_Release), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Comp_Release) },
};

var out_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Out_Drive), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Out_Drive) },
    .{ .id = @tagName(c1.CCs.Out_Vol), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Out_Vol) },
    .{ .id = @tagName(c1.CCs.Out_Pan), .value = 0.5, .radius = knob_size / 2, .pos = ModuleLayout.getKnobPosition(.Out_Pan) },
};
pub fn drawFxControlPanel(ctx: imgui.ContextPtr, state: *State) !void {
    _ = &state;

    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });
    const draw_list = try imgui.GetWindowDrawList(.{ctx});

    // const knob_spacing = 10.0;

    // Input Section
    {
        try imgui.BeginGroup(.{ctx}); // Group the sections horizontally
        defer imgui.EndGroup(.{ctx}) catch {};
        try imgui.Text(.{ ctx, "Input" });
        {
            for (&input_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                const rect = try Knobs.getScreenWidgetRect(ctx, knob.pos, knob.radius, win_pos);
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }
        try imgui.SameLine(.{ctx});
    }

    try imgui.Spacing(.{ctx});
    try imgui.Separator(.{ctx});

    {
        try imgui.BeginGroup(.{ctx}); // Group the sections horizontally
        defer imgui.EndGroup(.{ctx}) catch {};
        // Shape/Gate Section
        try imgui.Text(.{ ctx, "Shape" });
        {
            for (&shape_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                const rect = try Knobs.getScreenWidgetRect(ctx, knob.pos, knob.radius, win_pos);
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }
        try imgui.SameLine(.{ctx});
    }

    {
        try imgui.BeginGroup(.{ctx}); // Group the sections horizontally
        defer imgui.EndGroup(.{ctx}) catch {};
        // EQ Section
        try imgui.Text(.{ ctx, "EQ" });
        {
            for (&eq_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                const rect = try Knobs.getScreenWidgetRect(ctx, knob.pos, knob.radius, win_pos);
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }
        try imgui.SameLine(.{ctx});
    }

    {
        try imgui.BeginGroup(.{ctx}); // Group the sections horizontally
        defer imgui.EndGroup(.{ctx}) catch {};
        // Compressor Section
        try imgui.Text(.{ ctx, "Compressor" });
        {
            for (&comp_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                const rect = try Knobs.getScreenWidgetRect(ctx, knob.pos, knob.radius, win_pos);
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }
        try imgui.SameLine(.{ctx});
    }

    {
        try imgui.BeginGroup(.{ctx}); // Group the sections horizontally
        defer imgui.EndGroup(.{ctx}) catch {};
        // Output Section
        try imgui.Text(.{ ctx, "Output" });
        {
            for (&out_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                const rect = try Knobs.getScreenWidgetRect(ctx, knob.pos, knob.radius, win_pos);
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }
        try imgui.SameLine(.{ctx});
    }
}

test {
    std.testing.refAllDecls(@This());
}
