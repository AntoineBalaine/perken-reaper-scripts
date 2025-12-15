const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Knobs = @import("components/knob.zig");
const c1 = @import("c1.zig");
const WidgetInput = @import("fx_ctrl_actions.zig").WidgetInput;
const Globals = @import("globals.zig").Globals;
const widgets = @import("components/widgets.zig");
const roundButton = widgets.roundButton;
const vSeparator = widgets.vSeparator;
const section_spacing = @import("styles.zig").section_spacing;
const Translations = @import("translations.zig");
const TranslationStore = Translations.TranslationStore;
const TranslationKey = Translations.TranslationKey;
const tr = @import("translations.zig").tr;
const Mode = @import("statemachine.zig").Mode;
const FxCtrlState = @import("fx_ctrl_state.zig").FxControlState;

/// Calculate the maximum width of a list of labels and calculate offsets
/// The offsets buffer will be filled with (max_width - width) / 2 for each label
/// or null if the label width equals the max width
/// FIXME: this shouldn’t be getting called at every frame
pub fn getMaxLabelWidth(ctx: imgui.ContextPtr, labels: []const [:0]const u8, offsets: []?f64) !f64 {
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
const KNOB_SIZE = 40.0;

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, globals: *Globals, translations: *TranslationStore) !?WidgetInput {
    const mode: Mode = globals.state.current_mode;
    const fx_state = &globals.state.fx_ctrl;
    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });
    var label_buf: [128:0]u8 = undefined;
    var id_buf: [64:0]u8 = undefined;
    var rv: ?WidgetInput = null;
    if (try inputPanel(ctx, mode, fx_state, translations, &label_buf, &id_buf)) |input_rv| {
        rv = input_rv;
    }
    try sectional(ctx);
    // Gate Module
    if (try gatePanel(ctx, mode, fx_state, translations, &label_buf, &id_buf)) |gate_rv| {
        rv = gate_rv;
    }
    try sectional(ctx);
    // EQ Module
    if (try eqPanel(ctx, mode, fx_state, translations, &label_buf, &id_buf)) |eq_rv| {
        rv = eq_rv;
    }
    try sectional(ctx);
    // Compressor Module
    if (try compPanel(ctx, mode, fx_state, translations, &label_buf, &id_buf)) |comp_rv| {
        rv = comp_rv;
    }
    try sectional(ctx);
    // Output Module
    if (try outputPanel(ctx, mode, fx_state, translations, &label_buf, &id_buf)) |output_rv| {
        rv = output_rv;
    }

    if (globals.m_midi_in == null) {
        try imgui.SameLine(.{ctx});
        try imgui.TextColored(.{ ctx, 0xFF0000FF, tr(translations, .fx_ctrl_disconnected) });
    }
    return rv;
}

pub fn sectional(ctx: imgui.ContextPtr) !void {
    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
    try vSeparator(.{ ctx, 0xFFFFFFFF });
    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
}

fn inputPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, translations: *TranslationStore, label_buf: *[128:0]u8, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    // try imgui.Text(.{ ctx, "Input" });

    { // First column
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const disp_on_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_disp_on,
            .transport => .trsprt_Inpt_disp_on,
            else => null,
        };
        const disp_on_label = if (disp_on_key) |key| tr(translations, key) else null;
        const disp_on_display_label: [:0]const u8 = disp_on_label orelse "-";
        const disp_on_disabled = (disp_on_label == null);
        if (try roundButton(.{ ctx, disp_on_display_label, "##" ++ @tagName(c1.CCs.Inpt_disp_on), null, null, null, disp_on_disabled })) {
            rv = .{ .cc = .Inpt_disp_on, .value = 1.0 };
        }
        try imgui.Dummy(.{ ctx, 0, KNOB_SIZE * 2 });

        // Center-align the knob
        const gain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_Gain,
            else => null,
        };
        const gain_label = if (gain_key) |key| tr(translations, key) else null;
        const gain_disabled = (gain_label == null);
        const gain_no_val_display = gain_disabled or mode != .fx_ctrl;
        const label_id = Knobs.LabelId{
            .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{gain_label orelse "-"}),
            .id = try std.fmt.bufPrintZ(id_buf, "Inpt_Gain", .{}),
        };
        var offsets = [_]?f64{null};
        const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{label_id.label}, &offsets);

        // Apply offset if needed
        var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
        if (try Knobs.drawWidget(ctx, &gain_prm.normalized, label_id, .{ .no_val_display = gain_no_val_display, .disabled = gain_disabled }, max_width)) {
            rv = .{ .cc = .Inpt_Gain, .value = gain_prm.normalized };
        }
    }
    try imgui.SameLine(.{ctx});

    // Second column (aligned right)
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        const disp_mode_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_disp_mode,
            .transport => .trsprt_Inpt_disp_mode,
            else => null,
        };
        const disp_mode_label = if (disp_mode_key) |key| tr(translations, key) else null;
        const disp_mode_display_label: [:0]const u8 = disp_mode_label orelse "-";
        const disp_mode_disabled = (disp_mode_label == null);
        if (try roundButton(.{ ctx, disp_mode_display_label, "##" ++ @tagName(c1.CCs.Inpt_disp_mode), null, null, null, disp_mode_disabled })) {
            rv = .{ .cc = .Inpt_disp_mode, .value = 1.0 };
        }
        {
            // Calculate max width for this column's knobs
            const hicut_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Inpt_HiCut,
                .transport => .trsprt_Inpt_HiCut,
                else => null,
            };
            const hicut_label = if (hicut_key) |key| tr(translations, key) else null;
            const hicut_disabled = (hicut_label == null);
            const hicut_no_val_display = hicut_disabled or mode != .fx_ctrl;
            const hicut_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{hicut_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Inpt_HiCut", .{}),
            };

            const locut_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Inpt_LoCut,
                else => null,
            };
            const locut_label = if (locut_key) |key| tr(translations, key) else null;
            const locut_disabled = (locut_label == null);
            const locut_no_val_display = locut_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const locut_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{locut_label orelse "-"}),
                .id = "Inpt_LoCut",
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ hicut_label_id.label, locut_label_id.label }, &offsets);

            // First knob
            var hicut_prm = fx_state.values.get(.Inpt_HiCut).?.param;
            if (try Knobs.drawWidget(ctx, &hicut_prm.normalized, hicut_label_id, .{ .no_val_display = hicut_no_val_display, .disabled = hicut_disabled }, max_width)) {
                rv = .{ .cc = .Inpt_HiCut, .value = hicut_prm.normalized };
            }

            // Second knob
            var locut_prm = fx_state.values.get(.Inpt_LoCut).?.param;
            if (try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_label_id, .{ .no_val_display = locut_no_val_display, .disabled = locut_disabled }, max_width)) {
                rv = .{ .cc = .Inpt_LoCut, .value = locut_prm.normalized };
            }
        }

        const filt_to_comp_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_filt_to_comp,
            else => null,
        };
        const filt_to_comp_label = if (filt_to_comp_key) |key| tr(translations, key) else null;
        const filt_to_comp_display_label: [:0]const u8 = filt_to_comp_label orelse "-";
        const filt_to_comp_disabled = (filt_to_comp_label == null);
        if (try roundButton(.{ ctx, filt_to_comp_display_label, "##" ++ @tagName(c1.CCs.Inpt_filt_to_comp), null, null, .right, filt_to_comp_disabled })) {}

        const phase_inv_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_phase_inv,
            else => null,
        };
        const phase_inv_label = if (phase_inv_key) |key| tr(translations, key) else null;
        const phase_inv_display_label: [:0]const u8 = phase_inv_label orelse "-";
        const phase_inv_disabled = (phase_inv_label == null);
        if (try roundButton(.{ ctx, phase_inv_display_label, "##" ++ @tagName(c1.CCs.Inpt_phase_inv), null, null, .right, phase_inv_disabled })) {
            rv = .{ .cc = .Inpt_phase_inv, .value = 1.0 };
        }

        const preset_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Inpt_preset,
            else => null,
        };
        const preset_label = if (preset_key) |key| tr(translations, key) else null;
        const preset_display_label: [:0]const u8 = preset_label orelse "-";
        const preset_disabled = (preset_label == null);
        if (try roundButton(.{ ctx, preset_display_label, "##" ++ @tagName(c1.CCs.Inpt_preset), null, null, .right, preset_disabled })) {
            rv = .{ .cc = .Inpt_preset, .value = 1.0 };
        }
    }

    return rv;
}

fn gatePanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, translations: *TranslationStore, label_buf: *[128:0]u8, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    const shp_bypass = fx_state.values.get(.Shp_shape).?.button;
    const shp_bypass_val = shp_bypass;
    const shp_shape_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Shp_shape,
        else => null,
    };
    const shp_shape_label = if (shp_shape_key) |key| tr(translations, key) else null;
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
            try imgui.Dummy(.{ ctx, 0, KNOB_SIZE * 0.75 });

            // Center-align the knob
            const gate_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Shp_Gate,
                else => null,
            };
            const gate_label = if (gate_key) |key| tr(translations, key) else null;
            const gate_disabled = (gate_label == null);
            const gate_no_val_display = gate_disabled or mode != .fx_ctrl;
            const label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{gate_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Shp_Gate", .{}),
            };
            var offsets = [_]?f64{null};
            _ = try getMaxLabelWidth(ctx, &[_][:0]const u8{label_id.label}, &offsets);

            // Apply offset if needed
            var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
            if (try Knobs.drawWidget(ctx, &gate_prm.normalized, label_id, .{ .no_val_display = gate_no_val_display, .disabled = gate_disabled }, null)) {
                rv = .{ .cc = .Shp_Gate, .value = gate_prm.normalized };
            }

            const hard_gate = fx_state.values.get(.Shp_hard_gate).?.button;
            const hard_gate_val = hard_gate;
            const hard_gate_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Shp_hard_gate,
                else => null,
            };
            const hard_gate_label = if (hard_gate_key) |key| tr(translations, key) else null;
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
            const release_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Shp_GateRelease,
                else => null,
            };
            const release_label = if (release_key) |key| tr(translations, key) else null;
            const release_disabled = (release_label == null);
            const release_no_val_display = release_disabled or mode != .fx_ctrl;
            const release_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{release_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Shp_GateRelease", .{}),
            };

            const sustain_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Shp_sustain,
                else => null,
            };
            const sustain_label = if (sustain_key) |key| tr(translations, key) else null;
            const sustain_disabled = (sustain_label == null);
            const sustain_no_val_display = sustain_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const sustain_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{sustain_label orelse "-"}),
                .id = "Shp_sustain",
            };

            const punch_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Shp_Punch,
                else => null,
            };
            const punch_label = if (punch_key) |key| tr(translations, key) else null;
            const punch_disabled = (punch_label == null);
            const punch_no_val_display = punch_disabled or mode != .fx_ctrl;
            var label_buf3: [128:0]u8 = undefined;
            const punch_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf3, "{s}", .{punch_label orelse "-"}),
                .id = "Shp_Punch",
            };
            var offsets = [_]?f64{ null, null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ release_label_id.label, sustain_label_id.label, punch_label_id.label }, &offsets);

            // First knob
            var release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
            if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label_id, .{ .no_val_display = release_no_val_display, .disabled = release_disabled }, max_width)) {
                rv = .{ .cc = .Shp_GateRelease, .value = release_prm.normalized };
            }

            // Second knob
            var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
            if (try Knobs.drawWidget(ctx, &sustain_prm.normalized, sustain_label_id, .{ .no_val_display = sustain_no_val_display, .disabled = sustain_disabled }, max_width)) {
                rv = .{ .cc = .Shp_sustain, .value = sustain_prm.normalized };
            }

            // Third knob
            var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
            if (try Knobs.drawWidget(ctx, &punch_prm.normalized, punch_label_id, .{ .no_val_display = punch_no_val_display, .disabled = punch_disabled }, max_width)) {
                rv = .{ .cc = .Shp_Punch, .value = punch_prm.normalized };
            }
        }
    }

    return rv;
}

fn eqPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, translations: *TranslationStore, label_buf: *[128:0]u8, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    const eq_bypass = fx_state.values.get(.Eq_eq).?.button;
    const eq_eq_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Eq_eq,
        .transport => .trsprt_Eq_eq,
        else => null,
    };
    const eq_eq_label = if (eq_eq_key) |key| tr(translations, key) else null;
    const eq_eq_display_label: [:0]const u8 = eq_eq_label orelse "-";
    const eq_eq_disabled = (eq_eq_label == null);
    if (try roundButton(.{ ctx, eq_eq_display_label, "##" ++ @tagName(c1.CCs.Eq_eq), null, null, .right, eq_eq_disabled })) {
        rv = .{ .cc = .Eq_eq, .value = if (eq_bypass) 0 else 1 };
    }

    { // first column
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE / 2, KNOB_SIZE / 2 });

            const lo_shape = fx_state.values.get(.Eq_lp_shape).?.button;
            const lp_shape_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_lp_shape,
                else => null,
            };
            const lp_shape_label = if (lp_shape_key) |key| tr(translations, key) else null;
            const lp_shape_display_label: [:0]const u8 = lp_shape_label orelse "-";
            const lp_shape_disabled = (lp_shape_label == null);
            if (try roundButton(.{ ctx, lp_shape_display_label, "##" ++ @tagName(c1.CCs.Eq_lp_shape), null, null, .right, lp_shape_disabled })) {
                rv = .{ .cc = .Eq_lp_shape, .value = if (lo_shape) 0 else 1 };
            }

            // Calculate max width for this column's knobs
            const lofreq_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_LoFrq,
                else => null,
            };
            const lofreq_label = if (lofreq_key) |key| tr(translations, key) else null;
            const lofreq_disabled = (lofreq_label == null);
            const lofreq_no_val_display = lofreq_disabled or mode != .fx_ctrl;
            const lofreq_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{lofreq_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_LoFrq", .{}),
            };

            const logain_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_LoGain,
                else => null,
            };
            const logain_label = if (logain_key) |key| tr(translations, key) else null;
            const logain_disabled = (logain_label == null);
            const logain_no_val_display = logain_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const logain_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{logain_label orelse "-"}),
                .id = "Eq_LoGain",
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ lofreq_label_id.label, logain_label_id.label }, &offsets);

            // First knob
            var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
            if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_label_id, .{ .no_val_display = lofreq_no_val_display, .disabled = lofreq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
            }

            // Second knob
            var logain_prm = fx_state.values.get(.Eq_LoGain).?.param;
            if (try Knobs.drawWidget(ctx, &logain_prm.normalized, logain_label_id, .{ .no_val_display = logain_no_val_display, .disabled = logain_disabled }, max_width)) {
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
            const lomidq_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_LoMidQ,
                else => null,
            };
            const lomidq_label = if (lomidq_key) |key| tr(translations, key) else null;
            const lomidq_disabled = (lomidq_label == null);
            const lomidq_no_val_display = lomidq_disabled or mode != .fx_ctrl;
            const lomidq_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{lomidq_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_LoMidQ", .{}),
            };

            const lomidfreq_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_LoMidFrq,
                else => null,
            };
            const lomidfreq_label = if (lomidfreq_key) |key| tr(translations, key) else null;
            const lomidfreq_disabled = (lomidfreq_label == null);
            const lomidfreq_no_val_display = lomidfreq_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const lomidfreq_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{lomidfreq_label orelse "-"}),
                .id = "Eq_LoMidFrq",
            };

            const lomidgain_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_LoMidGain,
                else => null,
            };
            const lomidgain_label = if (lomidgain_key) |key| tr(translations, key) else null;
            const lomidgain_disabled = (lomidgain_label == null);
            const lomidgain_no_val_display = lomidgain_disabled or mode != .fx_ctrl;
            var label_buf3: [128:0]u8 = undefined;
            const lomidgain_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf3, "{s}", .{lomidgain_label orelse "-"}),
                .id = "Eq_LoMidGain",
            };
            var offsets = [_]?f64{ null, null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ lomidq_label_id.label, lomidfreq_label_id.label, lomidgain_label_id.label }, &offsets);

            // First knob
            var lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
            if (try Knobs.drawWidget(ctx, &lomidq_prm.normalized, lomidq_label_id, .{ .no_val_display = lomidq_no_val_display, .disabled = lomidq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_LoMidQ, .value = lomidq_prm.normalized };
            }

            // Second knob
            var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
            if (try Knobs.drawWidget(ctx, &lomidfreq_prm.normalized, lomidfreq_label_id, .{ .no_val_display = lomidfreq_no_val_display, .disabled = lomidfreq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_LoMidFrq, .value = lomidfreq_prm.normalized };
            }

            // Third knob
            var lomidgain_prm = fx_state.values.get(.Eq_LoMidGain).?.param;
            if (try Knobs.drawWidget(ctx, &lomidgain_prm.normalized, lomidgain_label_id, .{ .no_val_display = lomidgain_no_val_display, .disabled = lomidgain_disabled }, max_width)) {
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
            const himidq_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_HiMidQ,
                else => null,
            };
            const himidq_label = if (himidq_key) |key| tr(translations, key) else null;
            const himidq_disabled = (himidq_label == null);
            const himidq_no_val_display = himidq_disabled or mode != .fx_ctrl;
            const himidq_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{himidq_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_HiMidQ", .{}),
            };

            const himidfreq_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_HiMidFrq,
                else => null,
            };
            const himidfreq_label = if (himidfreq_key) |key| tr(translations, key) else null;
            const himidfreq_disabled = (himidfreq_label == null);
            const himidfreq_no_val_display = himidfreq_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const himidfreq_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{himidfreq_label orelse "-"}),
                .id = "Eq_HiMidFrq",
            };

            const himidgain_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_HiMidGain,
                else => null,
            };
            const himidgain_label = if (himidgain_key) |key| tr(translations, key) else null;
            const himidgain_disabled = (himidgain_label == null);
            const himidgain_no_val_display = himidgain_disabled or mode != .fx_ctrl;
            var label_buf3: [128:0]u8 = undefined;
            const himidgain_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf3, "{s}", .{himidgain_label orelse "-"}),
                .id = "Eq_HiMidGain",
            };
            var offsets = [_]?f64{ null, null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ himidq_label_id.label, himidfreq_label_id.label, himidgain_label_id.label }, &offsets);

            // First knob
            var himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
            if (try Knobs.drawWidget(ctx, &himidq_prm.normalized, himidq_label_id, .{ .no_val_display = himidq_no_val_display, .disabled = himidq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiMidQ, .value = himidq_prm.normalized };
            }

            // Second knob
            var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
            if (try Knobs.drawWidget(ctx, &himidfreq_prm.normalized, himidfreq_label_id, .{ .no_val_display = himidfreq_no_val_display, .disabled = himidfreq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiMidFrq, .value = himidfreq_prm.normalized };
            }

            // Third knob
            var himidgain_prm = fx_state.values.get(.Eq_HiMidGain).?.param;
            if (try Knobs.drawWidget(ctx, &himidgain_prm.normalized, himidgain_label_id, .{ .no_val_display = himidgain_no_val_display, .disabled = himidgain_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiMidGain, .value = himidgain_prm.normalized };
            }
        }
    }

    try imgui.SameLine(.{ctx});

    { // fourth column
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE / 2, KNOB_SIZE / 2 });

            const hi_shape = fx_state.values.get(.Eq_hp_shape).?.button;
            const hp_shape_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_hp_shape,
                else => null,
            };
            const hp_shape_label = if (hp_shape_key) |key| tr(translations, key) else null;
            const hp_shape_display_label: [:0]const u8 = hp_shape_label orelse "-";
            const hp_shape_disabled = (hp_shape_label == null);
            if (try roundButton(.{ ctx, hp_shape_display_label, "##" ++ @tagName(c1.CCs.Eq_hp_shape), null, null, .right, hp_shape_disabled })) {
                rv = .{ .cc = .Eq_hp_shape, .value = if (hi_shape) 0 else 1 };
            }

            // Calculate max width for this column's knobs
            const hifreq_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_HiFrq,
                else => null,
            };
            const hifreq_label = if (hifreq_key) |key| tr(translations, key) else null;
            const hifreq_disabled = (hifreq_label == null);
            const hifreq_no_val_display = hifreq_disabled or mode != .fx_ctrl;
            const hifreq_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{hifreq_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_HiFrq", .{}),
            };

            const higain_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Eq_HiGain,
                else => null,
            };
            const higain_label = if (higain_key) |key| tr(translations, key) else null;
            const higain_disabled = (higain_label == null);
            const higain_no_val_display = higain_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const higain_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{higain_label orelse "-"}),
                .id = "Eq_HiGain",
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ hifreq_label_id.label, higain_label_id.label }, &offsets);

            // First knob
            var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
            if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_label_id, .{ .no_val_display = hifreq_no_val_display, .disabled = hifreq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
            }

            // Second knob
            var higain_prm = fx_state.values.get(.Eq_HiGain).?.param;
            if (try Knobs.drawWidget(ctx, &higain_prm.normalized, higain_label_id, .{ .no_val_display = higain_no_val_display, .disabled = higain_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiGain, .value = higain_prm.normalized };
            }
        }
    }

    return rv;
}

fn compPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, translations: *TranslationStore, label_buf: *[128:0]u8, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    const comp_bypass = fx_state.values.get(.Comp_comp).?.button;
    const comp_comp_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Comp_comp,
        .transport => .trsprt_Comp_comp,
        else => null,
    };
    const comp_comp_label = if (comp_comp_key) |key| tr(translations, key) else null;
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
            try imgui.Dummy(.{ ctx, KNOB_SIZE / 2, KNOB_SIZE / 2 });

            // Calculate max width for this column's knobs
            const ratio_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Comp_Ratio,
                else => null,
            };
            const ratio_label = if (ratio_key) |key| tr(translations, key) else null;
            const ratio_disabled = (ratio_label == null);
            const ratio_no_val_display = ratio_disabled or mode != .fx_ctrl;
            const ratio_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{ratio_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Comp_Ratio", .{}),
            };

            const drywet_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Comp_DryWet,
                else => null,
            };
            const drywet_label = if (drywet_key) |key| tr(translations, key) else null;
            const drywet_disabled = (drywet_label == null);
            const drywet_no_val_display = drywet_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const drywet_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{drywet_label orelse "-"}),
                .id = "Comp_DryWet",
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ ratio_label_id.label, drywet_label_id.label }, &offsets);

            // First knob
            var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
            if (try Knobs.drawWidget(ctx, &ratio_prm.normalized, ratio_label_id, .{ .no_val_display = ratio_no_val_display, .disabled = ratio_disabled }, max_width)) {
                rv = .{ .cc = .Comp_Ratio, .value = ratio_prm.normalized };
            }

            // Second knob
            var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
            if (try Knobs.drawWidget(ctx, &drywet_prm.normalized, drywet_label_id, .{ .no_val_display = drywet_no_val_display, .disabled = drywet_disabled }, max_width)) {
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
            const attack_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Comp_Attack,
                else => null,
            };
            const attack_label = if (attack_key) |key| tr(translations, key) else null;
            const attack_disabled = (attack_label == null);
            const attack_no_val_display = attack_disabled or mode != .fx_ctrl;
            const attack_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{attack_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Comp_Attack", .{}),
            };

            const release_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Comp_Release,
                else => null,
            };
            const release_label = if (release_key) |key| tr(translations, key) else null;
            const release_disabled = (release_label == null);
            const release_no_val_display = release_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const release_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{release_label orelse "-"}),
                .id = "Comp_Release",
            };

            const thresh_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Comp_Thresh,
                else => null,
            };
            const thresh_label = if (thresh_key) |key| tr(translations, key) else null;
            const thresh_disabled = (thresh_label == null);
            const thresh_no_val_display = thresh_disabled or mode != .fx_ctrl;
            var label_buf3: [128:0]u8 = undefined;
            const thresh_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf3, "{s}", .{thresh_label orelse "-"}),
                .id = "Comp_Thresh",
            };
            var offsets = [_]?f64{ null, null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ attack_label_id.label, release_label_id.label, thresh_label_id.label }, &offsets);

            // First knob
            var attack_prm = fx_state.values.get(.Comp_Attack).?.param;
            if (try Knobs.drawWidget(ctx, &attack_prm.normalized, attack_label_id, .{ .no_val_display = attack_no_val_display, .disabled = attack_disabled }, max_width)) {
                rv = .{ .cc = .Comp_Attack, .value = attack_prm.normalized };
            }

            // Second knob
            var release_prm = fx_state.values.get(.Comp_Release).?.param;
            if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label_id, .{ .no_val_display = release_no_val_display, .disabled = release_disabled }, max_width)) {
                rv = .{ .cc = .Comp_Release, .value = release_prm.normalized };
            }

            // Third knob
            var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
            if (try Knobs.drawWidget(ctx, &thresh_prm.normalized, thresh_label_id, .{ .no_val_display = thresh_no_val_display, .disabled = thresh_disabled }, max_width)) {
                rv = .{ .cc = .Comp_Thresh, .value = thresh_prm.normalized };
            }
        }
    }

    return rv;
}

fn outputPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, translations: *TranslationStore, label_buf: *[128:0]u8, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        const tr_order_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Tr_order,
            else => null,
        };
        const tr_order_label = if (tr_order_key) |key| tr(translations, key) else null;
        const tr_order_display_label: [:0]const u8 = tr_order_label orelse "-";
        const tr_order_disabled = (tr_order_label == null);
        if (try roundButton(.{ ctx, tr_order_display_label, "##" ++ @tagName(c1.CCs.Tr_order), null, null, .right, tr_order_disabled })) {}
        {
            // Calculate max width for this column's knobs
            const drive_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Out_Drive,
                else => null,
            };
            const drive_label = if (drive_key) |key| tr(translations, key) else null;
            const drive_disabled = (drive_label == null);
            const drive_no_val_display = drive_disabled or mode != .fx_ctrl;
            const drive_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{drive_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Out_Drive", .{}),
            };

            const char_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Out_DriveChar,
                else => null,
            };
            const char_label = if (char_key) |key| tr(translations, key) else null;
            const char_disabled = (char_label == null);
            const char_no_val_display = char_disabled or mode != .fx_ctrl;
            var label_buf2: [128:0]u8 = undefined;
            const char_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf2, "{s}", .{char_label orelse "-"}),
                .id = "Out_DriveChar",
            };

            const pan_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Out_Pan,
                else => null,
            };
            const pan_label = if (pan_key) |key| tr(translations, key) else null;
            const pan_disabled = (pan_label == null);
            const pan_no_val_display = pan_disabled or mode != .fx_ctrl;
            var label_buf3: [128:0]u8 = undefined;
            const pan_label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(&label_buf3, "{s}", .{pan_label orelse "-"}),
                .id = "Out_Pan",
            };
            var offsets = [_]?f64{ null, null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ drive_label_id.label, char_label_id.label, pan_label_id.label }, &offsets);

            // First knob
            var drive_prm = fx_state.values.get(.Out_Drive).?.param;
            if (try Knobs.drawWidget(ctx, &drive_prm.normalized, drive_label_id, .{ .no_val_display = drive_no_val_display, .disabled = drive_disabled }, max_width)) {
                rv = .{ .cc = .Out_Drive, .value = drive_prm.normalized };
            }

            // Second knob
            var char_prm = fx_state.values.get(.Out_DriveChar).?.param;
            if (try Knobs.drawWidget(ctx, &char_prm.normalized, char_label_id, .{ .no_val_display = char_no_val_display, .disabled = char_disabled }, max_width)) {
                rv = .{ .cc = .Out_DriveChar, .value = char_prm.normalized };
            }

            // Third knob
            var pan_prm = fx_state.values.get(.Out_Pan).?.param;
            if (try Knobs.drawWidget(ctx, &pan_prm.normalized, pan_label_id, .{ .no_val_display = pan_no_val_display, .disabled = pan_disabled }, max_width)) {
                rv = .{ .cc = .Out_Pan, .value = pan_prm.normalized };
            }
        }
    }
    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const ext_sidechain_key: ?TranslationKey = switch (mode) {
            .fx_ctrl => .fx_ctrl_Tr_ext_sidechain,
            else => null,
        };
        const ext_sidechain_label = if (ext_sidechain_key) |key| tr(translations, key) else null;
        const ext_sidechain_display_label: [:0]const u8 = ext_sidechain_label orelse "-";
        const ext_sidechain_disabled = (ext_sidechain_label == null);
        if (try roundButton(.{ ctx, ext_sidechain_display_label, "##" ++ @tagName(c1.CCs.Tr_ext_sidechain), null, null, .right, ext_sidechain_disabled })) {}
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE * 2, KNOB_SIZE * 2 });
            const solo = fx_state.values.get(.Out_solo).?.button;
            const out_solo_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Out_solo,
                else => null,
            };
            const out_solo_label = if (out_solo_key) |key| tr(translations, key) else null;
            const out_solo_display_label: [:0]const u8 = out_solo_label orelse "-";
            const out_solo_disabled = (out_solo_label == null);
            if (try roundButton(.{ ctx, out_solo_display_label, "##" ++ @tagName(c1.CCs.Out_solo), null, null, .below, out_solo_disabled })) {
                rv = .{ .cc = .Out_solo, .value = if (solo) 0 else 1 };
            }

            try imgui.SameLine(.{ctx});

            const mute = fx_state.values.get(.Out_mute).?.button;
            const out_mute_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Out_mute,
                else => null,
            };
            const out_mute_label = if (out_mute_key) |key| tr(translations, key) else null;
            const out_mute_display_label: [:0]const u8 = out_mute_label orelse "-";
            const out_mute_disabled = (out_mute_label == null);
            if (try roundButton(.{ ctx, out_mute_display_label, "##" ++ @tagName(c1.CCs.Out_mute), null, null, .below, out_mute_disabled })) {
                rv = .{ .cc = .Out_mute, .value = if (mute) 0 else 1 };
            }

            // Center-align the volume knob
            const vol_key: ?TranslationKey = switch (mode) {
                .fx_ctrl => .fx_ctrl_Out_Vol,
                else => null,
            };
            const vol_label = if (vol_key) |key| tr(translations, key) else null;
            const vol_disabled = (vol_label == null);
            const vol_no_val_display = vol_disabled or mode != .fx_ctrl;
            const label_id = Knobs.LabelId{
                .label = try std.fmt.bufPrintZ(label_buf, "{s}", .{vol_label orelse "-"}),
                .id = try std.fmt.bufPrintZ(id_buf, "Out_Vol", .{}),
            };
            var offsets = [_]?f64{null};
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{label_id.label}, &offsets);

            // Apply offset if needed
            var vol_prm = fx_state.values.get(.Out_Vol).?.param;
            if (try Knobs.drawWidget(ctx, &vol_prm.normalized, label_id, .{ .no_val_display = vol_no_val_display, .disabled = vol_disabled }, max_width)) {
                rv = .{ .cc = .Out_Vol, .value = vol_prm.normalized };
            }
        }
    }

    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
