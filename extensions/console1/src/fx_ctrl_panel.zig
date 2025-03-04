const std = @import("std");
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

            const disp_on_label = c1.CCs.Inpt_disp_on.getLabel(mode);
            const disp_on_display_label: [:0]const u8 = disp_on_label orelse "-";
            const disp_on_disabled = (disp_on_label == null);
            if (try roundButton(.{ ctx, disp_on_display_label, "##" ++ @tagName(c1.CCs.Inpt_disp_on), null, null, null, disp_on_disabled })) {
                rv = .{ .cc = .Inpt_disp_on, .value = 1.0 };
            }
            try imgui.Dummy(.{ ctx, 0, knob_size * 2 });

            // Center-align the knob
            const gain_label = c1.CCs.Inpt_Gain.getLabel(mode);
            const gain_disabled = (gain_label == null);
            const gain_no_val_display = gain_disabled or mode != .fx_ctrl;
            const gain_display_label: [:0]const u8 = gain_label orelse "-";
            var offsets = [_]?f64{null};
            try getMaxLabelWidth(ctx, &[_][:0]const u8{gain_display_label}, &offsets);

            // Apply offset if needed
            if (offsets[0]) |offset| {
                try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
            }
            var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
            if (try Knobs.drawWidget(ctx, &gain_prm.normalized, gain_display_label, .{ .no_val_display = gain_no_val_display, .disabled = gain_disabled })) {
                rv = .{ .cc = .Inpt_Gain, .value = gain_prm.normalized };
            }
        }
        try imgui.SameLine(.{ctx});

        // Second column (aligned right)
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            const disp_mode_label = c1.CCs.Inpt_disp_mode.getLabel(mode);
            const disp_mode_display_label: [:0]const u8 = disp_mode_label orelse "-";
            const disp_mode_disabled = (disp_mode_label == null);
            if (try roundButton(.{ ctx, disp_mode_display_label, "##" ++ @tagName(c1.CCs.Inpt_disp_on), null, null, null, disp_mode_disabled })) {
                rv = .{ .cc = .Inpt_disp_mode, .value = 1.0 };
            }
            {
                // Calculate max width for this column's knobs
                const hicut_label = c1.CCs.Inpt_HiCut.getLabel(mode);
                const hicut_disabled = (hicut_label == null);
                const hicut_no_val_display = hicut_disabled or mode != .fx_ctrl;
                const hicut_display_label: [:0]const u8 = hicut_label orelse "-";
                const locut_label = c1.CCs.Inpt_LoCut.getLabel(mode);
                const locut_disabled = (locut_label == null);
                const locut_no_val_display = locut_disabled or mode != .fx_ctrl;
                const locut_display_label: [:0]const u8 = locut_label orelse "-";
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ hicut_display_label, locut_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
                if (try Knobs.drawWidget(ctx, &hicut_prm.normalized, hicut_display_label, .{ .no_val_display = hicut_no_val_display, .disabled = hicut_disabled })) {
                    rv = .{ .cc = .Inpt_HiCut, .value = hicut_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
                if (try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_display_label, .{ .no_val_display = locut_no_val_display, .disabled = locut_disabled })) {
                    rv = .{ .cc = .Inpt_LoCut, .value = locut_prm.normalized };
                }
            }

            const filt_to_comp_label = c1.CCs.Inpt_filt_to_comp.getLabel(mode);
            const filt_to_comp_display_label: [:0]const u8 = filt_to_comp_label orelse "-";
            const filt_to_comp_disabled = (filt_to_comp_label == null);
            if (try roundButton(.{ ctx, filt_to_comp_display_label, "##" ++ @tagName(c1.CCs.Inpt_filt_to_comp), null, null, .right, filt_to_comp_disabled })) {}
            const phase_inv_label = c1.CCs.Inpt_phase_inv.getLabel(mode);
            const phase_inv_display_label: [:0]const u8 = phase_inv_label orelse "-";
            const phase_inv_disabled = (phase_inv_label == null);
            if (try roundButton(.{ ctx, phase_inv_display_label, "##" ++ @tagName(c1.CCs.Inpt_phase_inv), null, null, .right, phase_inv_disabled })) {
                rv = .{ .cc = .Inpt_phase_inv, .value = 1.0 };
            }
            const preset_label = c1.CCs.Inpt_preset.getLabel(mode);
            const preset_display_label: [:0]const u8 = preset_label orelse "-";
            const preset_disabled = (preset_label == null);
            if (try roundButton(.{ ctx, preset_display_label, "##" ++ @tagName(c1.CCs.Inpt_preset), null, null, .right, preset_disabled })) {}
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
        const shp_shape_label = c1.CCs.Shp_shape.getLabel(mode);
        const shp_shape_display_label: [:0]const u8 = shp_shape_label orelse "-";
        const shp_shape_disabled = (shp_shape_label == null);
        if (try roundButton(.{ ctx, shp_shape_display_label, "##" ++ @tagName(c1.CCs.Inpt_preset), null, null, .right, shp_shape_disabled })) {
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
                const gate_disabled = (gate_label == null);
                const gate_no_val_display = gate_disabled or mode != .fx_ctrl;
                const gate_display_label: [:0]const u8 = gate_label orelse "-";
                var offsets = [_]?f64{null};
                try getMaxLabelWidth(ctx, &[_][:0]const u8{gate_display_label}, &offsets);

                // Apply offset if needed
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
                if (try Knobs.drawWidget(ctx, &gate_prm.normalized, gate_display_label, .{ .no_val_display = gate_no_val_display, .disabled = gate_disabled })) {
                    rv = .{ .cc = .Shp_Gate, .value = gate_prm.normalized };
                }

                const hard_gate = fx_state.values.get(.Shp_hard_gate).?.button;
                const hard_gate_val = hard_gate;
                const hard_gate_label = c1.CCs.Shp_hard_gate.getLabel(mode);
                const hard_gate_display_label: [:0]const u8 = hard_gate_label orelse "-";
                const hard_gate_disabled = (hard_gate_label == null);
                if (try roundButton(.{ ctx, hard_gate_display_label, "##" ++ @tagName(c1.CCs.Shp_hard_gate), null, null, .below, hard_gate_disabled })) {
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
                const release_disabled = (release_label == null);
                const release_no_val_display = release_disabled or mode != .fx_ctrl;
                const release_display_label: [:0]const u8 = release_label orelse "-";
                const sustain_label = c1.CCs.Shp_sustain.getLabel(mode);
                const sustain_disabled = (sustain_label == null);
                const sustain_no_val_display = sustain_disabled or mode != .fx_ctrl;
                const sustain_display_label: [:0]const u8 = sustain_label orelse "-";
                const punch_label = c1.CCs.Shp_Punch.getLabel(mode);
                const punch_disabled = (punch_label == null);
                const punch_no_val_display = punch_disabled or mode != .fx_ctrl;
                const punch_display_label: [:0]const u8 = punch_label orelse "-";
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ release_display_label, sustain_display_label, punch_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_display_label, .{ .no_val_display = release_no_val_display, .disabled = release_disabled })) {
                    rv = .{ .cc = .Shp_GateRelease, .value = release_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
                if (try Knobs.drawWidget(ctx, &sustain_prm.normalized, sustain_display_label, .{ .no_val_display = sustain_no_val_display, .disabled = sustain_disabled })) {
                    rv = .{ .cc = .Shp_sustain, .value = sustain_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
                if (try Knobs.drawWidget(ctx, &punch_prm.normalized, punch_display_label, .{ .no_val_display = punch_no_val_display, .disabled = punch_disabled })) {
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
        const eq_eq_label = c1.CCs.Eq_eq.getLabel(mode);
        const eq_eq_display_label: [:0]const u8 = eq_eq_label orelse "-";
        const eq_eq_disabled = (eq_eq_label == null);
        if (try roundButton(.{ ctx, eq_eq_display_label, "##" ++ @tagName(c1.CCs.Eq_eq), null, null, .right, eq_eq_disabled })) {
            rv = .{ .cc = .Eq_eq, .value = if (eq_bypass) 0 else 1 };
        }

        { // first column
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            {
                try imgui.Dummy(.{ ctx, knob_size / 2, knob_size / 2 });

                const lo_shape = fx_state.values.get(.Eq_lp_shape).?.button;
                const lp_shape_label = c1.CCs.Eq_lp_shape.getLabel(mode);
                const lp_shape_display_label: [:0]const u8 = lp_shape_label orelse "-";
                const lp_shape_disabled = (lp_shape_label == null);
                if (try roundButton(.{ ctx, lp_shape_display_label, "##" ++ @tagName(c1.CCs.Eq_lp_shape), null, null, .right, lp_shape_disabled })) {
                    rv = .{ .cc = .Eq_lp_shape, .value = if (lo_shape) 0 else 1 };
                }

                // Calculate max width for this column's knobs
                const lofreq_label = c1.CCs.Eq_LoFrq.getLabel(mode);
                const lofreq_disabled = (lofreq_label == null);
                const lofreq_no_val_display = lofreq_disabled or mode != .fx_ctrl;
                const lofreq_display_label: [:0]const u8 = lofreq_label orelse "-";
                const logain_label = c1.CCs.Eq_LoGain.getLabel(mode);
                const logain_disabled = (logain_label == null);
                const logain_no_val_display = logain_disabled or mode != .fx_ctrl;
                const logain_display_label: [:0]const u8 = logain_label orelse "-";
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ lofreq_display_label, logain_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_display_label, .{ .no_val_display = lofreq_no_val_display, .disabled = lofreq_disabled })) {
                    rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
                if (try Knobs.drawWidget(ctx, &logain_prm.normalized, logain_display_label, .{ .no_val_display = logain_no_val_display, .disabled = logain_disabled })) {
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
                const lomidq_disabled = (lomidq_label == null);
                const lomidq_no_val_display = lomidq_disabled or mode != .fx_ctrl;
                const lomidq_display_label: [:0]const u8 = lomidq_label orelse "-";
                const lomidfreq_label = c1.CCs.Eq_LoMidFrq.getLabel(mode);
                const lomidfreq_disabled = (lomidfreq_label == null);
                const lomidfreq_no_val_display = lomidfreq_disabled or mode != .fx_ctrl;
                const lomidfreq_display_label: [:0]const u8 = lomidfreq_label orelse "-";
                const lomidgain_label = c1.CCs.Eq_LoMidGain.getLabel(mode);
                const lomidgain_disabled = (lomidgain_label == null);
                const lomidgain_no_val_display = lomidgain_disabled or mode != .fx_ctrl;
                const lomidgain_display_label: [:0]const u8 = lomidgain_label orelse "-";
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ lomidq_display_label, lomidfreq_display_label, lomidgain_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &lomidq_prm.normalized, lomidq_display_label, .{ .no_val_display = lomidq_no_val_display, .disabled = lomidq_disabled })) {
                    rv = .{ .cc = .Eq_LoMidQ, .value = lomidq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, lomidfreq_display_label, .{ .no_val_display = lomidfreq_no_val_display, .disabled = lomidfreq_disabled })) {
                    rv = .{ .cc = .Eq_LoMidFrq, .value = lomidfreq_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, lomidgain_display_label, .{ .no_val_display = lomidgain_no_val_display, .disabled = lomidgain_disabled })) {
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
                const himidq_disabled = (himidq_label == null);
                const himidq_no_val_display = himidq_disabled or mode != .fx_ctrl;
                const himidq_display_label: [:0]const u8 = himidq_label orelse "-";
                const himidfreq_label = c1.CCs.Eq_HiMidFrq.getLabel(mode);
                const himidfreq_disabled = (himidfreq_label == null);
                const himidfreq_no_val_display = himidfreq_disabled or mode != .fx_ctrl;
                const himidfreq_display_label: [:0]const u8 = himidfreq_label orelse "-";
                const himidgain_label = c1.CCs.Eq_HiMidGain.getLabel(mode);
                const himidgain_disabled = (himidgain_label == null);
                const himidgain_no_val_display = himidgain_disabled or mode != .fx_ctrl;
                const himidgain_display_label: [:0]const u8 = himidgain_label orelse "-";
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ himidq_display_label, himidfreq_display_label, himidgain_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
                if (try Knobs.drawWidget(ctx, &himidq_prm.normalized, himidq_display_label, .{ .no_val_display = himidq_no_val_display, .disabled = himidq_disabled })) {
                    rv = .{ .cc = .Eq_HiMidQ, .value = himidq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
                if (try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, himidfreq_display_label, .{ .no_val_display = himidfreq_no_val_display, .disabled = himidfreq_disabled })) {
                    rv = .{ .cc = .Eq_HiMidFrq, .value = himidfreq_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
                if (try Knobs.drawWidget(ctx, &himidgain_prm.normalized, himidgain_display_label, .{ .no_val_display = himidgain_no_val_display, .disabled = himidgain_disabled })) {
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
                const hp_shape_label = c1.CCs.Eq_hp_shape.getLabel(mode);
                const hp_shape_display_label: [:0]const u8 = hp_shape_label orelse "-";
                const hp_shape_disabled = (hp_shape_label == null);
                if (try roundButton(.{ ctx, hp_shape_display_label, "##" ++ @tagName(c1.CCs.Eq_hp_shape), null, null, .right, hp_shape_disabled })) {
                    rv = .{ .cc = .Eq_hp_shape, .value = if (hi_shape) 0 else 1 };
                }

                // Calculate max width for this column's knobs
                const hifreq_label = c1.CCs.Eq_HiFrq.getLabel(mode);
                const hifreq_disabled = (hifreq_label == null);
                const hifreq_no_val_display = hifreq_disabled or mode != .fx_ctrl;
                const hifreq_display_label: [:0]const u8 = hifreq_label orelse "-";
                const higain_label = c1.CCs.Eq_HiGain.getLabel(mode);
                const higain_disabled = (higain_label == null);
                const higain_no_val_display = higain_disabled or mode != .fx_ctrl;
                const higain_display_label: [:0]const u8 = higain_label orelse "-";
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ hifreq_display_label, higain_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
                if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_display_label, .{ .no_val_display = hifreq_no_val_display, .disabled = hifreq_disabled })) {
                    rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
                if (try Knobs.drawWidget(ctx, &higain_prm.normalized, higain_display_label, .{ .no_val_display = higain_no_val_display, .disabled = higain_disabled })) {
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
        const comp_comp_label = c1.CCs.Comp_comp.getLabel(mode);
        const comp_comp_display_label: [:0]const u8 = comp_comp_label orelse "-";
        const comp_comp_disabled = (comp_comp_label == null);
        if (try roundButton(.{ ctx, comp_comp_display_label, "##" ++ @tagName(c1.CCs.Comp_comp), null, null, .right, comp_comp_disabled })) {
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
                const ratio_disabled = (ratio_label == null);
                const ratio_no_val_display = ratio_disabled or mode != .fx_ctrl;
                const ratio_display_label: [:0]const u8 = ratio_label orelse "-";
                const drywet_label = c1.CCs.Comp_DryWet.getLabel(mode);
                const drywet_disabled = (drywet_label == null);
                const drywet_no_val_display = drywet_disabled or mode != .fx_ctrl;
                const drywet_display_label: [:0]const u8 = drywet_label orelse "-";
                var offsets = [_]?f64{ null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ ratio_display_label, drywet_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
                if (try Knobs.drawWidget(ctx, &ratio_prm.normalized, ratio_display_label, .{ .no_val_display = ratio_no_val_display, .disabled = ratio_disabled })) {
                    rv = .{ .cc = .Comp_Ratio, .value = ratio_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
                if (try Knobs.drawWidget(ctx, &drywet_prm.normalized, drywet_display_label, .{ .no_val_display = drywet_no_val_display, .disabled = drywet_disabled })) {
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
                const attack_disabled = (attack_label == null);
                const attack_no_val_display = attack_disabled or mode != .fx_ctrl;
                const attack_display_label: [:0]const u8 = attack_label orelse "-";
                const release_label = c1.CCs.Comp_Release.getLabel(mode);
                const release_disabled = (release_label == null);
                const release_no_val_display = release_disabled or mode != .fx_ctrl;
                const release_display_label: [:0]const u8 = release_label orelse "-";
                const thresh_label = c1.CCs.Comp_Thresh.getLabel(mode);
                const thresh_disabled = (thresh_label == null);
                const thresh_no_val_display = thresh_disabled or mode != .fx_ctrl;
                const thresh_display_label: [:0]const u8 = thresh_label orelse "-";
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ attack_display_label, release_display_label, thresh_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var attack_prm = fx_state.values.get(.Comp_Attack).?.param;
                if (try Knobs.drawWidget(ctx, &attack_prm.normalized, attack_display_label, .{ .no_val_display = attack_no_val_display, .disabled = attack_disabled })) {
                    rv = .{ .cc = .Comp_Attack, .value = attack_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var release_prm = fx_state.values.get(.Comp_Release).?.param;
                if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_display_label, .{ .no_val_display = release_no_val_display, .disabled = release_disabled })) {
                    rv = .{ .cc = .Comp_Release, .value = release_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
                if (try Knobs.drawWidget(ctx, &thresh_prm.normalized, thresh_display_label, .{ .no_val_display = thresh_no_val_display, .disabled = thresh_disabled })) {
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
            const tr_order_label = c1.CCs.Tr_order.getLabel(mode);
            const tr_order_display_label: [:0]const u8 = tr_order_label orelse "-";
            const tr_order_disabled = (tr_order_label == null);
            if (try roundButton(.{ ctx, tr_order_display_label, "##" ++ @tagName(c1.CCs.Tr_order), null, null, .right, tr_order_disabled })) {}
            {
                // Calculate max width for this column's knobs
                const drive_label = c1.CCs.Out_Drive.getLabel(mode);
                const drive_disabled = (drive_label == null);
                const drive_no_val_display = drive_disabled or mode != .fx_ctrl;
                const drive_display_label: [:0]const u8 = drive_label orelse "-";
                const char_label = c1.CCs.Out_DriveChar.getLabel(mode);
                const char_disabled = (char_label == null);
                const char_no_val_display = char_disabled or mode != .fx_ctrl;
                const char_display_label: [:0]const u8 = char_label orelse "-";
                const pan_label = c1.CCs.Out_Pan.getLabel(mode);
                const pan_disabled = (pan_label == null);
                const pan_no_val_display = pan_disabled or mode != .fx_ctrl;
                const pan_display_label: [:0]const u8 = pan_label orelse "-";
                var offsets = [_]?f64{ null, null, null };
                try getMaxLabelWidth(ctx, &[_][:0]const u8{ drive_display_label, char_display_label, pan_display_label }, &offsets);

                // First knob
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var drive_prm = fx_state.values.get(.Out_Drive).?.param;
                if (try Knobs.drawWidget(ctx, &drive_prm.normalized, drive_display_label, .{ .no_val_display = drive_no_val_display, .disabled = drive_disabled })) {
                    rv = .{ .cc = .Out_Drive, .value = drive_prm.normalized };
                }

                // Second knob
                if (offsets[1]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var char_prm = fx_state.values.get(.Out_DriveChar).?.param;
                if (try Knobs.drawWidget(ctx, &char_prm.normalized, char_display_label, .{ .no_val_display = char_no_val_display, .disabled = char_disabled })) {
                    rv = .{ .cc = .Out_DriveChar, .value = char_prm.normalized };
                }

                // Third knob
                if (offsets[2]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var pan_prm = fx_state.values.get(.Out_Pan).?.param;
                if (try Knobs.drawWidget(ctx, &pan_prm.normalized, pan_display_label, .{ .no_val_display = pan_no_val_display, .disabled = pan_disabled })) {
                    rv = .{ .cc = .Out_Pan, .value = pan_prm.normalized };
                }
            }
        }
        try imgui.SameLine(.{ctx});

        // Second column
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};

            const ext_sidechain_label = c1.CCs.Tr_ext_sidechain.getLabel(mode);
            const ext_sidechain_display_label: [:0]const u8 = ext_sidechain_label orelse "-";
            const ext_sidechain_disabled = (ext_sidechain_label == null);
            if (try roundButton(.{ ctx, ext_sidechain_display_label, "##" ++ @tagName(c1.CCs.Tr_ext_sidechain), null, null, .right, ext_sidechain_disabled })) {}
            {
                try imgui.Dummy(.{ ctx, knob_size * 2, knob_size * 2 });
                const solo = fx_state.values.get(.Out_solo).?.button;
                const out_solo_label = c1.CCs.Out_solo.getLabel(mode);
                const out_solo_display_label: [:0]const u8 = out_solo_label orelse "-";
                const out_solo_disabled = (out_solo_label == null);
                if (try roundButton(.{ ctx, out_solo_display_label, "##" ++ @tagName(c1.CCs.Out_solo), null, null, .below, out_solo_disabled })) {
                    rv = .{ .cc = .Out_solo, .value = if (solo) 0 else 1 };
                }

                try imgui.SameLine(.{ctx});

                const mute = fx_state.values.get(.Out_mute).?.button;
                const out_mute_label = c1.CCs.Out_mute.getLabel(mode);
                const out_mute_display_label: [:0]const u8 = out_mute_label orelse "-";
                const out_mute_disabled = (out_mute_label == null);
                if (try roundButton(.{ ctx, out_mute_display_label, "##" ++ @tagName(c1.CCs.Out_mute), null, null, .below, out_mute_disabled })) {
                    rv = .{ .cc = .Out_mute, .value = if (mute) 0 else 1 };
                }

                // Center-align the volume knob
                const vol_label = c1.CCs.Out_Vol.getLabel(mode);
                const vol_disabled = (vol_label == null);
                const vol_no_val_display = vol_disabled or mode != .fx_ctrl;
                const vol_display_label: [:0]const u8 = vol_label orelse "-";
                var offsets = [_]?f64{null};
                try getMaxLabelWidth(ctx, &[_][:0]const u8{vol_display_label}, &offsets);

                // Apply offset if needed
                if (offsets[0]) |offset| {
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + offset });
                }
                var vol_prm = fx_state.values.get(.Out_Vol).?.param;
                if (try Knobs.drawWidget(ctx, &vol_prm.normalized, vol_display_label, .{ .no_val_display = vol_no_val_display, .disabled = vol_disabled })) {
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
