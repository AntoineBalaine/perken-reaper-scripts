const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const State = @import("statemachine.zig").State;
const c1 = @import("c1.zig");
const WidgetInput = @import("fx_ctrl_actions.zig").WidgetInput;
const globals = @import("globals.zig");
const roundButton = @import("components/widgets.zig").roundButton;
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
    const mode: @import("statemachine.zig").Mode = state.current_mode;
    const fx_state = &state.fx_ctrl;
    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });
    var rv: ?WidgetInput = null;
    const section_spacing = 40.0;
    // Input Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // try imgui.Text(.{ ctx, "Input" });

        { // First column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};

            if (try roundButton(.{ ctx, c1.CCs.Inpt_disp_on.getLabel(mode), "##" ++ @tagName(c1.CCs.Inpt_disp_on) })) {}
            try imgui.Dummy(.{ ctx, 0, knob_size * 2 });
            var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
            if (try Knobs.drawWidget(ctx, &gain_prm.normalized, c1.CCs.Inpt_Gain.getLabel(mode), .{})) {
                rv = .{ .cc = .Inpt_Gain, .value = gain_prm.normalized };
            }
        }
        try imgui.SameLine(.{ctx});

        // Second column (aligned right)
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            if (try roundButton(.{ ctx, c1.CCs.Inpt_disp_mode.getLabel(mode), "##" ++ @tagName(c1.CCs.Inpt_disp_on) })) {}
            {
                var hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
                if (try Knobs.drawWidget(ctx, &hicut_prm.normalized, c1.CCs.Inpt_HiCut.getLabel(mode), .{})) {
                    rv = .{ .cc = .Inpt_HiCut, .value = hicut_prm.normalized };
                }

                var locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
                if (try Knobs.drawWidget(ctx, &locut_prm.normalized, c1.CCs.Inpt_LoCut.getLabel(mode), .{})) {
                    rv = .{ .cc = .Inpt_LoCut, .value = locut_prm.normalized };
                }
            }

            if (try roundButton(.{ ctx, c1.CCs.Inpt_filt_to_comp.getLabel(mode), "##" ++ @tagName(c1.CCs.Inpt_filt_to_comp), null, null, .right })) {}
            if (try roundButton(.{ ctx, c1.CCs.Inpt_phase_inv.getLabel(mode), "##" ++ @tagName(c1.CCs.Inpt_phase_inv), null, null, .right })) {}
            if (try roundButton(.{ ctx, c1.CCs.Inpt_preset.getLabel(mode), "##" ++ @tagName(c1.CCs.Inpt_preset), null, null, .right })) {}
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    // Shape Section
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const shp_bypass = fx_state.values.get(.Shp_shape).?.button;
        const shp_bypass_val = shp_bypass;
        if (try roundButton(.{ ctx, c1.CCs.Shp_shape.getLabel(mode), "##" ++ @tagName(c1.CCs.Inpt_preset), null, null, .right })) {
            rv = .{ .cc = .Shp_shape, .value = if (shp_bypass_val) 0 else 1 };
        }

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                try imgui.Dummy(.{ ctx, 0, knob_size * 0.75 });
                var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
                if (try Knobs.drawWidget(ctx, &gate_prm.normalized, c1.CCs.Shp_Gate.getLabel(mode), .{})) {
                    rv = .{ .cc = .Shp_Gate, .value = gate_prm.normalized };
                }

                const hard_gate = fx_state.values.get(.Shp_hard_gate).?.button;
                const hard_gate_val = hard_gate;
                if (try roundButton(.{ ctx, c1.CCs.Shp_hard_gate.getLabel(mode), "##" ++ @tagName(c1.CCs.Shp_hard_gate), null, null, .below })) {
                    rv = .{ .cc = .Shp_hard_gate, .value = if (hard_gate_val) 0 else 1 };
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
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, c1.CCs.Shp_GateRelease.getLabel(mode), .{})) {
                    rv = .{ .cc = .Shp_GateRelease, .value = release_prm.normalized };
                }

                var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
                if (try Knobs.drawWidget(ctx, &sustain_prm.normalized, c1.CCs.Shp_sustain.getLabel(mode), .{})) {
                    rv = .{ .cc = .Shp_sustain, .value = sustain_prm.normalized };
                }

                var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
                if (try Knobs.drawWidget(ctx, &punch_prm.normalized, c1.CCs.Shp_Punch.getLabel(mode), .{})) {
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
        if (try roundButton(.{ ctx, c1.CCs.Eq_eq.getLabel(mode), "##" ++ @tagName(c1.CCs.Eq_eq), null, null, .right })) {
            rv = .{ .cc = .Eq_eq, .value = if (eq_bypass) 0 else 1 };
        }

        { // first column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                try imgui.Dummy(.{ ctx, knob_size / 2, knob_size / 2 });

                const lo_shape = fx_state.values.get(.Eq_lp_shape).?.button;
                if (try roundButton(.{ ctx, c1.CCs.Eq_lp_shape.getLabel(mode), "##" ++ @tagName(c1.CCs.Eq_lp_shape), null, null, .right })) {
                    rv = .{ .cc = .Eq_lp_shape, .value = if (lo_shape) 0 else 1 };
                }

                var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, c1.CCs.Eq_LoFrq.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
                }

                var logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
                if (try Knobs.drawWidget(ctx, &logain_prm.normalized, c1.CCs.Eq_LoGain.getLabel(mode), .{})) {
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
                if (try Knobs.drawWidget(ctx, &lomidq_prm.normalized, c1.CCs.Eq_LoMidQ.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_LoMidQ, .value = lomidq_prm.normalized };
                }

                var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, c1.CCs.Eq_LoMidFrq.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_LoMidFrq, .value = lomidfreq_prm.normalized };
                }

                var lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, c1.CCs.Eq_LoMidGain.getLabel(mode), .{})) {
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
                if (try Knobs.drawWidget(ctx, &himidq_prm.normalized, c1.CCs.Eq_HiMidQ.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_HiMidQ, .value = himidq_prm.normalized };
                }

                var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, c1.CCs.Eq_HiMidFrq.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_HiMidFrq, .value = himidfreq_prm.normalized };
                }

                var himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &himidgain_prm.normalized, c1.CCs.Eq_HiMidGain.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_HiMidGain, .value = himidgain_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        { // fourth column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                try imgui.Dummy(.{ ctx, knob_size / 2, knob_size / 2 });

                const hi_shape = fx_state.values.get(.Eq_hp_shape).?.button;
                if (try roundButton(.{ ctx, c1.CCs.Eq_hp_shape.getLabel(mode), "##" ++ @tagName(c1.CCs.Eq_hp_shape), null, null, .right })) {
                    rv = .{ .cc = .Eq_hp_shape, .value = if (hi_shape) 0 else 1 };
                }

                var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
                if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, c1.CCs.Eq_HiFrq.getLabel(mode), .{})) {
                    rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
                }

                var higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
                if (try Knobs.drawWidget(ctx, &higain_prm.normalized, c1.CCs.Eq_HiGain.getLabel(mode), .{})) {
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
        if (try roundButton(.{ ctx, c1.CCs.Comp_comp.getLabel(mode), "##" ++ @tagName(c1.CCs.Comp_comp), null, null, .right })) {
            rv = .{ .cc = .Comp_comp, .value = if (comp_bypass) 0 else 1 };
        }

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                try imgui.Dummy(.{ ctx, knob_size / 2, knob_size / 2 });

                var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
                if (try Knobs.drawWidget(ctx, &ratio_prm.normalized, c1.CCs.Comp_Ratio.getLabel(mode), .{})) {
                    rv = .{ .cc = .Comp_Ratio, .value = ratio_prm.normalized };
                }

                var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
                if (try Knobs.drawWidget(ctx, &drywet_prm.normalized, c1.CCs.Comp_DryWet.getLabel(mode), .{})) {
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
                if (try Knobs.drawWidget(ctx, &attack_prm.normalized, c1.CCs.Comp_Attack.getLabel(mode), .{})) {
                    rv = .{ .cc = .Comp_Attack, .value = attack_prm.normalized };
                }

                var release_prm = fx_state.values.get(.Comp_Release).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, c1.CCs.Comp_Release.getLabel(mode), .{})) {
                    rv = .{ .cc = .Comp_Release, .value = release_prm.normalized };
                }

                var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
                if (try Knobs.drawWidget(ctx, &thresh_prm.normalized, c1.CCs.Comp_Thresh.getLabel(mode), .{})) {
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

        // First column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            if (try roundButton(.{ ctx, c1.CCs.Tr_order.getLabel(mode), "##" ++ @tagName(c1.CCs.Tr_order), null, null, .right })) {}
            {
                var drive_prm = fx_state.values.get(.Out_Drive).?.param;
                if (try Knobs.drawWidget(ctx, &drive_prm.normalized, c1.CCs.Out_Drive.getLabel(mode), .{})) {
                    rv = .{ .cc = .Out_Drive, .value = drive_prm.normalized };
                }

                var char_prm = fx_state.values.get(.Out_DriveChar).?.param;
                if (try Knobs.drawWidget(ctx, &char_prm.normalized, c1.CCs.Out_DriveChar.getLabel(mode), .{})) {
                    rv = .{ .cc = .Out_DriveChar, .value = char_prm.normalized };
                }

                var pan_prm = fx_state.values.get(.Out_Pan).?.param;
                if (try Knobs.drawWidget(ctx, &pan_prm.normalized, c1.CCs.Out_Pan.getLabel(mode), .{})) {
                    rv = .{ .cc = .Out_Pan, .value = pan_prm.normalized };
                }
            }
        }
        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};

            if (try roundButton(.{ ctx, c1.CCs.Tr_ext_sidechain.getLabel(mode), "##" ++ @tagName(c1.CCs.Tr_ext_sidechain), null, null, .right })) {}
            {
                try imgui.Dummy(.{ ctx, knob_size * 2, knob_size * 2 });
                const solo = fx_state.values.get(.Out_solo).?.button;
                if (try roundButton(.{ ctx, c1.CCs.Out_solo.getLabel(mode), "##" ++ @tagName(c1.CCs.Out_solo), null, null, .below })) {
                    rv = .{ .cc = .Out_solo, .value = if (solo) 0 else 1 };
                }

                try imgui.SameLine(.{ctx});

                const mute = fx_state.values.get(.Out_mute).?.button;
                if (try roundButton(.{ ctx, c1.CCs.Out_mute.getLabel(mode), "##" ++ @tagName(c1.CCs.Out_mute), null, null, .below })) {
                    rv = .{ .cc = .Out_mute, .value = if (mute) 0 else 1 };
                }

                var vol_prm = fx_state.values.get(.Out_Vol).?.param;
                if (try Knobs.drawWidget(ctx, &vol_prm.normalized, c1.CCs.Out_Vol.getLabel(mode), .{})) {
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
