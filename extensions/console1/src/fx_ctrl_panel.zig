const std = @import("std");
const imgui = @import("reaper_imgui");
const Knobs = @import("components/knob.zig");
const c1 = @import("c1.zig");
const WidgetInput = @import("action_types.zig").WidgetInput;
const UiState = @import("ui_state.zig").UiState;
const widgets = @import("components/widgets.zig");
const roundButton = widgets.roundButton;
const vSeparator = widgets.vSeparator;
const section_spacing = @import("styles.zig").section_spacing;
const Translations = @import("translations.zig");
const TranslationStore = Translations.TranslationStore;
const TranslationKey = Translations.TranslationKey;
const tr = @import("translations.zig").tr;
const Mode = @import("statemachine.zig").Mode;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const FxCtrlState = fx_ctrl_state.FxControlState;
const SCRouting = fx_ctrl_state.SCRouting;
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const TransportState = @import("action_types.zig").TransportState;
const LabelPool = @import("track_state.zig").LabelPool;
const toggle_active_color = @import("constants.zig").toggle_active_color;
const button = @import("components/button.zig");

fn renderMappableButton(
    ctx: imgui.ContextPtr,
    comptime cc: c1.CCs,
    fx_state: *FxCtrlState,
    mode: Mode,
    text_pos: ?button.TextPosition,
) !?WidgetInput {
    const is_fx_mode = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
    const val = fx_state.values.get(cc).?.param.normalized > 0.5;
    const mapped = is_fx_mode and fx_state.track_state.forward_map.get(cc) != null;
    const label: [:0]const u8 = if (mapped) fx_state.track_state.label_pool.getPrmLabel(cc) else "-";
    const color: ?c_int = if (mapped and val) toggle_active_color else null;
    if (try roundButton(.{ ctx, label, "##" ++ @tagName(cc), null, null, text_pos, !mapped, color })) {
        return .{ .cc = cc, .value = if (val) 0 else 1 };
    }
    return null;
}

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

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, ui: *UiState, translations: *TranslationStore) !?WidgetInput {
    const mode: Mode = ui.state.current_mode;
    const fx_state = &ui.state.fx_ctrl;
    const transport = &ui.state.transport;
    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });
    var id_buf: [64:0]u8 = undefined;
    var rv: ?WidgetInput = null;
    if (try inputPanel(ctx, mode, fx_state, transport, translations, &id_buf)) |input_rv| {
        rv = input_rv;
    }
    try sectional(ctx);
    // Gate Module
    if (try gatePanel(ctx, mode, fx_state, transport, &id_buf)) |gate_rv| {
        rv = gate_rv;
    }
    try sectional(ctx);
    // EQ Module
    if (try eqPanel(ctx, mode, fx_state, transport, translations, &id_buf)) |eq_rv| {
        rv = eq_rv;
    }
    try sectional(ctx);
    // Compressor Module
    if (try compPanel(ctx, mode, fx_state, transport, &id_buf)) |comp_rv| {
        rv = comp_rv;
    }
    try sectional(ctx);
    // Output Module
    if (try outputPanel(ctx, mode, fx_state, transport, translations, &id_buf)) |output_rv| {
        rv = output_rv;
    }

    if (!ui.midi_connected) {
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

fn inputPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, transport: *const TransportState, translations: *TranslationStore, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    // try imgui.Text(.{ ctx, "Input" });

    { // First column
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const disp_on_key: ?TranslationKey = switch (mode) {
            .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_disp_on,
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
        const pool = &fx_state.track_state.label_pool;
        const gain_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
        const gain_disabled = !gain_is_fx;
        const gain_no_val_display = gain_disabled or value_display_disabled;
        const label_id = Knobs.LabelId{
            .label = if (gain_is_fx) pool.getPrmLabel(.Inpt_Gain) else "-",
            .id = try std.fmt.bufPrintZ(id_buf, "Inpt_Gain", .{}),
            .value_text = if (gain_is_fx) pool.getFmtValue(.Inpt_Gain) else null,
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
            .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_disp_mode,
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
            const ftc = fx_state.filter_to_comp;

            // When filter_to_comp is active, check whether the COMP mapping
            // has the filter params defined; if not, disable the knobs.
            const comp_filter_unmapped = if (ftc) blk: {
                const panel_locs = fx_state.track_state.getModuleLocations() orelse break :blk true;
                const comp_loc = panel_locs.get(.COMP) orelse break :blk true;
                const mapping = comp_loc.mapping orelse break :blk true;
                break :blk (mapping.COMP.Comp_HiCut == null and mapping.COMP.Comp_LoCut == null);
            } else false;

            const inpt_pool = &fx_state.track_state.label_pool;
            const hicut_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const hicut_is_transport = (mode == .transport);
            const hicut_pool_cc: c1.CCs = if (ftc) .Comp_HiCut else .Inpt_HiCut;
            const hicut_disabled = (!hicut_is_fx and !hicut_is_transport) or comp_filter_unmapped;
            const hicut_no_val_display = hicut_disabled or value_display_disabled;
            const hicut_label_id = Knobs.LabelId{
                .label = if (hicut_is_fx) inpt_pool.getPrmLabel(hicut_pool_cc) else if (hicut_is_transport) tr(translations, .trsprt_Inpt_HiCut) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Inpt_HiCut", .{}),
                .value_text = if (hicut_is_fx) inpt_pool.getFmtValue(hicut_pool_cc) else null,
            };

            const locut_pool_cc: c1.CCs = if (ftc) .Comp_LoCut else .Inpt_LoCut;
            const locut_disabled = !hicut_is_fx or comp_filter_unmapped;
            const locut_no_val_display = locut_disabled or value_display_disabled;
            const locut_label_id = Knobs.LabelId{
                .label = if (hicut_is_fx) inpt_pool.getPrmLabel(locut_pool_cc) else "-",
                .id = "Inpt_LoCut",
                .value_text = if (hicut_is_fx) inpt_pool.getFmtValue(locut_pool_cc) else null,
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ hicut_label_id.label, locut_label_id.label }, &offsets);

            // First knob - read from the virtual CC when filter_to_comp is active
            const hicut_cc: c1.CCs = if (ftc) .Comp_HiCut else .Inpt_HiCut;
            var hicut_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.rate)) / 127.0
            else
                fx_state.values.get(hicut_cc).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &hicut_val, hicut_label_id, .{ .no_val_display = hicut_no_val_display, .disabled = hicut_disabled }, max_width)) {
                rv = .{ .cc = .Inpt_HiCut, .value = hicut_val };
            }

            // Second knob
            const locut_cc: c1.CCs = if (ftc) .Comp_LoCut else .Inpt_LoCut;
            var locut_prm = fx_state.values.get(locut_cc).?.param;
            if (try Knobs.drawWidget(ctx, &locut_prm.normalized, locut_label_id, .{ .no_val_display = locut_no_val_display, .disabled = locut_disabled }, max_width)) {
                rv = .{ .cc = .Inpt_LoCut, .value = locut_prm.normalized };
            }
        }

        const filt_to_comp_key: ?TranslationKey = switch (mode) {
            .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_filt_to_comp,
            else => null,
        };
        const filt_to_comp_label = if (filt_to_comp_key) |key| tr(translations, key) else null;
        const filt_to_comp_display_label: [:0]const u8 = filt_to_comp_label orelse "-";
        const filt_to_comp_disabled = (filt_to_comp_label == null);
        // Orange color (ABGR) when the toggle is active
        const ftc_color: ?c_int = if (fx_state.filter_to_comp) toggle_active_color else null;
        if (try roundButton(.{ ctx, filt_to_comp_display_label, "##" ++ @tagName(c1.CCs.Inpt_filt_to_comp), null, null, .right, filt_to_comp_disabled, ftc_color })) {
            rv = .{ .cc = .Inpt_filt_to_comp, .value = 1.0 };
        }

        const phase_inv_key: ?TranslationKey = switch (mode) {
            .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_phase_inv,
            else => null,
        };
        const phase_inv_label = if (phase_inv_key) |key| tr(translations, key) else null;
        const phase_inv_display_label: [:0]const u8 = phase_inv_label orelse "-";
        const phase_inv_disabled = (phase_inv_label == null);
        if (try roundButton(.{ ctx, phase_inv_display_label, "##" ++ @tagName(c1.CCs.Inpt_phase_inv), null, null, .right, phase_inv_disabled })) {
            rv = .{ .cc = .Inpt_phase_inv, .value = 1.0 };
        }

        const preset_key: ?TranslationKey = switch (mode) {
            .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_preset,
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

fn gatePanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, _: *const TransportState, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (try renderMappableButton(ctx, .Shp_shape, fx_state, mode, .right)) |action| {
        rv = action;
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            try imgui.Dummy(.{ ctx, 0, KNOB_SIZE * 0.75 });

            // Center-align the knob
            const pool = &fx_state.track_state.label_pool;
            const gate_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const gate_disabled = !gate_is_fx;
            const gate_no_val_display = gate_disabled or value_display_disabled;
            const label_id = Knobs.LabelId{
                .label = if (gate_is_fx) pool.getPrmLabel(.Shp_Gate) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Shp_Gate", .{}),
                .value_text = if (gate_is_fx) pool.getFmtValue(.Shp_Gate) else null,
            };
            var offsets = [_]?f64{null};
            _ = try getMaxLabelWidth(ctx, &[_][:0]const u8{label_id.label}, &offsets);

            // Apply offset if needed
            var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
            if (try Knobs.drawWidget(ctx, &gate_prm.normalized, label_id, .{ .no_val_display = gate_no_val_display, .disabled = gate_disabled }, null)) {
                rv = .{ .cc = .Shp_Gate, .value = gate_prm.normalized };
            }

            if (try renderMappableButton(ctx, .Shp_hard_gate, fx_state, mode, .below)) |action| {
                rv = action;
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
            const shp_pool = &fx_state.track_state.label_pool;
            const shp_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const release_disabled = !shp_is_fx;
            const release_no_val_display = release_disabled or value_display_disabled;
            const release_label_id = Knobs.LabelId{
                .label = if (shp_is_fx) shp_pool.getPrmLabel(.Shp_GateRelease) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Shp_GateRelease", .{}),
                .value_text = if (shp_is_fx) shp_pool.getFmtValue(.Shp_GateRelease) else null,
            };

            const sustain_disabled = !shp_is_fx;
            const sustain_no_val_display = sustain_disabled or value_display_disabled;
            const sustain_label_id = Knobs.LabelId{
                .label = if (shp_is_fx) shp_pool.getPrmLabel(.Shp_sustain) else "-",
                .id = "Shp_sustain",
                .value_text = if (shp_is_fx) shp_pool.getFmtValue(.Shp_sustain) else null,
            };

            const punch_disabled = !shp_is_fx;
            const punch_no_val_display = punch_disabled or value_display_disabled;
            const punch_label_id = Knobs.LabelId{
                .label = if (shp_is_fx) shp_pool.getPrmLabel(.Shp_Punch) else "-",
                .id = "Shp_Punch",
                .value_text = if (shp_is_fx) shp_pool.getFmtValue(.Shp_Punch) else null,
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

fn eqPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, transport: *const TransportState, translations: *TranslationStore, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (try renderMappableButton(ctx, .Eq_eq, fx_state, mode, .right)) |action| {
        rv = action;
    }

    { // first column
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE / 2, KNOB_SIZE / 2 });

            if (try renderMappableButton(ctx, .Eq_lp_shape, fx_state, mode, .right)) |action| {
                rv = action;
            }

            // Calculate max width for this column's knobs
            const eq_pool = &fx_state.track_state.label_pool;
            const eq_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const lofreq_disabled = !eq_is_fx;
            const lofreq_no_val_display = lofreq_disabled or value_display_disabled;
            const lofreq_label_id = Knobs.LabelId{
                .label = if (eq_is_fx) eq_pool.getPrmLabel(.Eq_LoFrq) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_LoFrq", .{}),
                .value_text = if (eq_is_fx) eq_pool.getFmtValue(.Eq_LoFrq) else null,
            };

            const logain_disabled = !eq_is_fx and mode != .transport;
            const logain_no_val_display = logain_disabled or value_display_disabled;
            const logain_label_id = Knobs.LabelId{
                .label = if (eq_is_fx) eq_pool.getPrmLabel(.Eq_LoGain) else if (mode == .transport) tr(translations, .trsprt_Eq_LoGain) else "-",
                .id = "Eq_LoGain",
                .value_text = if (eq_is_fx) eq_pool.getFmtValue(.Eq_LoGain) else null,
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ lofreq_label_id.label, logain_label_id.label }, &offsets);

            // First knob
            var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
            if (try Knobs.drawWidget(ctx, &lofreq_prm.normalized, lofreq_label_id, .{ .no_val_display = lofreq_no_val_display, .disabled = lofreq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_LoFrq, .value = lofreq_prm.normalized };
            }

            // Second knob
            var logain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.scrub)) / 127.0
            else
                fx_state.values.get(.Eq_LoGain).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &logain_val, logain_label_id, .{ .no_val_display = logain_no_val_display, .disabled = logain_disabled }, max_width)) {
                rv = .{ .cc = .Eq_LoGain, .value = logain_val };
            }
        }
    }

    try imgui.SameLine(.{ctx});

    { // second col
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            // Calculate max width for this column's knobs
            const eq2_pool = &fx_state.track_state.label_pool;
            const eq2_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const lomidq_disabled = !eq2_is_fx;
            const lomidq_no_val_display = lomidq_disabled or value_display_disabled;
            const lomidq_label_id = Knobs.LabelId{
                .label = if (eq2_is_fx) eq2_pool.getPrmLabel(.Eq_LoMidQ) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_LoMidQ", .{}),
                .value_text = if (eq2_is_fx) eq2_pool.getFmtValue(.Eq_LoMidQ) else null,
            };

            const lomidfreq_disabled = !eq2_is_fx;
            const lomidfreq_no_val_display = lomidfreq_disabled or value_display_disabled;
            const lomidfreq_label_id = Knobs.LabelId{
                .label = if (eq2_is_fx) eq2_pool.getPrmLabel(.Eq_LoMidFrq) else "-",
                .id = "Eq_LoMidFrq",
                .value_text = if (eq2_is_fx) eq2_pool.getFmtValue(.Eq_LoMidFrq) else null,
            };

            const lomidgain_disabled = !eq2_is_fx and mode != .transport;
            const lomidgain_no_val_display = lomidgain_disabled or value_display_disabled;
            const lomidgain_label_id = Knobs.LabelId{
                .label = if (eq2_is_fx) eq2_pool.getPrmLabel(.Eq_LoMidGain) else if (mode == .transport) tr(translations, .trsprt_Eq_LoMidGain) else "-",
                .id = "Eq_LoMidGain",
                .value_text = if (eq2_is_fx) eq2_pool.getFmtValue(.Eq_LoMidGain) else null,
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
            var lomidgain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.jog)) / 127.0
            else
                fx_state.values.get(.Eq_LoMidGain).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &lomidgain_val, lomidgain_label_id, .{ .no_val_display = lomidgain_no_val_display, .disabled = lomidgain_disabled }, max_width)) {
                rv = .{ .cc = .Eq_LoMidGain, .value = lomidgain_val };
            }
        }
    }

    try imgui.SameLine(.{ctx});

    { // third col
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            // Calculate max width for this column's knobs
            const eq3_pool = &fx_state.track_state.label_pool;
            const eq3_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const himidq_disabled = !eq3_is_fx;
            const himidq_no_val_display = himidq_disabled or value_display_disabled;
            const himidq_label_id = Knobs.LabelId{
                .label = if (eq3_is_fx) eq3_pool.getPrmLabel(.Eq_HiMidQ) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_HiMidQ", .{}),
                .value_text = if (eq3_is_fx) eq3_pool.getFmtValue(.Eq_HiMidQ) else null,
            };

            const himidfreq_disabled = !eq3_is_fx;
            const himidfreq_no_val_display = himidfreq_disabled or value_display_disabled;
            const himidfreq_label_id = Knobs.LabelId{
                .label = if (eq3_is_fx) eq3_pool.getPrmLabel(.Eq_HiMidFrq) else "-",
                .id = "Eq_HiMidFrq",
                .value_text = if (eq3_is_fx) eq3_pool.getFmtValue(.Eq_HiMidFrq) else null,
            };

            const himidgain_disabled = !eq3_is_fx and mode != .transport;
            const himidgain_no_val_display = himidgain_disabled or value_display_disabled;
            const himidgain_label_id = Knobs.LabelId{
                .label = if (eq3_is_fx) eq3_pool.getPrmLabel(.Eq_HiMidGain) else if (mode == .transport) tr(translations, .trsprt_Eq_HiMidGain) else "-",
                .id = "Eq_HiMidGain",
                .value_text = if (eq3_is_fx) eq3_pool.getFmtValue(.Eq_HiMidGain) else null,
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
            var himidgain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.jog_marker)) / 127.0
            else
                fx_state.values.get(.Eq_HiMidGain).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &himidgain_val, himidgain_label_id, .{ .no_val_display = himidgain_no_val_display, .disabled = himidgain_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiMidGain, .value = himidgain_val };
            }
        }
    }

    try imgui.SameLine(.{ctx});

    { // fourth column
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE / 2, KNOB_SIZE / 2 });

            if (try renderMappableButton(ctx, .Eq_hp_shape, fx_state, mode, .right)) |action| {
                rv = action;
            }

            // Calculate max width for this column's knobs
            const eq4_pool = &fx_state.track_state.label_pool;
            const eq4_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const hifreq_disabled = !eq4_is_fx;
            const hifreq_no_val_display = hifreq_disabled or value_display_disabled;
            const hifreq_label_id = Knobs.LabelId{
                .label = if (eq4_is_fx) eq4_pool.getPrmLabel(.Eq_HiFrq) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Eq_HiFrq", .{}),
                .value_text = if (eq4_is_fx) eq4_pool.getFmtValue(.Eq_HiFrq) else null,
            };

            const higain_disabled = !eq4_is_fx and mode != .transport;
            const higain_no_val_display = higain_disabled or value_display_disabled;
            const higain_label_id = Knobs.LabelId{
                .label = if (eq4_is_fx) eq4_pool.getPrmLabel(.Eq_HiGain) else if (mode == .transport) tr(translations, .trsprt_Eq_HiGain) else "-",
                .id = "Eq_HiGain",
                .value_text = if (eq4_is_fx) eq4_pool.getFmtValue(.Eq_HiGain) else null,
            };
            var offsets = [_]?f64{ null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ hifreq_label_id.label, higain_label_id.label }, &offsets);

            // First knob
            var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
            if (try Knobs.drawWidget(ctx, &hifreq_prm.normalized, hifreq_label_id, .{ .no_val_display = hifreq_no_val_display, .disabled = hifreq_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiFrq, .value = hifreq_prm.normalized };
            }

            // Second knob
            var higain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.jog_item)) / 127.0
            else
                fx_state.values.get(.Eq_HiGain).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &higain_val, higain_label_id, .{ .no_val_display = higain_no_val_display, .disabled = higain_disabled }, max_width)) {
                rv = .{ .cc = .Eq_HiGain, .value = higain_val };
            }
        }
    }

    return rv;
}

fn compPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, _: *const TransportState, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (try renderMappableButton(ctx, .Comp_comp, fx_state, mode, .right)) |action| {
        rv = action;
    }

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE / 2, KNOB_SIZE / 2 });

            // Calculate max width for this column's knobs
            const comp_pool = &fx_state.track_state.label_pool;
            const comp_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const ratio_disabled = !comp_is_fx;
            const ratio_no_val_display = ratio_disabled or value_display_disabled;
            const ratio_label_id = Knobs.LabelId{
                .label = if (comp_is_fx) comp_pool.getPrmLabel(.Comp_Ratio) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Comp_Ratio", .{}),
                .value_text = if (comp_is_fx) comp_pool.getFmtValue(.Comp_Ratio) else null,
            };

            const drywet_disabled = !comp_is_fx;
            const drywet_no_val_display = drywet_disabled or value_display_disabled;
            const drywet_label_id = Knobs.LabelId{
                .label = if (comp_is_fx) comp_pool.getPrmLabel(.Comp_DryWet) else "-",
                .id = "Comp_DryWet",
                .value_text = if (comp_is_fx) comp_pool.getFmtValue(.Comp_DryWet) else null,
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
            const comp2_pool = &fx_state.track_state.label_pool;
            const comp2_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const attack_disabled = !comp2_is_fx;
            const attack_no_val_display = attack_disabled or value_display_disabled;
            const attack_label_id = Knobs.LabelId{
                .label = if (comp2_is_fx) comp2_pool.getPrmLabel(.Comp_Attack) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Comp_Attack", .{}),
                .value_text = if (comp2_is_fx) comp2_pool.getFmtValue(.Comp_Attack) else null,
            };

            const comp_release_disabled = !comp2_is_fx;
            const release_no_val_display = comp_release_disabled or value_display_disabled;
            const release_label_id = Knobs.LabelId{
                .label = if (comp2_is_fx) comp2_pool.getPrmLabel(.Comp_Release) else "-",
                .id = "Comp_Release",
                .value_text = if (comp2_is_fx) comp2_pool.getFmtValue(.Comp_Release) else null,
            };

            const thresh_disabled = !comp2_is_fx;
            const thresh_no_val_display = thresh_disabled or value_display_disabled;
            const thresh_label_id = Knobs.LabelId{
                .label = if (comp2_is_fx) comp2_pool.getPrmLabel(.Comp_Thresh) else "-",
                .id = "Comp_Thresh",
                .value_text = if (comp2_is_fx) comp2_pool.getFmtValue(.Comp_Thresh) else null,
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
            if (try Knobs.drawWidget(ctx, &release_prm.normalized, release_label_id, .{ .no_val_display = release_no_val_display, .disabled = comp_release_disabled }, max_width)) {
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

fn outputPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, transport: *const TransportState, translations: *TranslationStore, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);
    const is_fx_mode = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
    const is_strip = is_fx_mode and fx_state.track_state.mode == .channel_strip;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    // First column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        if (is_strip) {
            const mapped = fx_state.track_state.forward_map.get(.Tr_order) != null;
            const label: [:0]const u8 = if (mapped) fx_state.track_state.label_pool.getFmtValue(.Tr_order) else "-";
            if (try roundButton(.{ ctx, label, "##" ++ @tagName(c1.CCs.Tr_order), null, null, .right, !mapped })) {
                rv = .{ .cc = .Tr_order, .value = 0 };
            }
        } else {
            const tr_order_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => switch (fx_state.track_state.getModulesOrder()) {
                    .@"EQ-S-C" => .fx_ctrl_Tr_order_eq_s_c,
                    .@"S-C-EQ" => .fx_ctrl_Tr_order_s_c_eq,
                    .@"S-EQ-C" => .fx_ctrl_Tr_order_s_eq_c,
                },
                else => null,
            };
            const tr_order_label = if (tr_order_key) |key| tr(translations, key) else null;
            const tr_order_display_label: [:0]const u8 = tr_order_label orelse "-";
            const tr_order_disabled = (tr_order_label == null);
            if (try roundButton(.{ ctx, tr_order_display_label, "##" ++ @tagName(c1.CCs.Tr_order), null, null, .right, tr_order_disabled })) {
                const next_order: ModulesOrder = switch (fx_state.track_state.getModulesOrder()) {
                    .@"EQ-S-C" => .@"S-C-EQ",
                    .@"S-C-EQ" => .@"S-EQ-C",
                    .@"S-EQ-C" => .@"EQ-S-C",
                };
                rv = .{ .cc = .Tr_order, .value = @as(f64, @floatFromInt(@intFromEnum(next_order))) };
            }
        }
        {
            // Calculate max width for this column's knobs
            const out_pool = &fx_state.track_state.label_pool;
            const out_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const out_is_transport = (mode == .transport);
            const drive_disabled = !out_is_fx and !out_is_transport;
            const drive_no_val_display = drive_disabled or value_display_disabled;
            const drive_label_id = Knobs.LabelId{
                .label = if (out_is_fx) out_pool.getPrmLabel(.Out_Drive) else if (out_is_transport) tr(translations, .trsprt_Out_Drive) else "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Out_Drive", .{}),
                .value_text = if (out_is_fx) out_pool.getFmtValue(.Out_Drive) else null,
            };

            const char_disabled = !out_is_fx and !out_is_transport;
            const char_no_val_display = char_disabled or value_display_disabled;
            const char_label_id = Knobs.LabelId{
                .label = if (out_is_fx) out_pool.getPrmLabel(.Out_DriveChar) else if (out_is_transport) tr(translations, .trsprt_Out_DriveChar) else "-",
                .id = "Out_DriveChar",
                .value_text = if (out_is_fx) out_pool.getFmtValue(.Out_DriveChar) else null,
            };

            // Out_Pan always controls track pan (not FX param), so we use translation labels
            const pan_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Out_Pan,
                .transport => .trsprt_Out_Pan,
                else => null,
            };
            const pan_label = if (pan_key) |key| tr(translations, key) else null;
            const pan_disabled = (pan_label == null);
            const pan_no_val_display = pan_disabled or value_display_disabled;
            const pan_label_id = Knobs.LabelId{
                .label = pan_label orelse "-",
                .id = "Out_Pan",
            };
            var offsets = [_]?f64{ null, null, null };
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{ drive_label_id.label, char_label_id.label, pan_label_id.label }, &offsets);

            // First knob
            var drive_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.zoom_horizontal)) / 127.0
            else
                fx_state.values.get(.Out_Drive).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &drive_val, drive_label_id, .{ .no_val_display = drive_no_val_display, .disabled = drive_disabled }, max_width)) {
                rv = .{ .cc = .Out_Drive, .value = drive_val };
            }

            // Second knob
            var char_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.zoom_vertical)) / 127.0
            else
                fx_state.values.get(.Out_DriveChar).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &char_val, char_label_id, .{ .no_val_display = char_no_val_display, .disabled = char_disabled }, max_width)) {
                rv = .{ .cc = .Out_DriveChar, .value = char_val };
            }

            // Third knob
            var pan_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.grid)) / 127.0
            else
                fx_state.values.get(.Out_Pan).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &pan_val, pan_label_id, .{ .no_val_display = pan_no_val_display, .disabled = pan_disabled }, max_width)) {
                rv = .{ .cc = .Out_Pan, .value = pan_val };
            }
        }
    }
    try imgui.SameLine(.{ctx});

    // Second column
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        if (is_strip) {
            const mapped = fx_state.track_state.forward_map.get(.Tr_ext_sidechain) != null;
            const label: [:0]const u8 = if (mapped) fx_state.track_state.label_pool.getFmtValue(.Tr_ext_sidechain) else "-";
            if (try roundButton(.{ ctx, label, "##" ++ @tagName(c1.CCs.Tr_ext_sidechain), null, null, .right, !mapped })) {
                rv = .{ .cc = .Tr_ext_sidechain, .value = 0 };
            }
        } else {
            const ext_sidechain_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => switch (fx_state.scRouting) {
                    .off => .fx_ctrl_Tr_ext_sidechain,
                    .toShape => .fx_ctrl_Tr_ext_sidechain_shape,
                    .toComp => .fx_ctrl_Tr_ext_sidechain_comp,
                },
                else => null,
            };
            const ext_sidechain_label = if (ext_sidechain_key) |key| tr(translations, key) else null;
            const ext_sidechain_display_label: [:0]const u8 = ext_sidechain_label orelse "-";
            const ext_sidechain_disabled = (ext_sidechain_label == null);
            if (try roundButton(.{ ctx, ext_sidechain_display_label, "##" ++ @tagName(c1.CCs.Tr_ext_sidechain), null, null, .right, ext_sidechain_disabled })) {
                const next_routing: SCRouting = switch (fx_state.scRouting) {
                    .off => .toShape,
                    .toShape => .toComp,
                    .toComp => .off,
                };
                rv = .{ .cc = .Tr_ext_sidechain, .value = @as(f64, @floatFromInt(@intFromEnum(next_routing))) };
            }
        }
        {
            try imgui.Dummy(.{ ctx, KNOB_SIZE * 2, KNOB_SIZE * 2 });
            const solo = fx_state.values.get(.Out_solo).?.button;
            const out_solo_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Out_solo,
                .transport => .trsprt_Out_solo,
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
                .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Out_mute,
                else => null,
            };
            const out_mute_label = if (out_mute_key) |key| tr(translations, key) else null;
            const out_mute_display_label: [:0]const u8 = out_mute_label orelse "-";
            const out_mute_disabled = (out_mute_label == null);
            if (try roundButton(.{ ctx, out_mute_display_label, "##" ++ @tagName(c1.CCs.Out_mute), null, null, .below, out_mute_disabled })) {
                rv = .{ .cc = .Out_mute, .value = if (mute) 0 else 1 };
            }

            // Center-align the volume knob
            // Out_Vol always controls track volume (not FX param), so we use translation labels
            const vol_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Out_Vol,
                .transport => .trsprt_Out_Vol,
                else => null,
            };
            const vol_label = if (vol_key) |key| tr(translations, key) else null;
            const vol_disabled = (vol_label == null);
            const vol_no_val_display = vol_disabled or value_display_disabled;
            const label_id = Knobs.LabelId{
                .label = vol_label orelse "-",
                .id = try std.fmt.bufPrintZ(id_buf, "Out_Vol", .{}),
            };
            var offsets = [_]?f64{null};
            const max_width = try getMaxLabelWidth(ctx, &[_][:0]const u8{label_id.label}, &offsets);

            // Apply offset if needed
            var vol_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.tr_sel)) / 127.0
            else
                fx_state.values.get(.Out_Vol).?.param.normalized;
            if (try Knobs.drawWidget(ctx, &vol_val, label_id, .{ .no_val_display = vol_no_val_display, .disabled = vol_disabled }, max_width)) {
                rv = .{ .cc = .Out_Vol, .value = vol_val };
            }
        }
    }

    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
