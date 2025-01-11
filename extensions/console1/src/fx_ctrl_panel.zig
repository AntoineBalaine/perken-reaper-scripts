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
// Module-level variables to hold knob values
// Input section
var input_gain: f64 = 0.5; // Inpt_Gain
var input_hicut: f64 = 0.5; // Inpt_HiCut
var input_locut: f64 = 0.5; // Inpt_LoCut

// Shape section
var shape_gate: f64 = 0.5; // Shp_Gate
var shape_release: f64 = 0.5; // Shp_GateRelease
var shape_hardgate: f64 = 0.5; // Shp_hard_gate

// EQ section
var eq_lofreq: f64 = 0.5; // Eq_LoFrq
var eq_logain: f64 = 0.5; // Eq_LoGain
var eq_lomidfreq: f64 = 0.5; // Eq_LoMidFrq
var eq_lomidgain: f64 = 0.5; // Eq_LoMidGain

// Compressor section
var comp_thresh: f64 = 0.5; // Comp_Thresh
var comp_ratio: f64 = 0.5; // Comp_Ratio
var comp_attack: f64 = 0.5; // Comp_Attack
var comp_release: f64 = 0.5; // Comp_Release

// Output section
var out_drive: f64 = 0.5; // Out_Drive
var out_vol: f64 = 0.5; // Out_Vol
var out_pan: f64 = 0.5; // Out_Pan

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

    // const knob_spacing = 10.0;
    const section_spacing = 40.0;

    // Input Section
    {
        try imgui.Text(.{ ctx, "Input" });

        // First column
        _ = try Knobs.drawWidget(ctx, &input_gain, "Gain", .{});

        // Second column (aligned right)
        const cursor_x = try imgui.GetCursorPosX(.{ctx});
        try imgui.SetCursorPosX(.{ ctx, cursor_x + knob_size + 20.0 }); // Move to second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                _ = try Knobs.drawWidget(ctx, &input_hicut, "HiCut", .{});
                _ = try Knobs.drawWidget(ctx, &input_locut, "LoCut", .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    // Move cursor to start of next section
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Shape Section
    {
        try imgui.Text(.{ ctx, "Shape" });

        // First column
        _ = try Knobs.drawWidget(ctx, &shape_gate, "Gate", .{});

        // Second column
        const cursor_x = try imgui.GetCursorPosX(.{ctx});
        try imgui.SetCursorPosX(.{ ctx, cursor_x + knob_size + 20.0 });
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                _ = try Knobs.drawWidget(ctx, &shape_release, "Release", .{});
                _ = try Knobs.drawWidget(ctx, &shape_hardgate, "Hard Gate", .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // EQ Section (single row, four knobs)
    {
        try imgui.Text(.{ ctx, "EQ" });
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                _ = try Knobs.drawWidget(ctx, &eq_lofreq, "Lo Freq", .{});
                try imgui.SameLine(.{ctx});
                _ = try Knobs.drawWidget(ctx, &eq_logain, "Lo Gain", .{});
                try imgui.SameLine(.{ctx});
                _ = try Knobs.drawWidget(ctx, &eq_lomidfreq, "Lo Mid Freq", .{});
                try imgui.SameLine(.{ctx});
                _ = try Knobs.drawWidget(ctx, &eq_lomidgain, "Lo Mid Gain", .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Compressor Section
    {
        try imgui.Text(.{ ctx, "Compressor" });

        // First column
        _ = try Knobs.drawWidget(ctx, &comp_ratio, "Ratio", .{});

        // Second column
        const cursor_x = try imgui.GetCursorPosX(.{ctx});
        try imgui.SetCursorPosX(.{ ctx, cursor_x + knob_size + 20.0 });
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                _ = try Knobs.drawWidget(ctx, &comp_thresh, "Threshold", .{});
                _ = try Knobs.drawWidget(ctx, &comp_attack, "Attack", .{});
                _ = try Knobs.drawWidget(ctx, &comp_release, "Release", .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Output Section
    {
        try imgui.Text(.{ ctx, "Output" });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                _ = try Knobs.drawWidget(ctx, &out_drive, "Drive", .{});
                _ = try Knobs.drawWidget(ctx, &out_pan, "Pan", .{});
            }
        }

        // Second column
        const cursor_x = try imgui.GetCursorPosX(.{ctx});
        try imgui.SetCursorPosX(.{ ctx, cursor_x + knob_size + 20.0 });
        _ = try Knobs.drawWidget(ctx, &out_vol, "Volume", .{});
    }
}

test {
    std.testing.refAllDecls(@This());
}
