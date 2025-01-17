const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const State = @import("statemachine.zig").State;
const c1 = @import("c1.zig");
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

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, state: *State) !void {
    const fx_state = &state.fx_ctrl;
    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });

    // const knob_spacing = 10.0;
    const section_spacing = 40.0;
    // _ = section_spacing;
    // Input Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Text(.{ ctx, "Input" });

        // First column
        var gain_prm = &fx_state.values.getPtr(.Inpt_Gain).?.param;
        _ = try Knobs.drawWidget(ctx, &gain_prm.normalized, gain_prm.label, .{});
        try imgui.SameLine(.{ctx});

        // Second column (aligned right)
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var hicut_prm = &fx_state.values.getPtr(.Inpt_HiCut).?.param;
                _ = try Knobs.drawWidget(ctx, &hicut_prm.normalized, hicut_prm.label, .{});

                var locut_prm = &fx_state.values.getPtr(.Inpt_LoCut).?.param;
                _ = try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_prm.label, .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    // // Move cursor to start of next section
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Shape Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const shp_bypass = fx_state.values.getPtr(.Shp_shape).?.button;
        var shp_bypass_val = shp_bypass;
        _ = try imgui.Checkbox(.{ ctx, "SHAPE##shp", &shp_bypass_val });
        // try imgui.Text(.{ ctx, "Shape" });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var gate_prm = &fx_state.values.getPtr(.Shp_Gate).?.param;
                _ = try Knobs.drawWidget(ctx, &gate_prm.normalized, gate_prm.label, .{});

                // For the checkbox, we need the button state
                const hard_gate = fx_state.values.getPtr(.Shp_hard_gate).?.button;
                var hard_gate_val = hard_gate;
                _ = try imgui.Checkbox(.{ ctx, "hard gate##hardgate", &hard_gate_val });
            }
        }

        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var release_prm = &fx_state.values.getPtr(.Shp_GateRelease).?.param;
                _ = try Knobs.drawWidget(ctx, &release_prm.normalized, release_prm.label, .{});

                var sustain_prm = &fx_state.values.getPtr(.Shp_sustain).?.param;
                _ = try Knobs.drawWidget(ctx, &sustain_prm.normalized, sustain_prm.label, .{});

                var punch_prm = &fx_state.values.getPtr(.Shp_Punch).?.param;
                _ = try Knobs.drawWidget(ctx, &punch_prm.normalized, punch_prm.label, .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // // EQ Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const eq_bypass = fx_state.values.getPtr(.Eq_eq).?.button;
        var eq_bypass_val = eq_bypass;
        _ = try imgui.Checkbox(.{ ctx, "EQ##eq", &eq_bypass_val });
        // try imgui.SameLine(.{ctx});
        // try imgui.Text(.{ ctx, "EQ" });
        { // first column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const lo_shape = fx_state.values.getPtr(.Eq_lp_shape).?.button;
                var lo_shape_val = lo_shape;
                _ = try imgui.Checkbox(.{ ctx, "lo shape##eq_lo_shp", &lo_shape_val });

                var lofreq_prm = &fx_state.values.getPtr(.Eq_LoFrq).?.param;
                _ = try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_prm.label, .{});

                var logain_prm = &fx_state.values.getPtr(.Eq_LoGain).?.param;
                _ = try Knobs.drawWidget(ctx, &logain_prm.normalized, logain_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        { // second col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var lomidq_prm = &fx_state.values.getPtr(.Eq_LoMidQ).?.param;
                _ = try Knobs.drawWidget(ctx, &lomidq_prm.normalized, lomidq_prm.label, .{});

                var lomidfreq_prm = &fx_state.values.getPtr(.Eq_LoMidFrq).?.param;
                _ = try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, lomidfreq_prm.label, .{});

                var lomidgain_prm = &fx_state.values.getPtr(.Eq_LoMidGain).?.param;
                _ = try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, lomidgain_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        { // third col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var himidq_prm = &fx_state.values.getPtr(.Eq_HiMidQ).?.param;
                _ = try Knobs.drawWidget(ctx, &himidq_prm.normalized, himidq_prm.label, .{});

                var himidfreq_prm = &fx_state.values.getPtr(.Eq_HiMidFrq).?.param;
                _ = try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, himidfreq_prm.label, .{});

                var himidgain_prm = &fx_state.values.getPtr(.Eq_HiMidGain).?.param;
                _ = try Knobs.drawWidget(ctx, &himidgain_prm.normalized, himidgain_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        { // fourth column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const hi_shape = fx_state.values.getPtr(.Eq_hp_shape).?.button;
                var hi_shape_val = hi_shape;
                _ = try imgui.Checkbox(.{ ctx, "hi shape##eq_hi_shp", &hi_shape_val });

                var hifreq_prm = &fx_state.values.getPtr(.Eq_HiFrq).?.param;
                _ = try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_prm.label, .{});

                var higain_prm = &fx_state.values.getPtr(.Eq_HiGain).?.param;
                _ = try Knobs.drawWidget(ctx, &higain_prm.normalized, higain_prm.label, .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // // Compressor Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        const comp_bypass = fx_state.values.getPtr(.Comp_comp).?.button;
        var comp_bypass_val = comp_bypass;
        _ = try imgui.Checkbox(.{ ctx, "Compressor##comp_byp", &comp_bypass_val });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var ratio_prm = &fx_state.values.getPtr(.Comp_Ratio).?.param;
                _ = try Knobs.drawWidget(ctx, &ratio_prm.normalized, ratio_prm.label, .{});

                var drywet_prm = &fx_state.values.getPtr(.Comp_DryWet).?.param;
                _ = try Knobs.drawWidget(ctx, &drywet_prm.normalized, drywet_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var attack_prm = &fx_state.values.getPtr(.Comp_Attack).?.param;
                _ = try Knobs.drawWidget(ctx, &attack_prm.normalized, attack_prm.label, .{});

                var release_prm = &fx_state.values.getPtr(.Comp_Release).?.param;
                _ = try Knobs.drawWidget(ctx, &release_prm.normalized, release_prm.label, .{});

                var thresh_prm = &fx_state.values.getPtr(.Comp_Thresh).?.param;
                _ = try Knobs.drawWidget(ctx, &thresh_prm.normalized, thresh_prm.label, .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // // Output Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        try imgui.Text(.{ ctx, "Output" });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var drive_prm = &fx_state.values.getPtr(.Out_Drive).?.param;
                _ = try Knobs.drawWidget(ctx, &drive_prm.normalized, drive_prm.label, .{});

                var char_prm = &fx_state.values.getPtr(.Out_DriveChar).?.param;
                _ = try Knobs.drawWidget(ctx, &char_prm.normalized, char_prm.label, .{});

                var pan_prm = &fx_state.values.getPtr(.Out_Pan).?.param;
                _ = try Knobs.drawWidget(ctx, &pan_prm.normalized, pan_prm.label, .{});
            }
        }
        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const solo = fx_state.values.getPtr(.Out_solo).?.button;
                var solo_val = solo;
                _ = try imgui.Checkbox(.{ ctx, "solo##out_solo", &solo_val });

                try imgui.SameLine(.{ctx});

                const mute = fx_state.values.getPtr(.Out_mute).?.button;
                var mute_val = mute;
                _ = try imgui.Checkbox(.{ ctx, "mute##out_mute", &mute_val });

                var vol_prm = &fx_state.values.getPtr(.Out_Vol).?.param;
                _ = try Knobs.drawWidget(ctx, &vol_prm.normalized, vol_prm.label, .{});
            }
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
