const std = @import("std");
const mem = std.mem;
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const Knob = Knobs.Knob;
const Rectangle = @import("components/knob.zig").Rectangle;
const c1 = @import("c1.zig");
const WidgetInput = @import("fx_ctrl_actions.zig").WidgetInput;
const Globals = @import("globals.zig").Globals;
const widgets = @import("components/widgets.zig");
const roundButton = widgets.roundButton;
const vSeparator = widgets.vSeparator;
const section_spacing = @import("styles.zig").section_spacing;

/// Calculate the maximum width of a list of labels and calculate offsets
/// The offsets buffer will be filled with (max_width - width) / 2 for each label
/// or null if the label width equals the max width
fn getMaxLabelWidth(ctx: imgui.ContextPtr, labels: []const [:0]const u8, offsets: []?f64) !void {
    var max_width: f64 = 0;
    var width: f64 = undefined;
    var height: f64 = undefined;

    // First pass: calculate max width and store widths
    for (labels, 0..) |label, i| {
        try imgui.CalcTextSize(.{ ctx, label, &width, &height });
        max_width = @max(max_width, width);
        offsets[i] = width; // Store width temporarily
    }

    // Second pass: calculate offsets
    for (offsets, 0..) |width_opt, i| {
        const width_val = width_opt.?; // Safe to unwrap as we just stored values
        if (width_val == max_width) {
            offsets[i] = null; // No offset needed
        } else {
            offsets[i] = (max_width - width_val) / 2; // Calculate offset
        }
    }
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
            var offsets = [_]?f64{null};
            try getMaxLabelWidth(ctx, &[_][:0]const u8{gain_label}, &offsets);

            // Apply offset if needed
            if (offsets[0]) |offset| {
                try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
            }

            const gain_no_val_display = mem.eql(u8, gain_label, "-");
            var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
            if (try Knobs.drawWidget(ctx, &gain_prm.normalized, gain_label, .{ .no_val_display = gain_no_val_display })) {
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
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ hicut_label, locut_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const hicut_no_val_display = mem.eql(u8, hicut_label, "-");
                var hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
                if (try Knobs.drawWidget(ctx, &hicut_prm.normalized, hicut_label, .{ .no_val_display = hicut_no_val_display })) {
                    rv = .{ .cc = .Inpt_HiCut, .value = hicut_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const locut_no_val_display = mem.eql(u8, locut_label, "-");
                var locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
                if (try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_label, .{ .no_val_display = locut_no_val_display })) {
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
    // Add vertical separator after Input section
    try vSeparator(.{ ctx, 0xFFFFFFFF });

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
                var offsets = [_]?f64{null};
                try getMaxLabelWidth(ctx, &[_][:0]const u8{gate_label}, &offsets);

                // Apply offset if needed
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }

                const gate_no_val_display = mem.eql(u8, gate_label, "-");
                var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
                if (try Knobs.drawWidget(ctx, &gate_prm.normalized, gate_label, .{ .no_val_display = gate_no_val_display })) {
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
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ release_label, sustain_label, punch_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const release_no_val_display = mem.eql(u8, release_label, "-");
                var release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label, .{ .no_val_display = release_no_val_display })) {
                    rv = .{ .cc = .Shp_GateRelease, .value = release_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const sustain_no_val_display = mem.eql(u8, sustain_label, "-");
                var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
                if (try Knobs.drawWidget(ctx, &sustain_prm.normalized, sustain_label, .{ .no_val_display = sustain_no_val_display })) {
                    rv = .{ .cc = .Shp_sustain, .value = sustain_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const punch_no_val_display = mem.eql(u8, punch_label, "-");
                var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
                if (try Knobs.drawWidget(ctx, &punch_prm.normalized, punch_label, .{ .no_val_display = punch_no_val_display })) {
                    rv = .{ .cc = .Shp_Punch, .value = punch_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});

    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
    // Add vertical separator after Shape section
    try vSeparator(.{ ctx, 0xFFFFFFFF });

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
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ lofreq_label, logain_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const lofreq_no_val_display = mem.eql(u8, lofreq_label, "-");
                var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_label, .{ .no_val_display = lofreq_no_val_display })) {
                    rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const logain_no_val_display = mem.eql(u8, logain_label, "-");
                var logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
                if (try Knobs.drawWidget(ctx, &logain_prm.normalized, logain_label, .{ .no_val_display = logain_no_val_display })) {
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
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ lomidq_label, lomidfreq_label, lomidgain_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const lomidq_no_val_display = mem.eql(u8, lomidq_label, "-");
                var lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &lomidq_prm.normalized, lomidq_label, .{ .no_val_display = lomidq_no_val_display })) {
                    rv = .{ .cc = .Eq_LoMidQ, .value = lomidq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const lomidfreq_no_val_display = mem.eql(u8, lomidfreq_label, "-");
                var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, lomidfreq_label, .{ .no_val_display = lomidfreq_no_val_display })) {
                    rv = .{ .cc = .Eq_LoMidFrq, .value = lomidfreq_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const lomidgain_no_val_display = mem.eql(u8, lomidgain_label, "-");
                var lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, lomidgain_label, .{ .no_val_display = lomidgain_no_val_display })) {
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
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ himidq_label, himidfreq_label, himidgain_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const himidq_no_val_display = mem.eql(u8, himidq_label, "-");
                var himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &himidq_prm.normalized, himidq_label, .{ .no_val_display = himidq_no_val_display })) {
                    rv = .{ .cc = .Eq_HiMidQ, .value = himidq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const himidfreq_no_val_display = mem.eql(u8, himidfreq_label, "-");
                var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, himidfreq_label, .{ .no_val_display = himidfreq_no_val_display })) {
                    rv = .{ .cc = .Eq_HiMidFrq, .value = himidfreq_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const himidgain_no_val_display = mem.eql(u8, himidgain_label, "-");
                var himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &himidgain_prm.normalized, himidgain_label, .{ .no_val_display = himidgain_no_val_display })) {
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
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ hifreq_label, higain_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const hifreq_no_val_display = mem.eql(u8, hifreq_label, "-");
                var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
                if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_label, .{ .no_val_display = hifreq_no_val_display })) {
                    rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const higain_no_val_display = mem.eql(u8, higain_label, "-");
                var higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
                if (try Knobs.drawWidget(ctx, &higain_prm.normalized, higain_label, .{ .no_val_display = higain_no_val_display })) {
                    rv = .{ .cc = .Eq_HiGain, .value = higain_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});

    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
    try vSeparator(.{ ctx, 0xFFFFFFFF });

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
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ ratio_label, drywet_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const ratio_no_val_display = mem.eql(u8, ratio_label, "-");
                var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
                if (try Knobs.drawWidget(ctx, &ratio_prm.normalized, ratio_label, .{ .no_val_display = ratio_no_val_display })) {
                    rv = .{ .cc = .Comp_Ratio, .value = ratio_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const drywet_no_val_display = mem.eql(u8, drywet_label, "-");
                var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
                if (try Knobs.drawWidget(ctx, &drywet_prm.normalized, drywet_label, .{ .no_val_display = drywet_no_val_display })) {
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
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ attack_label, release_label, thresh_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const attack_no_val_display = mem.eql(u8, attack_label, "-");
                var attack_prm = fx_state.values.get(.Comp_Attack).?.param;
                if (try Knobs.drawWidget(ctx, &attack_prm.normalized, attack_label, .{ .no_val_display = attack_no_val_display })) {
                    rv = .{ .cc = .Comp_Attack, .value = attack_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const release_no_val_display = mem.eql(u8, release_label, "-");
                var release_prm = fx_state.values.get(.Comp_Release).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label, .{ .no_val_display = release_no_val_display })) {
                    rv = .{ .cc = .Comp_Release, .value = release_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const thresh_no_val_display = mem.eql(u8, thresh_label, "-");
                var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
                if (try Knobs.drawWidget(ctx, &thresh_prm.normalized, thresh_label, .{ .no_val_display = thresh_no_val_display })) {
                    rv = .{ .cc = .Comp_Thresh, .value = thresh_prm.normalized };
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});

    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
    // Add vertical separator after Compressor section
    try vSeparator(.{ ctx, 0xFFFFFFFF });

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
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ drive_label, char_label, pan_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const drive_no_val_display = mem.eql(u8, drive_label, "-");
                var drive_prm = fx_state.values.get(.Out_Drive).?.param;
                if (try Knobs.drawWidget(ctx, &drive_prm.normalized, drive_label, .{ .no_val_display = drive_no_val_display })) {
                    rv = .{ .cc = .Out_Drive, .value = drive_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const char_no_val_display = mem.eql(u8, char_label, "-");
                var char_prm = fx_state.values.get(.Out_DriveChar).?.param;
                if (try Knobs.drawWidget(ctx, &char_prm.normalized, char_label, .{ .no_val_display = char_no_val_display })) {
                    rv = .{ .cc = .Out_DriveChar, .value = char_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                const pan_no_val_display = mem.eql(u8, pan_label, "-");
                var pan_prm = fx_state.values.get(.Out_Pan).?.param;
                if (try Knobs.drawWidget(ctx, &pan_prm.normalized, pan_label, .{ .no_val_display = pan_no_val_display })) {
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
                var offsets = [_]?f64{null};
                try getMaxLabelWidth(ctx, &[_][:0]const u8{vol_label}, &offsets);

                // Apply offset if needed
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }

                const vol_no_val_display = mem.eql(u8, vol_label, "-");
                var vol_prm = fx_state.values.get(.Out_Vol).?.param;
                if (try Knobs.drawWidget(ctx, &vol_prm.normalized, vol_label, .{ .no_val_display = vol_no_val_display })) {
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
