const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const State = @import("statemachine.zig").State;
const c1 = @import("internals/c1.zig");

// Layout constants
// const section_spacing = 10.0;
const knob_size = 40.0;

var input_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Inpt_Gain), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Inpt_HiCut), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Inpt_LoCut), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
};

var shape_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Shp_Gate), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Shp_GateRelease), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Shp_hard_gate), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
};

var eq_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Eq_LoFrq), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Eq_LoGain), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Eq_LoMidFrq), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Eq_LoMidGain), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
};

var comp_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Comp_Thresh), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Comp_Ratio), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Comp_Attack), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Comp_Release), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
};

var out_knobs = [_]Knob{
    .{ .id = @tagName(c1.CCs.Out_Drive), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Out_Vol), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
    .{ .id = @tagName(c1.CCs.Out_Pan), .value = 0.5, .radius = knob_size / 2, .pos = .{ .x = 0, .y = 0 } },
};

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, state: *State) !void {
    _ = &state;
    if (try imgui.Begin(.{ ctx, "FX Control", null })) {
        defer imgui.End(.{ctx}) catch {};

        const draw_list = try imgui.GetWindowDrawList(.{ctx});

        // const knob_spacing = 10.0;

        // Input Section
        try imgui.Text(.{ ctx, "Input" });
        {
            for (&input_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                var pos_x: f64 = undefined;
                var pos_y: f64 = undefined;
                try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });
                const rect = Rectangle{
                    .min_x = pos_x,
                    .min_y = pos_y,
                    .max_x = pos_x + knob_size,
                    .max_y = pos_y + knob_size,
                };
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }

        try imgui.Spacing(.{ctx});
        try imgui.Separator(.{ctx});

        // Shape/Gate Section
        try imgui.Text(.{ ctx, "Shape" });
        {
            for (&shape_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                var pos_x: f64 = undefined;
                var pos_y: f64 = undefined;
                try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });
                const rect = Rectangle{
                    .min_x = pos_x,
                    .min_y = pos_y,
                    .max_x = pos_x + knob_size,
                    .max_y = pos_y + knob_size,
                };
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }

        // EQ Section
        try imgui.Text(.{ ctx, "EQ" });
        {
            for (&eq_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                var pos_x: f64 = undefined;
                var pos_y: f64 = undefined;
                try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });
                const rect = Rectangle{
                    .min_x = pos_x,
                    .min_y = pos_y,
                    .max_x = pos_x + knob_size,
                    .max_y = pos_y + knob_size,
                };
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }

        // Compressor Section
        try imgui.Text(.{ ctx, "Compressor" });
        {
            for (&comp_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                var pos_x: f64 = undefined;
                var pos_y: f64 = undefined;
                try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });
                const rect = Rectangle{
                    .min_x = pos_x,
                    .min_y = pos_y,
                    .max_x = pos_x + knob_size,
                    .max_y = pos_y + knob_size,
                };
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }

        // Output Section
        try imgui.Text(.{ ctx, "Output" });
        {
            for (&out_knobs, 0..) |*knob, i| {
                if (i > 0) try imgui.SameLine(.{ctx});
                var pos_x: f64 = undefined;
                var pos_y: f64 = undefined;
                try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });
                const rect = Rectangle{
                    .min_x = pos_x,
                    .min_y = pos_y,
                    .max_x = pos_x + knob_size,
                    .max_y = pos_y + knob_size,
                };
                try Knobs.drawWidget(ctx, draw_list, knob, rect, knob.id, .{});
            }
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
