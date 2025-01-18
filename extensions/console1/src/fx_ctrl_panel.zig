const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const State = @import("statemachine.zig").State;
const c1 = @import("c1.zig");
const WidgetInput = @import("fx_ctrl_actions.zig").WidgetInput;
const globals = @import("globals.zig");

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

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, state: *State) !?WidgetInput {
    if (globals.m_midi_in == null) try imgui.BeginDisabled(.{ctx});
    defer if (globals.m_midi_in == null) imgui.EndDisabled(.{ctx}) catch {};

    const fx_state = &state.fx_ctrl;
    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });
    var rv: ?WidgetInput = null;
    const section_spacing = 40.0;
    // Input Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        try imgui.Text(.{ ctx, "Input" });

        // First column
        var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
        if (try Knobs.drawWidget(ctx, &gain_prm.normalized, gain_prm.label, .{})) {
            rv = .{ .cc = .Inpt_Gain, .value = gain_prm.normalized };
        }
        try imgui.SameLine(.{ctx});

        // Second column (aligned right)
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
                if (try Knobs.drawWidget(ctx, &hicut_prm.normalized, hicut_prm.label, .{})) {
                    rv = .{ .cc = .Inpt_HiCut, .value = hicut_prm.normalized };
                }

                var locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
                if (try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_prm.label, .{})) {
                    rv = .{ .cc = .Inpt_LoCut, .value = locut_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Shape Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const shp_bypass = fx_state.values.get(.Shp_shape).?.button;
        var shp_bypass_val = shp_bypass;
        if (try imgui.Checkbox(.{ ctx, "SHAPE##shp", &shp_bypass_val })) {
            rv = .{ .cc = .Shp_shape, .value = if (shp_bypass_val) 1 else 0 };
        }

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
                if (try Knobs.drawWidget(ctx, &gate_prm.normalized, gate_prm.label, .{})) {
                    rv = .{ .cc = .Shp_Gate, .value = gate_prm.normalized };
                }

                const hard_gate = fx_state.values.get(.Shp_hard_gate).?.button;
                var hard_gate_val = hard_gate;
                if (try imgui.Checkbox(.{ ctx, "hard gate##hardgate", &hard_gate_val })) {
                    rv = .{ .cc = .Shp_hard_gate, .value = if (hard_gate_val) 1 else 0 };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_prm.label, .{})) {
                    rv = .{ .cc = .Shp_GateRelease, .value = release_prm.normalized };
                }

                var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
                if (try Knobs.drawWidget(ctx, &sustain_prm.normalized, sustain_prm.label, .{})) {
                    rv = .{ .cc = .Shp_sustain, .value = sustain_prm.normalized };
                }

                var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
                if (try Knobs.drawWidget(ctx, &punch_prm.normalized, punch_prm.label, .{})) {
                    rv = .{ .cc = .Shp_Punch, .value = punch_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // EQ Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const eq_bypass = fx_state.values.get(.Eq_eq).?.button;
        var eq_bypass_val = eq_bypass;
        if (try imgui.Checkbox(.{ ctx, "EQ##eq", &eq_bypass_val })) {
            rv = .{ .cc = .Eq_eq, .value = if (eq_bypass_val) 1 else 0 };
        }

        { // first column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const lo_shape = fx_state.values.get(.Eq_lp_shape).?.button;
                var lo_shape_val = lo_shape;
                if (try imgui.Checkbox(.{ ctx, "lo shape##eq_lo_shp", &lo_shape_val })) {
                    rv = .{ .cc = .Eq_lp_shape, .value = if (lo_shape_val) 1 else 0 };
                }

                var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_prm.label, .{})) {
                    rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
                }

                var logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
                if (try Knobs.drawWidget(ctx, &logain_prm.normalized, logain_prm.label, .{})) {
                    rv = .{ .cc = .Eq_LoGain, .value = logain_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        { // second col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &lomidq_prm.normalized, lomidq_prm.label, .{})) {
                    rv = .{ .cc = .Eq_LoMidQ, .value = lomidq_prm.normalized };
                }

                var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, lomidfreq_prm.label, .{})) {
                    rv = .{ .cc = .Eq_LoMidFrq, .value = lomidfreq_prm.normalized };
                }

                var lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, lomidgain_prm.label, .{})) {
                    rv = .{ .cc = .Eq_LoMidGain, .value = lomidgain_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        { // third col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &himidq_prm.normalized, himidq_prm.label, .{})) {
                    rv = .{ .cc = .Eq_HiMidQ, .value = himidq_prm.normalized };
                }

                var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, himidfreq_prm.label, .{})) {
                    rv = .{ .cc = .Eq_HiMidFrq, .value = himidfreq_prm.normalized };
                }

                var himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &himidgain_prm.normalized, himidgain_prm.label, .{})) {
                    rv = .{ .cc = .Eq_HiMidGain, .value = himidgain_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        { // fourth column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                const hi_shape = fx_state.values.get(.Eq_hp_shape).?.button;
                var hi_shape_val = hi_shape;
                if (try imgui.Checkbox(.{ ctx, "hi shape##eq_hi_shp", &hi_shape_val })) {
                    rv = .{ .cc = .Eq_hp_shape, .value = if (hi_shape_val) 1 else 0 };
                }

                var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
                if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_prm.label, .{})) {
                    rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
                }

                var higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
                if (try Knobs.drawWidget(ctx, &higain_prm.normalized, higain_prm.label, .{})) {
                    rv = .{ .cc = .Eq_HiGain, .value = higain_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Compressor Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        const comp_bypass = fx_state.values.get(.Comp_comp).?.button;
        var comp_bypass_val = comp_bypass;
        if (try imgui.Checkbox(.{ ctx, "Compressor##comp_byp", &comp_bypass_val })) {
            rv = .{ .cc = .Comp_comp, .value = if (comp_bypass_val) 1 else 0 };
        }

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
                if (try Knobs.drawWidget(ctx, &ratio_prm.normalized, ratio_prm.label, .{})) {
                    rv = .{ .cc = .Comp_Ratio, .value = ratio_prm.normalized };
                }

                var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
                if (try Knobs.drawWidget(ctx, &drywet_prm.normalized, drywet_prm.label, .{})) {
                    rv = .{ .cc = .Comp_DryWet, .value = drywet_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var attack_prm = fx_state.values.get(.Comp_Attack).?.param;
                if (try Knobs.drawWidget(ctx, &attack_prm.normalized, attack_prm.label, .{})) {
                    rv = .{ .cc = .Comp_Attack, .value = attack_prm.normalized };
                }

                var release_prm = fx_state.values.get(.Comp_Release).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_prm.label, .{})) {
                    rv = .{ .cc = .Comp_Release, .value = release_prm.normalized };
                }

                var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
                if (try Knobs.drawWidget(ctx, &thresh_prm.normalized, thresh_prm.label, .{})) {
                    rv = .{ .cc = .Comp_Thresh, .value = thresh_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Output Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        try imgui.Text(.{ ctx, "Output" });

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                var drive_prm = fx_state.values.get(.Out_Drive).?.param;
                if (try Knobs.drawWidget(ctx, &drive_prm.normalized, drive_prm.label, .{})) {
                    rv = .{ .cc = .Out_Drive, .value = drive_prm.normalized };
                }

                var char_prm = fx_state.values.get(.Out_DriveChar).?.param;
                if (try Knobs.drawWidget(ctx, &char_prm.normalized, char_prm.label, .{})) {
                    rv = .{ .cc = .Out_DriveChar, .value = char_prm.normalized };
                }

                var pan_prm = fx_state.values.get(.Out_Pan).?.param;
                if (try Knobs.drawWidget(ctx, &pan_prm.normalized, pan_prm.label, .{})) {
                    rv = .{ .cc = .Out_Pan, .value = pan_prm.normalized };
                }
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

                if (try imgui.Checkbox(.{ ctx, "solo##out_solo", &solo_val })) {
                    rv = .{ .cc = .Out_solo, .value = if (solo_val) 1 else 0 };
                }

                try imgui.SameLine(.{ctx});

                const mute = fx_state.values.get(.Out_mute).?.button;
                var mute_val = mute;
                if (try imgui.Checkbox(.{ ctx, "mute##out_mute", &mute_val })) {
                    rv = .{ .cc = .Out_mute, .value = if (mute_val) 1 else 0 };
                }

                var vol_prm = fx_state.values.get(.Out_Vol).?.param;
                if (try Knobs.drawWidget(ctx, &vol_prm.normalized, vol_prm.label, .{})) {
                    rv = .{ .cc = .Out_Vol, .value = vol_prm.normalized };
                }
            }
        }
    }

    if (globals.m_midi_in == null) {
        try imgui.SameLine(.{ctx});
        try imgui.TextColored(.{ ctx, 0xFF0000FF, "Console disconnected" });
    }
    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
