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
        const gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
        var gain_val = gain_prm.normalized;
        _ = try Knobs.drawWidget(ctx, &gain_val, gain_prm.label, .{});
        try imgui.SameLine(.{ctx});

        // Second column (aligned right)
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
                var hicut_val = hicut_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &hicut_val, hicut_prm.label, .{});

                const locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
                var locut_val = locut_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &locut_val, locut_prm.label, .{});
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

        const shp_bypass = fx_state.values.get(.Shp_shape).?.button;
        var shp_bypass_val = shp_bypass;
        _ = try imgui.Checkbox(.{ ctx, "SHAPE##shp", &shp_bypass_val });
        // try imgui.Text(.{ ctx, "Shape" });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const gate_prm = fx_state.values.get(.Shp_Gate).?.param;
                var gate_val = gate_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &gate_val, gate_prm.label, .{});

                // For the checkbox, we need the button state
                const hard_gate = fx_state.values.get(.Shp_hard_gate).?.button;
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
                const release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
                var release_val = release_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &release_val, release_prm.label, .{});

                const punch_prm = fx_state.values.get(.Shp_Punch).?.param;
                var punch_val = punch_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &punch_val, punch_prm.label, .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // // EQ Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const eq_bypass = fx_state.values.get(.Eq_eq).?.button;
        var eq_bypass_val = eq_bypass;
        _ = try imgui.Checkbox(.{ ctx, "EQ##eq", &eq_bypass_val });
        // try imgui.SameLine(.{ctx});
        // try imgui.Text(.{ ctx, "EQ" });
        { // first column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const lo_shape = fx_state.values.get(.Eq_lp_shape).?.button;
                var lo_shape_val = lo_shape;
                _ = try imgui.Checkbox(.{ ctx, "lo shape##eq_lo_shp", &lo_shape_val });

                const lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
                var lofreq_val = lofreq_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &lofreq_val, lofreq_prm.label, .{});

                const logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
                var logain_val = logain_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &logain_val, logain_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        { // second col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
                var lomidq_val = lomidq_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &lomidq_val, lomidq_prm.label, .{});

                const lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
                var lomidfreq_val = lomidfreq_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &lomidfreq_val, lomidfreq_prm.label, .{});

                const lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
                var lomidgain_val = lomidgain_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &lomidgain_val, lomidgain_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        { // third col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
                var himidq_val = himidq_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &himidq_val, himidq_prm.label, .{});

                const himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
                var himidfreq_val = himidfreq_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &himidfreq_val, himidfreq_prm.label, .{});

                const himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
                var himidgain_val = himidgain_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &himidgain_val, himidgain_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        { // fourth column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const hi_shape = fx_state.values.get(.Eq_hp_shape).?.button;
                var hi_shape_val = hi_shape;
                _ = try imgui.Checkbox(.{ ctx, "hi shape##eq_hi_shp", &hi_shape_val });

                const hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
                var hifreq_val = hifreq_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &hifreq_val, hifreq_prm.label, .{});

                const higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
                var higain_val = higain_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &higain_val, higain_prm.label, .{});
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // // Compressor Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        const comp_bypass = fx_state.values.get(.Comp_comp).?.button;
        var comp_bypass_val = comp_bypass;
        _ = try imgui.Checkbox(.{ ctx, "Compressor##comp_byp", &comp_bypass_val });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
                var ratio_val = ratio_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &ratio_val, ratio_prm.label, .{});

                const drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
                var drywet_val = drywet_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &drywet_val, drywet_prm.label, .{});
            }
        }

        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
                var thresh_val = thresh_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &thresh_val, thresh_prm.label, .{});

                const attack_prm = fx_state.values.get(.Comp_Attack).?.param;
                var attack_val = attack_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &attack_val, attack_prm.label, .{});

                const release_prm = fx_state.values.get(.Comp_Release).?.param;
                var release_val = release_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &release_val, release_prm.label, .{});
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
                const drive_prm = fx_state.values.get(.Out_Drive).?.param;
                var drive_val = drive_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &drive_val, drive_prm.label, .{});

                const char_prm = fx_state.values.get(.Out_DriveChar).?.param;
                var char_val = char_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &char_val, char_prm.label, .{});

                const pan_prm = fx_state.values.get(.Out_Pan).?.param;
                var pan_val = pan_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &pan_val, pan_prm.label, .{});
            }
        }
        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const solo = fx_state.values.get(.Out_solo).?.button;
                var solo_val = solo;
                _ = try imgui.Checkbox(.{ ctx, "solo##out_solo", &solo_val });

                try imgui.SameLine(.{ctx});

                const mute = fx_state.values.get(.Out_mute).?.button;
                var mute_val = mute;
                _ = try imgui.Checkbox(.{ ctx, "mute##out_mute", &mute_val });

                const vol_prm = fx_state.values.get(.Out_Vol).?.param;
                var vol_val = vol_prm.normalized;
                _ = try Knobs.drawWidget(ctx, &vol_val, vol_prm.label, .{});
            }
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
