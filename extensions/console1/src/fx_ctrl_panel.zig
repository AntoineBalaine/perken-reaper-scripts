const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const c1 = @import("c1.zig");
const WidgetInput = @import("fx_ctrl_actions.zig").WidgetInput;
const Globals = @import("globals.zig").Globals;
const roundButton = @import("components/widgets.zig").roundButton;

/// Calculate the maximum width of a list of labels
fn getMaxLabelWidth(ctx: imgui.ContextPtr, labels: []const [:0]const u8) !f64 {
    var max_width: f64 = 0;
    var width: f64 = undefined;
    var height: f64 = undefined;

    for (labels) |label| {
        try imgui.CalcTextSize(.{ ctx, label, &width, &height });
        max_width = @max(max_width, width);
    }

    return max_width;
}

/// Center a widget based on its label width and the maximum width in its column
fn centerWidgetLabel(ctx: imgui.ContextPtr, label: [:0]const u8, max_width: f64) !void {
    var width: f64 = undefined;
    var height: f64 = undefined;

    try imgui.CalcTextSize(.{ ctx, label, &width, &height });

    // Calculate the offset to center the widget
    const offset = (max_width - width) / 2.0;
    if (offset > 0) {
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
    }
}
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

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, globals: *Globals) !?WidgetInput {
    const mode: @import("statemachine.zig").Mode = globals.state.current_mode;
    const fx_state = &globals.state.fx_ctrl;
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

            // Center-align the knob
            const gain_label = c1.CCs.Inpt_Gain.getLabel(mode);
            try centerWidgetLabel(ctx, gain_label, try getMaxLabelWidth(ctx, &[_][:0]const u8{gain_label}));

            var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
            if (try Knobs.drawWidget(ctx, &gain_prm.normalized, gain_label, .{})) {
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
                // Calculate max width for this column's knobs
                const hicut_label = c1.CCs.Inpt_HiCut.getLabel(mode);
                const locut_label = c1.CCs.Inpt_LoCut.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ hicut_label, locut_label });

                // First knob
                try centerWidgetLabel(ctx, hicut_label, max_width);
                var hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
                if (try Knobs.drawWidget(ctx, &hicut_prm.normalized, hicut_label, .{})) {
                    rv = .{ .cc = .Inpt_HiCut, .value = hicut_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, locut_label, max_width);
                var locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
                if (try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_label, .{})) {
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

                // Center-align the knob
                const gate_label = c1.CCs.Shp_Gate.getLabel(mode);
                try centerWidgetLabel(ctx, gate_label, try getMaxLabelWidth(ctx, &[_][:0]const u8{gate_label}));

                var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
                if (try Knobs.drawWidget(ctx, &gate_prm.normalized, gate_label, .{})) {
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
                // Calculate max width for this column's knobs
                const release_label = c1.CCs.Shp_GateRelease.getLabel(mode);
                const sustain_label = c1.CCs.Shp_sustain.getLabel(mode);
                const punch_label = c1.CCs.Shp_Punch.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ release_label, sustain_label, punch_label });

                // First knob
                try centerWidgetLabel(ctx, release_label, max_width);
                var release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label, .{})) {
                    rv = .{ .cc = .Shp_GateRelease, .value = release_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, sustain_label, max_width);
                var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
                if (try Knobs.drawWidget(ctx, &sustain_prm.normalized, sustain_label, .{})) {
                    rv = .{ .cc = .Shp_sustain, .value = sustain_prm.normalized };
                }

                // Third knob
                try centerWidgetLabel(ctx, punch_label, max_width);
                var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
                if (try Knobs.drawWidget(ctx, &punch_prm.normalized, punch_label, .{})) {
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

                // Calculate max width for this column's knobs
                const lofreq_label = c1.CCs.Eq_LoFrq.getLabel(mode);
                const logain_label = c1.CCs.Eq_LoGain.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ lofreq_label, logain_label });

                // First knob
                try centerWidgetLabel(ctx, lofreq_label, max_width);
                var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_label, .{})) {
                    rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, logain_label, max_width);
                var logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
                if (try Knobs.drawWidget(ctx, &logain_prm.normalized, logain_label, .{})) {
                    rv = .{ .cc = .Eq_LoGain, .value = logain_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        { // second col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                // Calculate max width for this column's knobs
                const lomidq_label = c1.CCs.Eq_LoMidQ.getLabel(mode);
                const lomidfreq_label = c1.CCs.Eq_LoMidFrq.getLabel(mode);
                const lomidgain_label = c1.CCs.Eq_LoMidGain.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ lomidq_label, lomidfreq_label, lomidgain_label });

                // First knob
                try centerWidgetLabel(ctx, lomidq_label, max_width);
                var lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &lomidq_prm.normalized, lomidq_label, .{})) {
                    rv = .{ .cc = .Eq_LoMidQ, .value = lomidq_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, lomidfreq_label, max_width);
                var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, lomidfreq_label, .{})) {
                    rv = .{ .cc = .Eq_LoMidFrq, .value = lomidfreq_prm.normalized };
                }

                // Third knob
                try centerWidgetLabel(ctx, lomidgain_label, max_width);
                var lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, lomidgain_label, .{})) {
                    rv = .{ .cc = .Eq_LoMidGain, .value = lomidgain_prm.normalized };
                }
            }
        }

        try imgui.SameLine(.{ctx});

        { // third col
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                // Calculate max width for this column's knobs
                const himidq_label = c1.CCs.Eq_HiMidQ.getLabel(mode);
                const himidfreq_label = c1.CCs.Eq_HiMidFrq.getLabel(mode);
                const himidgain_label = c1.CCs.Eq_HiMidGain.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ himidq_label, himidfreq_label, himidgain_label });

                // First knob
                try centerWidgetLabel(ctx, himidq_label, max_width);
                var himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &himidq_prm.normalized, himidq_label, .{})) {
                    rv = .{ .cc = .Eq_HiMidQ, .value = himidq_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, himidfreq_label, max_width);
                var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, himidfreq_label, .{})) {
                    rv = .{ .cc = .Eq_HiMidFrq, .value = himidfreq_prm.normalized };
                }

                // Third knob
                try centerWidgetLabel(ctx, himidgain_label, max_width);
                var himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &himidgain_prm.normalized, himidgain_label, .{})) {
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

                // Calculate max width for this column's knobs
                const hifreq_label = c1.CCs.Eq_HiFrq.getLabel(mode);
                const higain_label = c1.CCs.Eq_HiGain.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ hifreq_label, higain_label });

                // First knob
                try centerWidgetLabel(ctx, hifreq_label, max_width);
                var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
                if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_label, .{})) {
                    rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, higain_label, max_width);
                var higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
                if (try Knobs.drawWidget(ctx, &higain_prm.normalized, higain_label, .{})) {
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

                // Calculate max width for this column's knobs
                const ratio_label = c1.CCs.Comp_Ratio.getLabel(mode);
                const drywet_label = c1.CCs.Comp_DryWet.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ ratio_label, drywet_label });

                // First knob
                try centerWidgetLabel(ctx, ratio_label, max_width);
                var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
                if (try Knobs.drawWidget(ctx, &ratio_prm.normalized, ratio_label, .{})) {
                    rv = .{ .cc = .Comp_Ratio, .value = ratio_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, drywet_label, max_width);
                var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
                if (try Knobs.drawWidget(ctx, &drywet_prm.normalized, drywet_label, .{})) {
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
                // Calculate max width for this column's knobs
                const attack_label = c1.CCs.Comp_Attack.getLabel(mode);
                const release_label = c1.CCs.Comp_Release.getLabel(mode);
                const thresh_label = c1.CCs.Comp_Thresh.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ attack_label, release_label, thresh_label });

                // First knob
                try centerWidgetLabel(ctx, attack_label, max_width);
                var attack_prm = fx_state.values.get(.Comp_Attack).?.param;
                if (try Knobs.drawWidget(ctx, &attack_prm.normalized, attack_label, .{})) {
                    rv = .{ .cc = .Comp_Attack, .value = attack_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, release_label, max_width);
                var release_prm = fx_state.values.get(.Comp_Release).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label, .{})) {
                    rv = .{ .cc = .Comp_Release, .value = release_prm.normalized };
                }

                // Third knob
                try centerWidgetLabel(ctx, thresh_label, max_width);
                var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
                if (try Knobs.drawWidget(ctx, &thresh_prm.normalized, thresh_label, .{})) {
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
                // Calculate max width for this column's knobs
                const drive_label = c1.CCs.Out_Drive.getLabel(mode);
                const char_label = c1.CCs.Out_DriveChar.getLabel(mode);
                const pan_label = c1.CCs.Out_Pan.getLabel(mode);
                const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ drive_label, char_label, pan_label });

                // First knob
                try centerWidgetLabel(ctx, drive_label, max_width);
                var drive_prm = fx_state.values.get(.Out_Drive).?.param;
                if (try Knobs.drawWidget(ctx, &drive_prm.normalized, drive_label, .{})) {
                    rv = .{ .cc = .Out_Drive, .value = drive_prm.normalized };
                }

                // Second knob
                try centerWidgetLabel(ctx, char_label, max_width);
                var char_prm = fx_state.values.get(.Out_DriveChar).?.param;
                if (try Knobs.drawWidget(ctx, &char_prm.normalized, char_label, .{})) {
                    rv = .{ .cc = .Out_DriveChar, .value = char_prm.normalized };
                }

                // Third knob
                try centerWidgetLabel(ctx, pan_label, max_width);
                var pan_prm = fx_state.values.get(.Out_Pan).?.param;
                if (try Knobs.drawWidget(ctx, &pan_prm.normalized, pan_label, .{})) {
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

                // Center-align the volume knob
                const vol_label = c1.CCs.Out_Vol.getLabel(mode);
                try centerWidgetLabel(ctx, vol_label, try getMaxLabelWidth(ctx, &[_][:0]const u8{vol_label}));

                var vol_prm = fx_state.values.get(.Out_Vol).?.param;
                if (try Knobs.drawWidget(ctx, &vol_prm.normalized, vol_label, .{})) {
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
