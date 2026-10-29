const std = @import("std");
const imgui = @import("reaper_imgui");
const Knobs = @import("knob");
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

const button = @import("components/button.zig");
const module_plate = @import("components/module_plate.zig");
const c1_theme = @import("theme/c1_theme.zig");

/// The colors of the buttons that are on, as on a mixing desk: yellow for solo, red for mute, blue for phase.
const solo_yellow: c_int = @bitCast(@as(u32, 0xF0C020FF));
const mute_red: c_int = @bitCast(@as(u32, 0xE04848FF));
const phase_blue: c_int = @bitCast(@as(u32, 0x4FA0E8FF));

/// Whether an on/off button is on. Because the host library that holds the state is replaced less often
/// than this one, a control that the host has not made a button yet reads as off.
fn buttonIsOn(fx_state: *const FxCtrlState, cc: c1.CCs) bool {
    const value = fx_state.values.get(cc) orelse return false;
    return switch (value) {
        .button => |on| on,
        else => false,
    };
}

/// The widest of some labels, so that a button whose label changes is given room for the longest.
fn widestOf(ctx: imgui.ContextPtr, candidates: []const [:0]const u8) ![:0]const u8 {
    var widest: [:0]const u8 = "";
    var widest_w: f64 = -1;
    for (candidates) |candidate| {
        var w: f64 = undefined;
        var h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, candidate, &w, &h });
        if (w > widest_w) {
            widest = candidate;
            widest_w = w;
        }
    }
    return widest;
}

/// The label that the plugin of the track gives to a parameter. Because the widths of the cards are made of
/// these labels, they are read whatever the mode: the widths must not change when the mode does.
fn paramLabel(fx_state: *const FxCtrlState, cc: c1.CCs) [:0]const u8 {
    return fx_state.track_state.label_pool.getPrmLabel(cc);
}

/// The distance that two columns must keep for the label of the bypass button of a module, which stands at the
/// top left of the plate, not to reach the label of the first knob of the next column.
fn bypassPitch(ctx: imgui.ContextPtr, fx_state: *const FxCtrlState, cc: c1.CCs) !f64 {
    const label = paramLabel(fx_state, cc);
    var w: f64 = 0;
    var h: f64 = undefined;
    if (label.len > 0) try imgui.CalcTextSize(.{ ctx, label, &w, &h });
    return button.default_radius * 2 + 4 + w + 8;
}

const ModuleCard = enum { input, shape, eq, comp, output };

/// Every title that a card can have, in any mode.
fn moduleTitles(card: ModuleCard) [2][:0]const u8 {
    return .{ moduleTitle(.fx_ctrl, card), moduleTitle(.transport, card) };
}

/// The title of the card of a module. The controls of the cards are those of the modules of the channel strip,
/// except in the transport mode, where the same controls move the transport: the cards are then named after
/// what their controls do.
fn moduleTitle(mode: Mode, card: ModuleCard) [:0]const u8 {
    return switch (mode) {
        .transport => switch (card) {
            .input => "PLAYBACK",
            .shape => "",
            .eq => "NAVIGATION",
            .comp => "MARKERS",
            .output => "VIEW",
        },
        else => switch (card) {
            .input => "INPUT",
            .shape => "SHAPE",
            .eq => "EQUALIZER",
            .comp => "COMPRESSOR",
            .output => "OUTPUT",
        },
    };
}

/// The accent color of the theme of REAPER, made opaque: the color that a selected row or a header has.
fn themeAccent(ctx: imgui.ContextPtr) !c_int {
    const color: u32 = @bitCast(try imgui.GetStyleColor(.{ ctx, imgui.Col_Header }));
    return @bitCast(color | 0xFF);
}

fn renderMappableButton(
    ctx: imgui.ContextPtr,
    plate: Plate,
    slot: Slot,
    comptime cc: c1.CCs,
    fx_state: *FxCtrlState,
    mode: Mode,
    text_pos: ?button.TextPosition,
) !?WidgetInput {
    const is_fx_mode = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
    const val = fx_state.values.get(cc).?.param.normalized > 0.5;
    const mapped = is_fx_mode and fx_state.track_state.forward_map.get(cc) != null;
    const label: [:0]const u8 = if (mapped) fx_state.track_state.label_pool.getPrmLabel(cc) else "-";
    const color: ?c_int = if (mapped and val) Knobs.led_orange else null;
    try plate.button(ctx, slot, label, text_pos orelse .right);
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
const KNOB_SIZE = Knobs.knob_size;

fn @"editMode?"(fx_state: *FxCtrlState, cc: c1.CCs) Knobs.EditMode {
    if (fx_state.editing_cc) |ecc| {
        if (ecc == cc) return &fx_state.edit_buf;
    }
    return null;
}

fn toWidgetInput(result: Knobs.KnobResult, cc: c1.CCs, normalized: f64, fx_state: *FxCtrlState) ?WidgetInput {
    switch (result) {
        .active => return .{ .cc = cc, .value = normalized },
        .value_dclick => {
            fx_state.editing_cc = cc;
            const written = std.mem.printSentinel(&fx_state.edit_buf, "{d:.4}", .{normalized}, 0) catch "";
            @memset(fx_state.edit_buf[written.len..], 0);
            return null;
        },
        .value_submit => |val| {
            fx_state.editing_cc = null;
            return .{ .cc = cc, .value = val };
        },
        .value_cancel => {
            fx_state.editing_cc = null;
            return null;
        },
    }
}

pub fn drawFxControlPanel(ctx: imgui.ContextPtr, ui: *UiState, translations: *TranslationStore) !?WidgetInput {
    const mode: Mode = ui.state.current_mode;
    const fx_state = &ui.state.fx_ctrl;
    const transport = &ui.state.transport;
    var win_pos = Knobs.Position{ .x = undefined, .y = undefined };
    try imgui.GetWindowPos(.{ ctx, &win_pos.x, &win_pos.y });
    var id_buf: [64:0]u8 = undefined;
    var rv: ?WidgetInput = null;
    module_plate.startFrame();
    if (try inputPanel(ctx, mode, fx_state, transport, translations, &id_buf)) |input_rv| {
        rv = input_rv;
    }
    try sectional(ctx);
    // Gate Module
    if (try gatePanel(ctx, mode, fx_state, &id_buf)) |gate_rv| {
        rv = gate_rv;
    }
    try sectional(ctx);
    // EQ Module
    if (try eqPanel(ctx, mode, fx_state, transport, translations, &id_buf)) |eq_rv| {
        rv = eq_rv;
    }
    try sectional(ctx);
    // Compressor Module
    if (try compPanel(ctx, mode, fx_state, &id_buf)) |comp_rv| {
        rv = comp_rv;
    }
    try sectional(ctx);
    // Output Module
    if (try outputPanel(ctx, mode, fx_state, transport, translations, &id_buf)) |output_rv| {
        rv = output_rv;
    }

    if (!ui.midi_connected) {
        try imgui.SameLine(.{ctx});
        try imgui.TextColored(.{ ctx, try imgui.GetStyleColor(.{ ctx, imgui.Col_PlotHistogram }), tr(translations, .fx_ctrl_disconnected) });
    }
    return rv;
}

pub fn sectional(ctx: imgui.ContextPtr) !void {
    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
}

const Slot = module_plate.Slot;
const Plate = module_plate.Plate;

// The slots of the modules: where each control is on the hardware, in pixels of a photograph of the console,
// and in which column of the module. A slot is named after the control it holds.

const input_slots = struct {
    const Inpt_disp_on = Slot{ .kind = .button, .col = 0, .y = 378, .at_left = true };
    const Inpt_disp_mode = Slot{ .kind = .button, .col = 1, .y = 378 };
    const Inpt_Gain = Slot{ .kind = .knob, .col = 0, .y = 553 };
    const Inpt_HiCut = Slot{ .kind = .knob, .col = 1, .y = 447 };
    const Inpt_LoCut = Slot{ .kind = .knob, .col = 1, .y = 519 };
    // The three buttons sit a little left of the center of the second column.
    const Inpt_filt_to_comp = Slot{ .kind = .button, .col = 1, .dx = -11, .y = 572 };
    const Inpt_phase_inv = Slot{ .kind = .button, .col = 1, .dx = -11, .y = 596 };
    const Inpt_preset = Slot{ .kind = .button, .col = 1, .dx = -11, .y = 620 };
    const all = [_]Slot{ Inpt_disp_on, Inpt_disp_mode, Inpt_Gain, Inpt_HiCut, Inpt_LoCut, Inpt_filt_to_comp, Inpt_phase_inv, Inpt_preset };
};

const shape_slots = struct {
    // The bypass buttons are in the top left corner of their plates.
    const Shp_shape = Slot{ .kind = .button, .y = 0, .at_left = true, .at_top = true };
    const Shp_Gate = Slot{ .kind = .knob, .col = 0, .y = 483 };
    const Shp_hard_gate = Slot{ .kind = .button_below, .col = 0, .y = 553 };
    const Shp_GateRelease = Slot{ .kind = .knob, .col = 1, .y = 447 };
    const Shp_sustain = Slot{ .kind = .knob, .col = 1, .y = 519 };
    const Shp_Punch = Slot{ .kind = .knob, .col = 1, .y = 591 };
    const all = [_]Slot{ Shp_shape, Shp_Gate, Shp_hard_gate, Shp_GateRelease, Shp_sustain, Shp_Punch };
};

const eq_slots = struct {
    const Eq_eq = Slot{ .kind = .button, .y = 0, .at_left = true, .at_top = true };
    // The shape buttons sit a little higher than on the hardware, to stay clear of the label of the knob under them.
    const Eq_lp_shape = Slot{ .kind = .button, .col = 0, .dx = -19, .y = 454 };
    const Eq_LoFrq = Slot{ .kind = .knob, .col = 0, .y = 518 };
    const Eq_LoGain = Slot{ .kind = .knob, .col = 0, .y = 590 };
    const Eq_LoMidQ = Slot{ .kind = .knob, .col = 1, .y = 447 };
    const Eq_LoMidFrq = Slot{ .kind = .knob, .col = 1, .y = 518 };
    const Eq_LoMidGain = Slot{ .kind = .knob, .col = 1, .y = 590 };
    const Eq_HiMidQ = Slot{ .kind = .knob, .col = 2, .y = 447 };
    const Eq_HiMidFrq = Slot{ .kind = .knob, .col = 2, .y = 518 };
    const Eq_HiMidGain = Slot{ .kind = .knob, .col = 2, .y = 590 };
    const Eq_hp_shape = Slot{ .kind = .button, .col = 3, .dx = -20, .y = 454 };
    const Eq_HiFrq = Slot{ .kind = .knob, .col = 3, .y = 518 };
    const Eq_HiGain = Slot{ .kind = .knob, .col = 3, .y = 590 };
    const all = [_]Slot{ Eq_eq, Eq_lp_shape, Eq_LoFrq, Eq_LoGain, Eq_LoMidQ, Eq_LoMidFrq, Eq_LoMidGain, Eq_HiMidQ, Eq_HiMidFrq, Eq_HiMidGain, Eq_hp_shape, Eq_HiFrq, Eq_HiGain };
};

const comp_slots = struct {
    const Comp_comp = Slot{ .kind = .button, .y = 0, .at_left = true, .at_top = true };
    const Comp_Ratio = Slot{ .kind = .knob, .col = 0, .y = 483 };
    const Comp_DryWet = Slot{ .kind = .knob, .col = 0, .y = 555 };
    const Comp_Attack = Slot{ .kind = .knob, .col = 1, .y = 447 };
    const Comp_Release = Slot{ .kind = .knob, .col = 1, .y = 519 };
    const Comp_Thresh = Slot{ .kind = .knob, .col = 1, .y = 591 };
    const all = [_]Slot{ Comp_comp, Comp_Ratio, Comp_DryWet, Comp_Attack, Comp_Release, Comp_Thresh };
};

const out_slots = struct {
    const Tr_order = Slot{ .kind = .button, .col = 0, .y = 382, .at_left = true };
    const Out_Drive = Slot{ .kind = .knob, .col = 0, .y = 447 };
    const Out_DriveChar = Slot{ .kind = .knob, .col = 0, .y = 519 };
    const Out_Pan = Slot{ .kind = .knob, .col = 0, .y = 591 };
    // The sidechain button stands right after the label of the order button, which is the first slot.
    const Tr_ext_sidechain = Slot{ .kind = .button, .y = 382, .follows = 0 };
    // Solo and mute are stacked above the volume knob, where the second column is free, so that their labels have room.
    const Out_solo = Slot{ .kind = .button, .col = 1, .dx = -27, .y = 450 };
    const Out_mute = Slot{ .kind = .button, .col = 1, .dx = -27, .y = 482 };
    // The volume knob is left aligned with the solo and mute buttons, which are the sixth slot.
    const Out_Vol = Slot{ .kind = .knob, .col = 1, .y = 591, .align_left_to = 5 };
    const all = [_]Slot{ Tr_order, Out_Drive, Out_DriveChar, Out_Pan, Tr_ext_sidechain, Out_solo, Out_mute, Out_Vol };
};

fn inputPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, transport: *const TransportState, translations: *TranslationStore, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    // The display button is named "FX" in the FX modes and "Hide C1" in the transport mode, and is in the accent of
    // the theme. Both names are the same in every language, and so are not translated.
    const disp_on_fx_label: [:0]const u8 = "FX";
    const disp_on_transport_label: [:0]const u8 = "Hide C1";

    // The labels of the buttons are translations of the panel, and so are the same in every mode.
    const labels = [_][:0]const u8{ try widestOf(ctx, &.{ disp_on_fx_label, disp_on_transport_label }), try widestOf(ctx, &.{ tr(translations, .fx_ctrl_Inpt_disp_mode), tr(translations, .trsprt_Inpt_disp_mode) }), "", "", "", tr(translations, .fx_ctrl_Inpt_filt_to_comp), tr(translations, .fx_ctrl_Inpt_phase_inv), tr(translations, .fx_ctrl_Inpt_preset) };
    const plate = try Plate.begin(ctx, .{ .slots = &input_slots.all, .title = moduleTitle(mode, .input), .title_alternatives = &moduleTitles(.input), .title_font = c1_theme.fonts.TAB, .columns = 2, .widest_label = "Input Gain", .labels = &labels });

    const disp_on_key: ?TranslationKey = switch (mode) {
        .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_disp_on,
        .transport => .trsprt_Inpt_disp_on,
        else => null,
    };
    const disp_on_label = if (disp_on_key) |key| tr(translations, key) else null;
    const disp_on_fx_mode = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
    const disp_on_display_label: [:0]const u8 = if (disp_on_fx_mode) disp_on_fx_label else if (mode == .transport) disp_on_transport_label else disp_on_label orelse "-";
    try plate.button(ctx, input_slots.Inpt_disp_on, disp_on_display_label, .right);
    const disp_on_color: ?c_int = if (disp_on_label == null) null else try themeAccent(ctx);
    if (try roundButton(.{ ctx, disp_on_display_label, "##" ++ @tagName(c1.CCs.Inpt_disp_on), null, null, .right, disp_on_label == null, disp_on_color, disp_on_fx_mode and fx_state.display != null })) {
        rv = .{ .cc = .Inpt_disp_on, .value = 1.0 };
    }

    const disp_mode_key: ?TranslationKey = switch (mode) {
        .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_disp_mode,
        .transport => .trsprt_Inpt_disp_mode,
        else => null,
    };
    const disp_mode_label = if (disp_mode_key) |key| tr(translations, key) else null;
    const disp_mode_display_label: [:0]const u8 = disp_mode_label orelse "-";
    try plate.button(ctx, input_slots.Inpt_disp_mode, disp_mode_display_label, .right);
    if (try roundButton(.{ ctx, disp_mode_display_label, "##" ++ @tagName(c1.CCs.Inpt_disp_mode), null, null, .right, disp_mode_label == null })) {
        rv = .{ .cc = .Inpt_disp_mode, .value = 1.0 };
    }

    // The gain knob, at the left of the first knob row.
    {
        const pool = &fx_state.track_state.label_pool;
        const gain_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
        const gain_disabled = !gain_is_fx;
        const label_id = Knobs.LabelId{
            .label = if (gain_is_fx) pool.getPrmLabel(.Inpt_Gain) else "-",
            .id = try std.mem.printSentinel(id_buf, "Inpt_Gain", .{}, 0),
            .value_text = if (gain_is_fx) pool.getFmtValue(.Inpt_Gain) else null,
        };
        var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
        try plate.knob(ctx, input_slots.Inpt_Gain);
        if (try Knobs.drawWidget(
            ctx,
            &gain_prm.normalized,
            label_id,
            .{ .no_val_display = gain_disabled or value_display_disabled, .disabled = gain_disabled },
            plate.knob_w,
            @"editMode?"(fx_state, .Inpt_Gain),
        )) |knob_res| {
            rv = toWidgetInput(knob_res, .Inpt_Gain, gain_prm.normalized, fx_state);
        }
    }

    // The two filter knobs, at the right of the gain knob.
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
        const hicut_label_id = Knobs.LabelId{
            .label = if (hicut_is_fx) inpt_pool.getPrmLabel(hicut_pool_cc) else if (hicut_is_transport) tr(translations, .trsprt_Inpt_HiCut) else "-",
            .id = try std.mem.printSentinel(id_buf, "Inpt_HiCut", .{}, 0),
            .value_text = if (hicut_is_fx) inpt_pool.getFmtValue(hicut_pool_cc) else null,
        };

        const locut_pool_cc: c1.CCs = if (ftc) .Comp_LoCut else .Inpt_LoCut;
        const locut_disabled = !hicut_is_fx or comp_filter_unmapped;
        const locut_label_id = Knobs.LabelId{
            .label = if (hicut_is_fx) inpt_pool.getPrmLabel(locut_pool_cc) else "-",
            .id = "Inpt_LoCut",
            .value_text = if (hicut_is_fx) inpt_pool.getFmtValue(locut_pool_cc) else null,
        };

        // First knob - read from the virtual CC when filter_to_comp is active
        const hicut_cc: c1.CCs = if (ftc) .Comp_HiCut else .Inpt_HiCut;
        var hicut_val: f64 = if (mode == .transport)
            @as(f64, @floatFromInt(transport.rate)) / 127.0
        else
            fx_state.values.get(hicut_cc).?.param.normalized;
        try plate.knob(ctx, input_slots.Inpt_HiCut);
        if (try Knobs.drawWidget(
            ctx,
            &hicut_val,
            hicut_label_id,
            .{ .no_val_display = hicut_disabled or value_display_disabled, .disabled = hicut_disabled },
            plate.knob_w,
            @"editMode?"(fx_state, .Inpt_HiCut),
        )) |knob_res| {
            rv = toWidgetInput(knob_res, .Inpt_HiCut, hicut_val, fx_state);
        }

        // Second knob
        const locut_cc: c1.CCs = if (ftc) .Comp_LoCut else .Inpt_LoCut;
        var locut_prm = fx_state.values.get(locut_cc).?.param;
        try plate.knob(ctx, input_slots.Inpt_LoCut);
        if (try Knobs.drawWidget(
            ctx,
            &locut_prm.normalized,
            locut_label_id,
            .{ .no_val_display = locut_disabled or value_display_disabled, .disabled = locut_disabled },
            plate.knob_w,
            @"editMode?"(fx_state, .Inpt_LoCut),
        )) |knob_res| {
            rv = toWidgetInput(knob_res, .Inpt_LoCut, locut_prm.normalized, fx_state);
        }
    }

    // The preset, phase and filter buttons, stacked under the filter knobs.

    const preset_key: ?TranslationKey = switch (mode) {
        .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_preset,
        else => null,
    };
    const preset_label = if (preset_key) |key| tr(translations, key) else null;
    const preset_display_label: [:0]const u8 = preset_label orelse "-";
    try plate.button(ctx, input_slots.Inpt_preset, preset_display_label, .right);
    if (try roundButton(.{ ctx, preset_display_label, "##" ++ @tagName(c1.CCs.Inpt_preset), null, null, .right, preset_label == null })) {
        rv = .{ .cc = .Inpt_preset, .value = 1.0 };
    }

    const phase_inv_key: ?TranslationKey = switch (mode) {
        .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_phase_inv,
        else => null,
    };
    const phase_inv_label = if (phase_inv_key) |key| tr(translations, key) else null;
    const phase_inv_display_label: [:0]const u8 = phase_inv_label orelse "-";
    const phase_inv_color: ?c_int = if (buttonIsOn(fx_state, .Inpt_phase_inv)) phase_blue else null;
    try plate.button(ctx, input_slots.Inpt_phase_inv, phase_inv_display_label, .right);
    if (try roundButton(.{ ctx, phase_inv_display_label, "##" ++ @tagName(c1.CCs.Inpt_phase_inv), null, null, .right, phase_inv_label == null, phase_inv_color })) {
        rv = .{ .cc = .Inpt_phase_inv, .value = 1.0 };
    }

    const filt_to_comp_key: ?TranslationKey = switch (mode) {
        .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Inpt_filt_to_comp,
        else => null,
    };
    const filt_to_comp_label = if (filt_to_comp_key) |key| tr(translations, key) else null;
    const filt_to_comp_display_label: [:0]const u8 = filt_to_comp_label orelse "-";
    // The orange of the LEDs when the toggle is active
    const ftc_color: ?c_int = if (fx_state.filter_to_comp) Knobs.led_orange else null;
    try plate.button(ctx, input_slots.Inpt_filt_to_comp, filt_to_comp_display_label, .right);
    if (try roundButton(.{ ctx, filt_to_comp_display_label, "##" ++ @tagName(c1.CCs.Inpt_filt_to_comp), null, null, .right, filt_to_comp_label == null, ftc_color })) {
        rv = .{ .cc = .Inpt_filt_to_comp, .value = 1.0 };
    }

    try plate.end(ctx);
    return rv;
}

fn gatePanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    const shape_widest = try widestOf(ctx, &.{
        "Release",
        paramLabel(fx_state, .Shp_Gate),
        paramLabel(fx_state, .Shp_GateRelease),
        paramLabel(fx_state, .Shp_sustain),
        paramLabel(fx_state, .Shp_Punch),
    });
    const plate = try Plate.begin(ctx, .{ .slots = &shape_slots.all, .title = moduleTitle(mode, .shape), .title_alternatives = &moduleTitles(.shape), .title_font = c1_theme.fonts.TAB, .columns = 2, .widest_label = shape_widest, .min_pitch = try bypassPitch(ctx, fx_state, .Shp_shape) });

    if (try renderMappableButton(ctx, plate, shape_slots.Shp_shape, .Shp_shape, fx_state, mode, .right)) |action| {
        rv = action;
    }

    // First column
    {
        {

            // Center-align the knob
            const pool = &fx_state.track_state.label_pool;
            const gate_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const gate_disabled = !gate_is_fx;
            const gate_no_val_display = gate_disabled or value_display_disabled;
            const label_id = Knobs.LabelId{
                .label = if (gate_is_fx) pool.getPrmLabel(.Shp_Gate) else "-",
                .id = try std.mem.printSentinel(id_buf, "Shp_Gate", .{}, 0),
                .value_text = if (gate_is_fx) pool.getFmtValue(.Shp_Gate) else null,
            };
            var gate_prm = fx_state.values.get(.Shp_Gate).?.param;
            try plate.knob(ctx, shape_slots.Shp_Gate);
            if (try Knobs.drawWidget(
                ctx,
                &gate_prm.normalized,
                label_id,
                .{ .no_val_display = gate_no_val_display, .disabled = gate_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Shp_Gate),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Shp_Gate, gate_prm.normalized, fx_state);
            }

            if (try renderMappableButton(ctx, plate, shape_slots.Shp_hard_gate, .Shp_hard_gate, fx_state, mode, .below)) |action| {
                rv = action;
            }
        }
    }

    // Second column
    {
        {
            // Calculate max width for this column's knobs
            const shp_pool = &fx_state.track_state.label_pool;
            const shp_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const release_disabled = !shp_is_fx;
            const release_no_val_display = release_disabled or value_display_disabled;
            const release_label_id = Knobs.LabelId{
                .label = if (shp_is_fx) shp_pool.getPrmLabel(.Shp_GateRelease) else "-",
                .id = try std.mem.printSentinel(id_buf, "Shp_GateRelease", .{}, 0),
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

            // First knob
            var release_prm = fx_state.values.get(.Shp_GateRelease).?.param;
            try plate.knob(ctx, shape_slots.Shp_GateRelease);
            if (try Knobs.drawWidget(
                ctx,
                &release_prm.normalized,
                release_label_id,
                .{ .no_val_display = release_no_val_display, .disabled = release_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Shp_GateRelease),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Shp_GateRelease, release_prm.normalized, fx_state);
            }

            // Second knob
            var sustain_prm = fx_state.values.get(.Shp_sustain).?.param;
            try plate.knob(ctx, shape_slots.Shp_sustain);
            if (try Knobs.drawWidget(
                ctx,
                &sustain_prm.normalized,
                sustain_label_id,
                .{ .no_val_display = sustain_no_val_display, .disabled = sustain_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Shp_sustain),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Shp_sustain, sustain_prm.normalized, fx_state);
            }

            // Third knob
            var punch_prm = fx_state.values.get(.Shp_Punch).?.param;
            try plate.knob(ctx, shape_slots.Shp_Punch);
            if (try Knobs.drawWidget(
                ctx,
                &punch_prm.normalized,
                punch_label_id,
                .{ .no_val_display = punch_no_val_display, .disabled = punch_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Shp_Punch),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Shp_Punch, punch_prm.normalized, fx_state);
            }
        }
    }

    try plate.end(ctx);
    return rv;
}

fn eqPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, transport: *const TransportState, translations: *TranslationStore, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    // The knobs are as wide as the widest of the labels that the plugin gives them, and at least as wide as
    // the longest label of the hardware.
    const eq_widest = try widestOf(ctx, &.{
        "Low Mid Gain",
        paramLabel(fx_state, .Eq_LoFrq),
        paramLabel(fx_state, .Eq_LoGain),
        paramLabel(fx_state, .Eq_LoMidQ),
        paramLabel(fx_state, .Eq_LoMidFrq),
        paramLabel(fx_state, .Eq_LoMidGain),
        paramLabel(fx_state, .Eq_HiMidQ),
        paramLabel(fx_state, .Eq_HiMidFrq),
        paramLabel(fx_state, .Eq_HiMidGain),
        paramLabel(fx_state, .Eq_HiFrq),
        paramLabel(fx_state, .Eq_HiGain),
        tr(translations, .trsprt_Eq_LoGain),
        tr(translations, .trsprt_Eq_LoMidGain),
        tr(translations, .trsprt_Eq_HiMidGain),
        tr(translations, .trsprt_Eq_HiGain),
    });
    const plate = try Plate.begin(ctx, .{ .slots = &eq_slots.all, .title = moduleTitle(mode, .eq), .title_alternatives = &moduleTitles(.eq), .title_font = c1_theme.fonts.TAB, .columns = 4, .widest_label = eq_widest, .min_pitch = try bypassPitch(ctx, fx_state, .Eq_eq) });

    if (try renderMappableButton(ctx, plate, eq_slots.Eq_eq, .Eq_eq, fx_state, mode, .right)) |action| {
        rv = action;
    }

    { // first column
        {
            if (try renderMappableButton(ctx, plate, eq_slots.Eq_lp_shape, .Eq_lp_shape, fx_state, mode, .right)) |action| {
                rv = action;
            }

            // Calculate max width for this column's knobs
            const eq_pool = &fx_state.track_state.label_pool;
            const eq_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const lofreq_disabled = !eq_is_fx;
            const lofreq_no_val_display = lofreq_disabled or value_display_disabled;
            const lofreq_label_id = Knobs.LabelId{
                .label = if (eq_is_fx) eq_pool.getPrmLabel(.Eq_LoFrq) else "-",
                .id = try std.mem.printSentinel(id_buf, "Eq_LoFrq", .{}, 0),
                .value_text = if (eq_is_fx) eq_pool.getFmtValue(.Eq_LoFrq) else null,
            };

            const logain_disabled = !eq_is_fx and mode != .transport;
            const logain_no_val_display = logain_disabled or value_display_disabled;
            const logain_label_id = Knobs.LabelId{
                .label = if (eq_is_fx) eq_pool.getPrmLabel(.Eq_LoGain) else if (mode == .transport) tr(translations, .trsprt_Eq_LoGain) else "-",
                .id = "Eq_LoGain",
                .value_text = if (eq_is_fx) eq_pool.getFmtValue(.Eq_LoGain) else null,
            };

            // First knob
            var lofreq_prm = fx_state.values.get(.Eq_LoFrq).?.param;
            try plate.knob(ctx, eq_slots.Eq_LoFrq);
            if (try Knobs.drawWidget(
                ctx,
                &lofreq_prm.normalized,
                lofreq_label_id,
                .{ .no_val_display = lofreq_no_val_display, .disabled = lofreq_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_LoFrq),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_LoFrq, lofreq_prm.normalized, fx_state);
            }

            // Second knob
            var logain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.scrub)) / 127.0
            else
                fx_state.values.get(.Eq_LoGain).?.param.normalized;
            try plate.knob(ctx, eq_slots.Eq_LoGain);
            if (try Knobs.drawWidget(
                ctx,
                &logain_val,
                logain_label_id,
                .{ .no_val_display = logain_no_val_display, .disabled = logain_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_LoGain),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_LoGain, logain_val, fx_state);
            }
        }
    }

    { // second col
        {
            // Calculate max width for this column's knobs
            const eq2_pool = &fx_state.track_state.label_pool;
            const eq2_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const lomidq_disabled = !eq2_is_fx;
            const lomidq_no_val_display = lomidq_disabled or value_display_disabled;
            const lomidq_label_id = Knobs.LabelId{
                .label = if (eq2_is_fx) eq2_pool.getPrmLabel(.Eq_LoMidQ) else "-",
                .id = try std.mem.printSentinel(id_buf, "Eq_LoMidQ", .{}, 0),
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

            // First knob
            var lomidq_prm = fx_state.values.get(.Eq_LoMidQ).?.param;
            try plate.knob(ctx, eq_slots.Eq_LoMidQ);
            if (try Knobs.drawWidget(
                ctx,
                &lomidq_prm.normalized,
                lomidq_label_id,
                .{ .no_val_display = lomidq_no_val_display, .disabled = lomidq_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_LoMidQ),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_LoMidQ, lomidq_prm.normalized, fx_state);
            }

            // Second knob
            var lomidfreq_prm = fx_state.values.get(.Eq_LoMidFrq).?.param;
            try plate.knob(ctx, eq_slots.Eq_LoMidFrq);
            if (try Knobs.drawWidget(
                ctx,
                &lomidfreq_prm.normalized,
                lomidfreq_label_id,
                .{ .no_val_display = lomidfreq_no_val_display, .disabled = lomidfreq_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_LoMidFrq),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_LoMidFrq, lomidfreq_prm.normalized, fx_state);
            }

            // Third knob
            var lomidgain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.jog)) / 127.0
            else
                fx_state.values.get(.Eq_LoMidGain).?.param.normalized;
            try plate.knob(ctx, eq_slots.Eq_LoMidGain);
            if (try Knobs.drawWidget(
                ctx,
                &lomidgain_val,
                lomidgain_label_id,
                .{ .no_val_display = lomidgain_no_val_display, .disabled = lomidgain_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_LoMidGain),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_LoMidGain, lomidgain_val, fx_state);
            }
        }
    }

    { // third col
        {
            // Calculate max width for this column's knobs
            const eq3_pool = &fx_state.track_state.label_pool;
            const eq3_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const himidq_disabled = !eq3_is_fx;
            const himidq_no_val_display = himidq_disabled or value_display_disabled;
            const himidq_label_id = Knobs.LabelId{
                .label = if (eq3_is_fx) eq3_pool.getPrmLabel(.Eq_HiMidQ) else "-",
                .id = try std.mem.printSentinel(id_buf, "Eq_HiMidQ", .{}, 0),
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

            // First knob
            var himidq_prm = fx_state.values.get(.Eq_HiMidQ).?.param;
            try plate.knob(ctx, eq_slots.Eq_HiMidQ);
            if (try Knobs.drawWidget(
                ctx,
                &himidq_prm.normalized,
                himidq_label_id,
                .{ .no_val_display = himidq_no_val_display, .disabled = himidq_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_HiMidQ),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_HiMidQ, himidq_prm.normalized, fx_state);
            }

            // Second knob
            var himidfreq_prm = fx_state.values.get(.Eq_HiMidFrq).?.param;
            try plate.knob(ctx, eq_slots.Eq_HiMidFrq);
            if (try Knobs.drawWidget(
                ctx,
                &himidfreq_prm.normalized,
                himidfreq_label_id,
                .{ .no_val_display = himidfreq_no_val_display, .disabled = himidfreq_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_HiMidFrq),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_HiMidFrq, himidfreq_prm.normalized, fx_state);
            }

            // Third knob
            var himidgain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.jog_marker)) / 127.0
            else
                fx_state.values.get(.Eq_HiMidGain).?.param.normalized;
            try plate.knob(ctx, eq_slots.Eq_HiMidGain);
            if (try Knobs.drawWidget(
                ctx,
                &himidgain_val,
                himidgain_label_id,
                .{ .no_val_display = himidgain_no_val_display, .disabled = himidgain_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_HiMidGain),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_HiMidGain, himidgain_val, fx_state);
            }
        }
    }

    { // fourth column
        {
            if (try renderMappableButton(ctx, plate, eq_slots.Eq_hp_shape, .Eq_hp_shape, fx_state, mode, .right)) |action| {
                rv = action;
            }

            // Calculate max width for this column's knobs
            const eq4_pool = &fx_state.track_state.label_pool;
            const eq4_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const hifreq_disabled = !eq4_is_fx;
            const hifreq_no_val_display = hifreq_disabled or value_display_disabled;
            const hifreq_label_id = Knobs.LabelId{
                .label = if (eq4_is_fx) eq4_pool.getPrmLabel(.Eq_HiFrq) else "-",
                .id = try std.mem.printSentinel(id_buf, "Eq_HiFrq", .{}, 0),
                .value_text = if (eq4_is_fx) eq4_pool.getFmtValue(.Eq_HiFrq) else null,
            };

            const higain_disabled = !eq4_is_fx and mode != .transport;
            const higain_no_val_display = higain_disabled or value_display_disabled;
            const higain_label_id = Knobs.LabelId{
                .label = if (eq4_is_fx) eq4_pool.getPrmLabel(.Eq_HiGain) else if (mode == .transport) tr(translations, .trsprt_Eq_HiGain) else "-",
                .id = "Eq_HiGain",
                .value_text = if (eq4_is_fx) eq4_pool.getFmtValue(.Eq_HiGain) else null,
            };

            // First knob
            var hifreq_prm = fx_state.values.get(.Eq_HiFrq).?.param;
            try plate.knob(ctx, eq_slots.Eq_HiFrq);
            if (try Knobs.drawWidget(
                ctx,
                &hifreq_prm.normalized,
                hifreq_label_id,
                .{ .no_val_display = hifreq_no_val_display, .disabled = hifreq_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_HiFrq),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_HiFrq, hifreq_prm.normalized, fx_state);
            }

            // Second knob
            var higain_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.jog_item)) / 127.0
            else
                fx_state.values.get(.Eq_HiGain).?.param.normalized;
            try plate.knob(ctx, eq_slots.Eq_HiGain);
            if (try Knobs.drawWidget(
                ctx,
                &higain_val,
                higain_label_id,
                .{ .no_val_display = higain_no_val_display, .disabled = higain_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Eq_HiGain),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Eq_HiGain, higain_val, fx_state);
            }
        }
    }

    try plate.end(ctx);
    return rv;
}

fn compPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);

    const comp_widest = try widestOf(ctx, &.{
        "Threshold",
        paramLabel(fx_state, .Comp_Ratio),
        paramLabel(fx_state, .Comp_DryWet),
        paramLabel(fx_state, .Comp_Attack),
        paramLabel(fx_state, .Comp_Release),
        paramLabel(fx_state, .Comp_Thresh),
    });
    const plate = try Plate.begin(ctx, .{ .slots = &comp_slots.all, .title = moduleTitle(mode, .comp), .title_alternatives = &moduleTitles(.comp), .title_font = c1_theme.fonts.TAB, .columns = 2, .widest_label = comp_widest, .min_pitch = try bypassPitch(ctx, fx_state, .Comp_comp) });

    if (try renderMappableButton(ctx, plate, comp_slots.Comp_comp, .Comp_comp, fx_state, mode, .right)) |action| {
        rv = action;
    }

    // First column
    {
        {

            // Calculate max width for this column's knobs
            const comp_pool = &fx_state.track_state.label_pool;
            const comp_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const ratio_disabled = !comp_is_fx;
            const ratio_no_val_display = ratio_disabled or value_display_disabled;
            const ratio_label_id = Knobs.LabelId{
                .label = if (comp_is_fx) comp_pool.getPrmLabel(.Comp_Ratio) else "-",
                .id = try std.mem.printSentinel(id_buf, "Comp_Ratio", .{}, 0),
                .value_text = if (comp_is_fx) comp_pool.getFmtValue(.Comp_Ratio) else null,
            };

            const drywet_disabled = !comp_is_fx;
            const drywet_no_val_display = drywet_disabled or value_display_disabled;
            const drywet_label_id = Knobs.LabelId{
                .label = if (comp_is_fx) comp_pool.getPrmLabel(.Comp_DryWet) else "-",
                .id = "Comp_DryWet",
                .value_text = if (comp_is_fx) comp_pool.getFmtValue(.Comp_DryWet) else null,
            };

            // First knob
            var ratio_prm = fx_state.values.get(.Comp_Ratio).?.param;
            try plate.knob(ctx, comp_slots.Comp_Ratio);
            if (try Knobs.drawWidget(
                ctx,
                &ratio_prm.normalized,
                ratio_label_id,
                .{ .no_val_display = ratio_no_val_display, .disabled = ratio_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Comp_Ratio),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Comp_Ratio, ratio_prm.normalized, fx_state);
            }

            // Second knob
            var drywet_prm = fx_state.values.get(.Comp_DryWet).?.param;
            try plate.knob(ctx, comp_slots.Comp_DryWet);
            if (try Knobs.drawWidget(
                ctx,
                &drywet_prm.normalized,
                drywet_label_id,
                .{ .no_val_display = drywet_no_val_display, .disabled = drywet_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Comp_DryWet),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Comp_DryWet, drywet_prm.normalized, fx_state);
            }
        }
    }

    // Second column
    {
        {
            // Calculate max width for this column's knobs
            const comp2_pool = &fx_state.track_state.label_pool;
            const comp2_is_fx = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
            const attack_disabled = !comp2_is_fx;
            const attack_no_val_display = attack_disabled or value_display_disabled;
            const attack_label_id = Knobs.LabelId{
                .label = if (comp2_is_fx) comp2_pool.getPrmLabel(.Comp_Attack) else "-",
                .id = try std.mem.printSentinel(id_buf, "Comp_Attack", .{}, 0),
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

            // First knob
            var attack_prm = fx_state.values.get(.Comp_Attack).?.param;
            try plate.knob(ctx, comp_slots.Comp_Attack);
            if (try Knobs.drawWidget(
                ctx,
                &attack_prm.normalized,
                attack_label_id,
                .{ .no_val_display = attack_no_val_display, .disabled = attack_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Comp_Attack),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Comp_Attack, attack_prm.normalized, fx_state);
            }

            // Second knob
            var release_prm = fx_state.values.get(.Comp_Release).?.param;
            try plate.knob(ctx, comp_slots.Comp_Release);
            if (try Knobs.drawWidget(
                ctx,
                &release_prm.normalized,
                release_label_id,
                .{ .no_val_display = release_no_val_display, .disabled = comp_release_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Comp_Release),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Comp_Release, release_prm.normalized, fx_state);
            }

            // Third knob
            var thresh_prm = fx_state.values.get(.Comp_Thresh).?.param;
            try plate.knob(ctx, comp_slots.Comp_Thresh);
            if (try Knobs.drawWidget(
                ctx,
                &thresh_prm.normalized,
                thresh_label_id,
                .{ .no_val_display = thresh_no_val_display, .disabled = thresh_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Comp_Thresh),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Comp_Thresh, thresh_prm.normalized, fx_state);
            }
        }
    }

    try plate.end(ctx);
    return rv;
}

fn outputPanel(ctx: imgui.ContextPtr, mode: Mode, fx_state: *FxCtrlState, transport: *const TransportState, translations: *TranslationStore, id_buf: *[64:0]u8) !?WidgetInput {
    var rv: ?WidgetInput = null;
    const value_display_disabled = (mode != .fx_ctrl and mode != .mapping_panel and mode != .fx_sel);
    const is_fx_mode = (mode == .fx_ctrl or mode == .mapping_panel or mode == .fx_sel);
    const is_strip = is_fx_mode and fx_state.track_state.mode == .channel_strip;

    // In a channel strip, the two buttons show the text that the plugin gives them, which can be longer than
    // the translations: its width is measured too.
    const strip_order: [:0]const u8 = if (fx_state.track_state.mode == .channel_strip) fx_state.track_state.label_pool.getFmtValue(.Tr_order) else "";
    const strip_sidechain: [:0]const u8 = if (fx_state.track_state.mode == .channel_strip) fx_state.track_state.label_pool.getFmtValue(.Tr_ext_sidechain) else "";
    const out_widest = try widestOf(ctx, &.{
        "Character",
        paramLabel(fx_state, .Out_Drive),
        paramLabel(fx_state, .Out_DriveChar),
        tr(translations, .trsprt_Out_Drive),
        tr(translations, .trsprt_Out_DriveChar),
        tr(translations, .fx_ctrl_Out_Pan),
        tr(translations, .trsprt_Out_Pan),
        tr(translations, .fx_ctrl_Out_Vol),
        tr(translations, .trsprt_Out_Vol),
    });
    const plate = try Plate.begin(ctx, .{ .slots = &out_slots.all, .title = moduleTitle(mode, .output), .title_alternatives = &moduleTitles(.output), .title_font = c1_theme.fonts.TAB, .columns = 2, .widest_label = out_widest, .column_gap = 24, .labels = &[_][:0]const u8{
        try widestOf(ctx, &.{ strip_order, tr(translations, .fx_ctrl_Tr_order_eq_s_c), tr(translations, .fx_ctrl_Tr_order_s_c_eq), tr(translations, .fx_ctrl_Tr_order_s_eq_c) }),
        "",
        "",
        "",
        try widestOf(ctx, &.{ strip_sidechain, tr(translations, .fx_ctrl_Tr_ext_sidechain), tr(translations, .fx_ctrl_Tr_ext_sidechain_shape), tr(translations, .fx_ctrl_Tr_ext_sidechain_comp) }),
        try widestOf(ctx, &.{ tr(translations, .fx_ctrl_Out_solo), tr(translations, .trsprt_Out_solo) }),
        tr(translations, .fx_ctrl_Out_mute),
        "",
    } });

    // First column
    {
        if (is_strip) {
            const mapped = fx_state.track_state.forward_map.get(.Tr_order) != null;
            const label: [:0]const u8 = if (mapped) fx_state.track_state.label_pool.getFmtValue(.Tr_order) else "-";
            try plate.button(ctx, out_slots.Tr_order, label, .right);
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
            try plate.button(ctx, out_slots.Tr_order, tr_order_display_label, .right);
            if (try roundButton(.{ ctx, tr_order_display_label, "##" ++ @tagName(c1.CCs.Tr_order), null, null, .right, tr_order_disabled })) {
                const next_order: ModulesOrder = switch (fx_state.track_state.getModulesOrder()) {
                    .@"EQ-S-C" => .@"S-C-EQ",
                    .@"S-C-EQ" => .@"S-EQ-C",
                    .@"S-EQ-C" => .@"EQ-S-C",
                };
                rv = .{ .cc = .Tr_order, .value = @as(f64, @floatFromInt(@backingInt(next_order))) };
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
                .id = try std.mem.printSentinel(id_buf, "Out_Drive", .{}, 0),
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

            // First knob
            var drive_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.zoom_horizontal)) / 127.0
            else
                fx_state.values.get(.Out_Drive).?.param.normalized;
            try plate.knob(ctx, out_slots.Out_Drive);
            if (try Knobs.drawWidget(
                ctx,
                &drive_val,
                drive_label_id,
                .{ .no_val_display = drive_no_val_display, .disabled = drive_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Out_Drive),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Out_Drive, drive_val, fx_state);
            }

            // Second knob
            var char_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.zoom_vertical)) / 127.0
            else
                fx_state.values.get(.Out_DriveChar).?.param.normalized;
            try plate.knob(ctx, out_slots.Out_DriveChar);
            if (try Knobs.drawWidget(
                ctx,
                &char_val,
                char_label_id,
                .{ .no_val_display = char_no_val_display, .disabled = char_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Out_DriveChar),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Out_DriveChar, char_val, fx_state);
            }

            // Third knob
            var pan_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.grid)) / 127.0
            else
                fx_state.values.get(.Out_Pan).?.param.normalized;
            try plate.knob(ctx, out_slots.Out_Pan);
            if (try Knobs.drawWidget(
                ctx,
                &pan_val,
                pan_label_id,
                .{ .no_val_display = pan_no_val_display, .disabled = pan_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Out_Pan),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Out_Pan, pan_val, fx_state);
            }
        }
    }

    // Second column
    {
        if (is_strip) {
            const mapped = fx_state.track_state.forward_map.get(.Tr_ext_sidechain) != null;
            const label: [:0]const u8 = if (mapped) fx_state.track_state.label_pool.getFmtValue(.Tr_ext_sidechain) else "-";
            try plate.button(ctx, out_slots.Tr_ext_sidechain, label, .right);
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
            try plate.button(ctx, out_slots.Tr_ext_sidechain, ext_sidechain_display_label, .right);
            if (try roundButton(.{ ctx, ext_sidechain_display_label, "##" ++ @tagName(c1.CCs.Tr_ext_sidechain), null, null, .right, ext_sidechain_disabled })) {
                const next_routing: SCRouting = switch (fx_state.scRouting) {
                    .off => .toShape,
                    .toShape => .toComp,
                    .toComp => .off,
                };
                rv = .{ .cc = .Tr_ext_sidechain, .value = @as(f64, @floatFromInt(@backingInt(next_routing))) };
            }
        }
        {
            const solo = buttonIsOn(fx_state, .Out_solo);
            const out_solo_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Out_solo,
                .transport => .trsprt_Out_solo,
                else => null,
            };
            const out_solo_label = if (out_solo_key) |key| tr(translations, key) else null;
            const out_solo_display_label: [:0]const u8 = out_solo_label orelse "-";
            const out_solo_disabled = (out_solo_label == null);
            try plate.button(ctx, out_slots.Out_solo, out_solo_display_label, .right);
            if (try roundButton(.{ ctx, out_solo_display_label, "##" ++ @tagName(c1.CCs.Out_solo), null, null, .right, out_solo_disabled, if (solo) solo_yellow else null })) {
                rv = .{ .cc = .Out_solo, .value = if (solo) 0 else 1 };
            }

            const mute = buttonIsOn(fx_state, .Out_mute);
            const out_mute_key: ?TranslationKey = switch (mode) {
                .fx_ctrl, .mapping_panel, .fx_sel => .fx_ctrl_Out_mute,
                else => null,
            };
            const out_mute_label = if (out_mute_key) |key| tr(translations, key) else null;
            const out_mute_display_label: [:0]const u8 = out_mute_label orelse "-";
            const out_mute_disabled = (out_mute_label == null);
            try plate.button(ctx, out_slots.Out_mute, out_mute_display_label, .right);
            if (try roundButton(.{ ctx, out_mute_display_label, "##" ++ @tagName(c1.CCs.Out_mute), null, null, .right, out_mute_disabled, if (mute) mute_red else null })) {
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
                .id = try std.mem.printSentinel(id_buf, "Out_Vol", .{}, 0),
            };
            var vol_val: f64 = if (mode == .transport)
                @as(f64, @floatFromInt(transport.tr_sel)) / 127.0
            else
                fx_state.values.get(.Out_Vol).?.param.normalized;
            try plate.knob(ctx, out_slots.Out_Vol);
            if (try Knobs.drawWidget(
                ctx,
                &vol_val,
                label_id,
                .{ .no_val_display = vol_no_val_display, .disabled = vol_disabled },
                plate.knob_w,
                @"editMode?"(fx_state, .Out_Vol),
            )) |knob_res| {
                rv = toWidgetInput(knob_res, .Out_Vol, vol_val, fx_state);
            }
        }
    }

    try plate.end(ctx);
    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
