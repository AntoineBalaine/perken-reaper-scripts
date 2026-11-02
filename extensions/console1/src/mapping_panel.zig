const std = @import("std");
const imgui = @import("reaper_imgui");
const mapping_actions = @import("action_types.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const AssignState = statemachine.AssignState;
const AssignSet = statemachine.AssignSet;
const c1 = @import("c1.zig");
const tr = @import("translations.zig").tr;
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const Translations = @import("translations.zig");
const TranslationStore = Translations.TranslationStore;
const TranslationKey = Translations.TranslationKey;
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");

const constants = @import("constants.zig");
const Theme = @import("theme/ReaperTheme.zig");
const c1_theme = @import("theme/c1_theme.zig");
const mappingKnob = @import("components/mappingKnob.zig");
const palette = @import("ui_palette");
const vr_widgets = @import("panel_widgets");
const icon_key = @import("components/icon_key.zig");
const Knobs = @import("knob");
const panel_theme = @import("panel_theme");
const widgets = @import("components/widgets.zig");
const module_plate = @import("components/module_plate.zig");
const combo_style = @import("components/combo_style.zig");
const Plate = module_plate.Plate;
const button_radius = @import("components/button.zig").default_radius;

pub fn drawMappingPanel(
    ctx: imgui.ContextPtr,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    // The bar of keys is all the way to the left, then the modules, then the assignments.
    if (try buttonBar(ctx, set, translations)) |action| {
        rv = action;
    }
    try fx_ctrl_panel.sectional(ctx);
    if (try controls(ctx, set, translations)) |action| {
        rv = action;
    }
    try imgui.SameLine(.{ctx});
    if (try formControls(ctx, set, translations)) |action| {
        rv = action;
    }
    return rv;
}

// Function to handle the controls column: the modules, on the plates that they have in the panel of the FX controls. Every
// module that has an FX is open at once.
fn controls(
    ctx: imgui.ContextPtr,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    // Because the plates are as tall as the tallest, as they are in the panel of the FX controls.
    module_plate.startFrame();

    // A channel strip is one plugin: its modules are one card.
    if (set.getConst(.STRIP) != null) {
        if (try stripCard(ctx, set, translations)) |act| rv = act;
        try fx_ctrl_panel.sectional(ctx);
        return rv;
    }

    inline for ([_]ModuleDef{ input_def, shape_def, eq_def, comp_def, output_def }) |def| {
        if (try modulePanel(ctx, def, set, translations)) |act| rv = act;
        try fx_ctrl_panel.sectional(ctx);
    }

    return rv;
}

/// The state that owns the controls of a module: the one of the channel strip when the track has one, and the one of the
/// module when it has an FX. Null when the module has no FX, which leaves its controls disabled.
fn ownerOf(set: *const AssignSet, module: ModulesList) ?*const AssignState {
    if (set.getConst(.STRIP)) |strip| return strip;
    const state = set.getConst(module) orelse return null;
    return if (state.assign_fx_index != null) state else null;
}

fn getControlMapping(assign_state: *const AssignState, cc: c1.CCs) ?u32 {
    const cc_name = @tagName(cc);
    switch (assign_state.current_mappings) {
        inline else => |mapping| {
            inline for (@typeInfo(@TypeOf(mapping)).@"struct".field_names) |field_name| {
                // Skip non-parameter fields because they are not optional u16 values
                if (comptime std.mem.eql(u8, field_name, "version")) continue;
                if (comptime std.mem.eql(u8, field_name, "fx_preset")) continue;

                if (std.mem.eql(u8, field_name, cc_name)) {
                    if (@field(mapping, field_name)) |param| {
                        return @intCast(param);
                    }
                }
            }
            return null;
        },
    }
}

/// How many entries of the assignments stand in a column, as the rows of a page stand in the list of the tracks.
const entry_rows = 10;
const entry_capacity = 96;

const Entry = struct { cc: c1.CCs, text: [96:0]u8 };

/// The assignments of every module, in the order of the modules.
fn collectEntries(set: *const AssignSet, entries: *[entry_capacity]Entry) usize {
    // Because every field of the mapping of every module is visited at compile time, the default limit is too low.
    @setEvalBranchQuota(100_000);
    var count: usize = 0;
    inline for (comptime std.enums.values(ModulesList)) |module| {
        if (set.getConst(module)) |assign_state| {
            switch (assign_state.current_mappings) {
                inline else => |mapping| {
                    inline for (@typeInfo(@TypeOf(mapping)).@"struct".field_names) |field_name| {
                        if (comptime std.mem.eql(u8, field_name, "version")) continue;
                        if (comptime !@hasField(c1.CCs, field_name)) continue;
                        if (@field(mapping, field_name)) |param_idx| {
                            if (count < entries.len) {
                                const param_name = if (param_idx < assign_state.param_store.len())
                                    assign_state.param_store.getName(@intCast(param_idx))
                                else
                                    "?";
                                entries[count].cc = @field(c1.CCs, field_name);
                                _ = std.mem.printSentinel(&entries[count].text, "{s} -> {s} (#{d})", .{ field_name, param_name, param_idx }, 0) catch {
                                    entries[count].text[0] = 0;
                                };
                                count += 1;
                            }
                        }
                    }
                },
            }
        }
    }
    return count;
}

/// Writes a text in the room of a column, cut at its width, and shows it in full under the mouse.
fn clippedText(ctx: imgui.ContextPtr, text: [:0]const u8, width: f64, color: c_int) !void {
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &x, &y });
    var line_w: f64 = undefined;
    var line_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, "Ag", &line_w, &line_h });
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try imgui.PushClipRect(.{ ctx, x, y, x + width, y + line_h, true });
    try imgui.DrawList_AddText(.{ dl, x, y, color, text });
    try imgui.PopClipRect(.{ctx});
    try imgui.Dummy(.{ ctx, width, line_h });
    if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None })) try imgui.SetTooltip(.{ ctx, text });
}

// Function to handle the two cards at the right of the modules: the mapping card, which has MIDI learn, the preset of the focused
// module and the key that closes the panel, and the card of the assignments, which is laid out as the list of the tracks is:
// its entries are in columns that fold after ten of them. The mapping of each module is saved from its own plate.
fn formControls(
    ctx: imgui.ContextPtr,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    var entries: [entry_capacity]Entry = undefined;
    const count = collectEntries(set, &entries);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    var line_w: f64 = undefined;
    var line_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, "Ag", &line_w, &line_h });
    var spacing_x: f64 = undefined;
    var spacing_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y });
    const min_content_h = entry_rows * line_h + (entry_rows - 1) * spacing_y;

    // The plates of the modules start under the line of their plugin: the card leaves the same room, so that they are level.
    try imgui.Dummy(.{ ctx, 1, line_h + 4 });
    if (try assignmentsCard(ctx, &entries, count, translations, min_content_h, line_h, spacing_y)) |action| rv = action;

    return rv;
}

/// The radius of the keys of the bar, a little bigger than the keys of the panel.
const bar_key_radius = 11.0;

/// The bar of keys all the way to the left of the window, one under the other, with no labels: the key that records a MIDI
/// learn, which is red while it listens as the record key of the transport is when it records, and the key that closes the panel.
/// What each one does is in its tooltip. A mark under them says when a mapping could not be saved.
fn buttonBar(
    ctx: imgui.ContextPtr,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    var text_buf: [256:0]u8 = undefined;
    const assign_state = set.activeConst();

    // Because the next item is put at the top of what is drawn here, the bar is a group: its top is the one of the modules.
    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    // The plates of the modules start under the line of their plugin: the bar leaves the same room, so that they are level.
    var line_w: f64 = undefined;
    var line_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, "Ag", &line_w, &line_h });
    try imgui.Dummy(.{ ctx, 1, line_h + 4 });

    const plate = try Plate.begin(ctx, .{
        .slots = &.{},
        .columns = 1,
        .widest_label = "Ag",
        .title = "",
        // Because the line of the title takes the height of its font, the bar has the font of the plates, and so their height.
        .title_font = c1_theme.fonts.TAB,
        .min_width = bar_key_radius * 2,
    });

    // The keys are flush with the top of the bar: it has no title, so they start where its face starts, not under the line that
    // a title would have.
    try imgui.SetCursorScreenPos(.{ ctx, plate.origin.x, plate.start.y + module_plate.pad });
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // While it listens, what it waits for is its tooltip.
        const tooltip: [:0]const u8 = if (!assign_state.midi_learn_active)
            tr(translations, .mapping_midi_learn)
        else if (assign_state.selected_control != null and assign_state.learned_param == null)
            std.mem.printSentinel(&text_buf, "CC: {s} -- {s}", .{
                @tagName(assign_state.selected_control.?),
                tr(translations, .mapping_midi_learn_touch_param),
            }, 0) catch ""
        else if (assign_state.learned_param != null and assign_state.selected_control == null) blk: {
            const param_name = if (assign_state.learned_param.? < assign_state.param_store.len())
                assign_state.param_store.getName(@intCast(assign_state.learned_param.?))
            else
                "?";
            break :blk std.mem.printSentinel(&text_buf, "Param: {s} (#{d}) -- {s}", .{
                param_name,
                assign_state.learned_param.?,
                tr(translations, .mapping_midi_learn_move_control),
            }, 0) catch "";
        } else tr(translations, .mapping_midi_learn_waiting);
        const record_red: c_int = @bitCast(@as(u32, 0xE03A3AFF));
        if (try widgets.roundButton(.{
            ctx,
            "",
            "##midi_learn",
            tooltip,
            bar_key_radius,
            .right,
            false,
            if (assign_state.midi_learn_active) record_red else null,
            assign_state.midi_learn_active,
            .rec,
        })) {
            rv = .{ .assign_toggle_midi_learn = {} };
        }

        // The key of the single plugin mode opens the browser of the channel strip, and it glows while the track has a strip.
        if (try widgets.roundButton(.{
            ctx,
            "",
            "##map_single",
            if (set.getConst(.STRIP) != null) tr(translations, .mapping_multi_fx) else tr(translations, .mapping_single_fx),
            bar_key_radius,
            .right,
            false,
            if (set.getConst(.STRIP) != null) Knobs.led_orange else null,
            set.getConst(.STRIP) != null,
            .single,
        })) {
            rv = .{ .assign_toggle_single_fx = {} };
        }

        if (try widgets.roundButton(.{ ctx, "", "##map_close", tr(translations, .mapping_close), bar_key_radius, .right, false, null, null, .cross })) {
            rv = .{ .assign_cancel = {} };
        }

        // What went wrong when a mapping was saved, in the module where it did.
        inline for (comptime std.enums.values(ModulesList)) |module| {
            if (set.getConst(module)) |state| {
                if (state.save_error) |err_key| try errorMark(ctx, tr(translations, err_key));
            }
        }
    }
    try plate.end(ctx);
    return rv;
}

/// A red warning triangle that says what went wrong in its tooltip. It is drawn, because the icon font has no warning sign.
fn errorMark(ctx: imgui.ContextPtr, message: [:0]const u8) !void {
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &x, &y });
    const size: f64 = button_radius * 2;
    _ = try imgui.InvisibleButton(.{ ctx, "##save_error", size, size });
    const hovered = try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None });
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try imgui.DrawList_AddTriangleFilled(.{ dl, x + size / 2, y + 1, x + 1, y + size - 1, x + size - 1, y + size - 1, if (hovered) panel_theme.amber else panel_theme.red });
    try imgui.DrawList_AddRectFilled(.{ dl, x + size / 2 - 1, y + 6, x + size / 2 + 1, y + 11, panel_theme.text_engraved_shadow, 0 });
    try imgui.DrawList_AddRectFilled(.{ dl, x + size / 2 - 1, y + 12.5, x + size / 2 + 1, y + 14.5, panel_theme.text_engraved_shadow, 0 });
    if (hovered) try imgui.SetTooltip(.{ ctx, message });
}

/// The card of the assignments: the entries, in columns that fold after ten of them, each with the key that removes its mapping.
fn assignmentsCard(
    ctx: imgui.ContextPtr,
    entries: *const [entry_capacity]Entry,
    count: usize,
    translations: *TranslationStore,
    min_content_h: f64,
    line_h: f64,
    spacing_y: f64,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const key_w = try saveKeyWidth(ctx);

    // The columns are as wide as the widest entry and its key.
    var widest_entry: f64 = 0;
    for (entries[0..count]) |*entry| {
        var w: f64 = undefined;
        var h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, std.mem.sliceTo(&entry.text, 0), &w, &h });
        widest_entry = @max(widest_entry, w);
    }
    const none_text = tr(translations, .mapping_none);
    if (count == 0) {
        var h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, none_text, &widest_entry, &h });
    }
    const entry_w = widest_entry + 6 + (if (count == 0) 0 else key_w);
    const column_count: usize = @max(1, (count + entry_rows - 1) / entry_rows);
    const column_gap = 12.0;

    const plate = try Plate.begin(ctx, .{
        .slots = &.{},
        .columns = 1,
        .widest_label = "Ag",
        .title = tr(translations, .mapping_assignments),
        .title_font = c1_theme.fonts.TAB,
        .min_width = @as(f64, @floatFromInt(column_count)) * entry_w + @as(f64, @floatFromInt(column_count - 1)) * column_gap,
        .min_content_h = min_content_h,
    });

    if (count == 0) {
        try imgui.SetCursorScreenPos(.{ ctx, plate.origin.x, plate.origin.y });
        try clippedText(ctx, none_text, entry_w, panel_theme.text_dim);
    }
    for (entries[0..count], 0..) |*entry, i| {
        const column: f64 = @floatFromInt(i / entry_rows);
        const row: f64 = @floatFromInt(i % entry_rows);
        const x = plate.origin.x + column * (entry_w + column_gap);
        const y = plate.origin.y + row * (line_h + spacing_y);
        try imgui.SetCursorScreenPos(.{ ctx, x, y });
        try clippedText(ctx, std.mem.sliceTo(&entry.text, 0), widest_entry, panel_theme.text);
        var id_buf: [64:0]u8 = undefined;
        const id = std.mem.printSentinel(&id_buf, "##rm_{s}", .{@tagName(entry.cc)}, 0) catch "##rm";
        if (try iconKey(ctx, id, x + widest_entry + 6, y, key_w, line_h, c1_theme.Icons.get(.close), true, false, null)) {
            rv = .{ .assign_remove_mapping = entry.cc };
        }
    }
    try plate.end(ctx);
    return rv;
}

const Slot = module_plate.Slot;
const TextPosition = @import("components/button.zig").TextPosition;
const mappingButton = @import("components/mappingButton.zig");

/// A control of a module of the mapping panel: its place on the plate, which is the one it has in the panel of the FX controls.
const Control = struct {
    cc: c1.CCs,
    slot: Slot,
    /// The translation of the label of the control when it is not the one that the panel of the FX controls has for it.
    label_key: ?TranslationKey = null,
    /// The control only exists on a channel strip.
    strip_only: bool = false,
    /// Which view of its module the control is in: the controls of a module that has two views, of which the toggle chooses one, are in
    /// the main view or in the one of the filters, and the others are in both.
    view: View = .always,
    /// The control is one of the track controls of the console, which are wired to the track and not mapped to a plugin: it is
    /// drawn and disabled.
    fixed: bool = false,
};

const View = enum { always, main, filters };

/// Whether the compressor shows its filters, which the key at the bottom left of its plate chooses, instead of its knobs. It is only
/// in the mapping panel, and only for the mapping: the filters are what the filters to compressor key of the FX controls sends to the
/// compressor, which has no knob of its own for them.
var comp_filters_view = false;

/// The view of the compressor, for the tests.
pub fn testSetFiltersView(on: bool) void {
    comp_filters_view = on;
}

const ModuleDef = struct {
    module: ModulesList,
    /// What names the keys of the plate, which does not change with the language, as its title does.
    id: [:0]const u8,
    /// The translation of the title of the plate.
    title_key: TranslationKey,
    /// All the slots of the module in the panel of the FX controls, so that the plate has the same measures.
    slots: []const Slot,
    columns: u8,
    controls: []const Control,
    /// A label that gives the width of the knobs, besides the labels of the controls.
    widest: [:0]const u8 = "",
    /// The module has a bypass key at the top left of its plate.
    has_bypass: bool = false,
    column_gap: f64 = 0,
    /// The columns of knobs after the first are moved to the right by half of the room that the plate has to the right of its
    /// last column. The plate of the FX controls is as wide as the labels of its buttons are, which the mapping panel does not
    /// have, and the knobs would otherwise stay at the left of an empty face.
    spread: bool = false,
    /// How much narrower the plate is here than the width that it has in the panel of the FX controls.
    width_trim: f64 = 0,
    /// The plate has a toggle at its bottom left that swaps its knobs for the ones of the filters.
    filters_toggle: bool = false,
};

const input_slots = fx_ctrl_panel.input_slots;
const input_def = ModuleDef{
    .module = .INPUT,
    .id = "INPUT",
    .title_key = .fx_ctrl_card_input,
    .slots = &input_slots.all,
    .columns = 2,
    .widest = "Input Gain",
    .spread = true,
    .width_trim = 10,
    .controls = &.{
        .{ .cc = .Inpt_Gain, .slot = input_slots.Inpt_Gain },
        .{ .cc = .Inpt_HiCut, .slot = input_slots.Inpt_HiCut },
        .{ .cc = .Inpt_LoCut, .slot = input_slots.Inpt_LoCut },
    },
};

const shape_slots = fx_ctrl_panel.shape_slots;
const shape_def = ModuleDef{
    .module = .GATE,
    .id = "SHAPE",
    .title_key = .fx_ctrl_card_shape,
    .slots = &shape_slots.all,
    .columns = 2,
    .widest = "Release",
    .has_bypass = true,
    .controls = &.{
        .{ .cc = .Shp_shape, .slot = shape_slots.Shp_shape },
        .{ .cc = .Shp_Gate, .slot = shape_slots.Shp_Gate },
        .{ .cc = .Shp_hard_gate, .slot = shape_slots.Shp_hard_gate },
        .{ .cc = .Shp_GateRelease, .slot = shape_slots.Shp_GateRelease },
        .{ .cc = .Shp_sustain, .slot = shape_slots.Shp_sustain },
        .{ .cc = .Shp_Punch, .slot = shape_slots.Shp_Punch },
    },
};

const eq_slots = fx_ctrl_panel.eq_slots;
const eq_def = ModuleDef{
    .module = .EQ,
    .id = "EQUALIZER",
    .title_key = .fx_ctrl_card_eq,
    .slots = &eq_slots.all,
    .columns = 4,
    .has_bypass = true,
    .controls = &.{
        .{ .cc = .Eq_eq, .slot = eq_slots.Eq_eq },
        .{ .cc = .Eq_lp_shape, .slot = eq_slots.Eq_lp_shape },
        .{ .cc = .Eq_LoFrq, .slot = eq_slots.Eq_LoFrq },
        .{ .cc = .Eq_LoGain, .slot = eq_slots.Eq_LoGain },
        .{ .cc = .Eq_LoMidQ, .slot = eq_slots.Eq_LoMidQ },
        .{ .cc = .Eq_LoMidFrq, .slot = eq_slots.Eq_LoMidFrq },
        .{ .cc = .Eq_LoMidGain, .slot = eq_slots.Eq_LoMidGain },
        .{ .cc = .Eq_HiMidQ, .slot = eq_slots.Eq_HiMidQ },
        .{ .cc = .Eq_HiMidFrq, .slot = eq_slots.Eq_HiMidFrq },
        .{ .cc = .Eq_HiMidGain, .slot = eq_slots.Eq_HiMidGain },
        .{ .cc = .Eq_hp_shape, .slot = eq_slots.Eq_hp_shape },
        .{ .cc = .Eq_HiFrq, .slot = eq_slots.Eq_HiFrq },
        .{ .cc = .Eq_HiGain, .slot = eq_slots.Eq_HiGain },
    },
};

const comp_slots = fx_ctrl_panel.comp_slots;
const comp_def = ModuleDef{
    .module = .COMP,
    .id = "COMPRESSOR",
    .title_key = .fx_ctrl_card_comp,
    .slots = &comp_slots.all,
    .columns = 2,
    .has_bypass = true,
    .filters_toggle = true,
    .controls = &.{
        .{ .cc = .Comp_comp, .slot = comp_slots.Comp_comp },
        .{ .cc = .Comp_Ratio, .slot = comp_slots.Comp_Ratio, .view = .main },
        .{ .cc = .Comp_DryWet, .slot = comp_slots.Comp_DryWet, .view = .main },
        .{ .cc = .Comp_Attack, .slot = comp_slots.Comp_Attack, .view = .main },
        .{ .cc = .Comp_Release, .slot = comp_slots.Comp_Release, .view = .main },
        .{ .cc = .Comp_Thresh, .slot = comp_slots.Comp_Thresh, .view = .main },
        // The filters take the places of the first two knobs of the second column, which are the rows of the filters of the input.
        .{ .cc = .Comp_HiCut, .slot = comp_slots.Comp_Attack, .view = .filters },
        .{ .cc = .Comp_LoCut, .slot = comp_slots.Comp_Release, .view = .filters },
    },
};

const out_slots = fx_ctrl_panel.out_slots;
const output_def = ModuleDef{
    .module = .OUTPT,
    .id = "OUTPUT",
    .title_key = .fx_ctrl_card_output,
    .slots = &out_slots.all,
    .columns = 2,
    .column_gap = 24,
    .controls = &.{
        // The pan, the solo, the mute and the volume are the track controls of the console: they are wired to the track, and are
        // not mapped. The order and the sidechain are the two controls that only a channel strip has.
        .{ .cc = .Tr_order, .slot = out_slots.Tr_order, .label_key = .mapping_order, .strip_only = true },
        .{ .cc = .Out_Drive, .slot = out_slots.Out_Drive },
        .{ .cc = .Out_DriveChar, .slot = out_slots.Out_DriveChar },
        .{ .cc = .Out_Pan, .slot = out_slots.Out_Pan },
        .{ .cc = .Tr_ext_sidechain, .slot = out_slots.Tr_ext_sidechain, .strip_only = true },
        .{ .cc = .Out_solo, .slot = out_slots.Out_solo, .fixed = true },
        .{ .cc = .Out_mute, .slot = out_slots.Out_mute, .fixed = true },
        .{ .cc = .Out_Vol, .slot = out_slots.Out_Vol },
    },
};

fn controlLabel(comptime c: Control, translations: *TranslationStore) [:0]const u8 {
    return tr(translations, c.label_key orelse @field(TranslationKey, "fx_ctrl_" ++ @tagName(c.cc)));
}

/// The labels of the slots of a module for its plate: the keys that are mapped have the width of their combo, and the other slots none.
fn comboLabels(comptime def: ModuleDef) [def.slots.len][:0]const u8 {
    var labels: [def.slots.len][:0]const u8 = undefined;
    for (def.slots, 0..) |slot, i| {
        labels[i] = "";
        if (slot.kind == .knob) continue;
        for (def.controls) |c| {
            if (std.meta.eql(c.slot, slot)) labels[i] = mappingButton.combo_label;
        }
    }
    return labels;
}

/// The widest of the labels of the knobs of a module, which gives their width.
fn widestLabel(ctx: imgui.ContextPtr, comptime def: ModuleDef, translations: *TranslationStore) ![:0]const u8 {
    var widest: [:0]const u8 = def.widest;
    var widest_w: f64 = -1;
    var h: f64 = undefined;
    if (widest.len > 0) try imgui.CalcTextSize(.{ ctx, widest, &widest_w, &h });
    inline for (def.controls) |c| {
        if (c.slot.kind == .knob) {
            const label = controlLabel(c, translations);
            var w: f64 = undefined;
            try imgui.CalcTextSize(.{ ctx, label, &w, &h });
            if (w > widest_w) {
                widest = label;
                widest_w = w;
            }
        }
    }
    return widest;
}

/// The width that the face of the plate of each module had on the frame before, which the line of its plugin does not go over:
/// a name that is wider is cut, because the group of the module would otherwise be wider than its plate.
var face_widths: [5]f64 = @splat(0);

/// The line over a plate that has the plugin that the module maps. It is clickable, and opens the browser of the plugins
/// of the module, to swap the plugin or to choose one when there is none. A channel strip is one plugin: its name is over the
/// first plate.
fn fxHeader(
    ctx: imgui.ContextPtr,
    module: ModulesList,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    const strip = set.getConst(.STRIP);
    if (strip != null and module != .INPUT) {
        // Because the plates are aligned, the line has the height of the one that has a name.
        var blank_w: f64 = undefined;
        var blank_h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, "Ag", &blank_w, &blank_h });
        try imgui.Dummy(.{ ctx, 1, blank_h + 4 });
        return null;
    }
    const index: usize = @backingInt(module);
    std.debug.assert(index < face_widths.len);
    const swap_module: ModulesList = if (strip != null) .STRIP else module;
    const name: [:0]const u8 = if (strip) |strip_state|
        (if (strip_state.target_fx.len > 0) strip_state.target_fx else tr(translations, .mapping_no_fx))
    else
        set.activeConst().module_fx_names.get(@fromBackingInt(@intCast(@backingInt(module)))) orelse tr(translations, .mapping_no_fx);

    var text_w: f64 = undefined;
    var text_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, name, &text_w, &text_h });

    // The name is in a frame, as a button that opens the browser: a combo-like display with a chevron at its right edge, which
    // lights in the amber of the panel under the mouse. It is cut at the width of the plate, which is not known on the first
    // frame: the name shows from the second one.
    const frame_h = text_h + 4;
    const wanted_w = text_w + 6 + mappingKnob.chevron_width + 4;
    const open_key_w = try saveKeyWidth(ctx);
    const row_w = if (face_widths[index] > 0) @max(@min(wanted_w, face_widths[index] - open_key_w - key_gap), 1) else 1;
    var id_buf: [64:0]u8 = undefined;
    const id = std.mem.printSentinel(&id_buf, "##fxsel_{s}", .{@tagName(module)}, 0) catch "##fxsel";
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &x, &y });
    const clicked = try imgui.InvisibleButton(.{ ctx, id, row_w, frame_h });
    const hovered = try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None });
    const held = try imgui.IsItemActive(.{ctx});

    const dl = try imgui.GetWindowDrawList(.{ctx});
    // Because the frame has no fill, as the combos of the panel, it shows the color of the surface that it is on.
    if (held or hovered) try imgui.DrawList_AddRectFilled(.{ dl, x, y, x + row_w, y + frame_h, if (held) panel_theme.amber_soft else panel_theme.amber_faint, 3 });
    try imgui.DrawList_AddRect(.{ dl, x, y, x + row_w, y + frame_h, if (hovered) panel_theme.amber else combo_style.withAlpha(panel_theme.frame_border, combo_style.outline_alpha), 3, null, 1 });
    try imgui.PushClipRect(.{ ctx, x + 1, y, x + row_w - mappingKnob.chevron_width, y + frame_h, true });
    try imgui.DrawList_AddText(.{ dl, x + 6, y + 2, if (hovered) panel_theme.text else panel_theme.label, name });
    try imgui.PopClipRect(.{ctx});
    try mappingKnob.drawChevron(dl, x + row_w, y, y + frame_h, if (hovered) panel_theme.amber else combo_style.withAlpha(panel_theme.text_dim, combo_style.chevron_alpha));

    if (hovered) {
        // The name is read in full here, as it may be cut.
        var tip_buf: [768:0]u8 = undefined;
        const tip = std.mem.printSentinel(&tip_buf, "{s}\n{s}", .{ name, tr(translations, .mapping_change_fx) }, 0) catch tr(translations, .mapping_change_fx);
        try imgui.SetTooltip(.{ ctx, tip });
    }

    // The key at the right of the name opens the window of the plugin, which is where its own controls are.
    var open_id_buf: [64:0]u8 = undefined;
    const open_id = std.mem.printSentinel(&open_id_buf, "##openfx_{s}", .{@tagName(module)}, 0) catch "##openfx";
    const open_clicked = try iconKey(ctx, open_id, x + row_w + key_gap, y, open_key_w, frame_h, c1_theme.Icons.get(.wrench), ownerOf(set, module) != null, false, tr(translations, .mapping_open_fx));
    if (clicked) return .{ .assign_swap_fx = swap_module };
    if (open_clicked) return .{ .assign_open_fx_ui = swap_module };
    return null;
}

/// The room between the title of a plate and its save key.
const save_gap = 8.0;

/// The width of the save key, which is its symbol and a little room around it.
fn saveKeyWidth(ctx: imgui.ContextPtr) !f64 {
    try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
    defer imgui.PopFont(.{ctx}) catch {};
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, c1_theme.Icons.get(.save), &w, &h });
    return w + 8;
}

/// A small raised key with a symbol of the icon font on it, which is the one that the settings have too.
fn iconKey(ctx: imgui.ContextPtr, id: [:0]const u8, x: f64, y: f64, w: f64, h: f64, icon: [:0]const u8, enabled: bool, lit: bool, tooltip: ?[:0]const u8) !bool {
    return icon_key.draw(ctx, id, x, y, w, h, icon, enabled, lit, tooltip, null);
}

/// The place of the keys at the right of the title of a plate: the first one is the save key, and the next ones follow it.
fn titleKeyX(plate: Plate, title_w: f64, key_w: f64, index: usize) f64 {
    return plate.start.x + module_plate.pad + 2 + title_w + save_gap + @as(f64, @floatFromInt(index)) * (key_w + key_gap);
}

/// The room between two keys at the right of a title.
const key_gap = 4.0;

/// The height of the keys at the right of a title.
fn titleKeyHeight(ctx: imgui.ContextPtr) !f64 {
    var line_w: f64 = undefined;
    var line_h: f64 = undefined;
    try imgui.PushFont(.{ ctx, c1_theme.fonts.TAB });
    try imgui.CalcTextSize(.{ ctx, "Ag", &line_w, &line_h });
    try imgui.PopFont(.{ctx});
    return line_h + 2;
}

/// The key that saves the mapping of a module, at the right of the title of its plate. It returns whether it was pressed.
fn saveKey(ctx: imgui.ContextPtr, plate: Plate, comptime id: [:0]const u8, title_w: f64, enabled: bool, translations: *TranslationStore) !bool {
    const key_w = try saveKeyWidth(ctx);
    return iconKey(ctx, "##save_" ++ id, titleKeyX(plate, title_w, key_w, 0), plate.start.y + module_plate.pad, key_w, try titleKeyHeight(ctx), c1_theme.Icons.get(.save), enabled, false, tr(translations, .mapping_save));
}

/// The key next to the save key that says whether the mapping stores the state of the plugin in its map file, as it is when
/// the mapping is saved. It is a pin that glows when it is on. It returns whether it was pressed.
fn storeKey(ctx: imgui.ContextPtr, plate: Plate, comptime id: [:0]const u8, title_w: f64, owner: ?*const AssignState, translations: *TranslationStore) !bool {
    const key_w = try saveKeyWidth(ctx);
    const state = owner orelse return false;
    const enabled = true;
    return iconKey(ctx, "##store_" ++ id, titleKeyX(plate, title_w, key_w, 1), plate.start.y + module_plate.pad, key_w, try titleKeyHeight(ctx), c1_theme.Icons.get(.pin), enabled, state.store_preset_data, tr(translations, .mapping_store_preset));
}

/// A control of a module, at its slot of the plate: a knob or a key, with the combo of its parameter where the label is. A
/// module that has no FX has no owner: its controls are drawn disabled, with nothing mapped.
fn control(
    ctx: imgui.ContextPtr,
    plate: Plate,
    comptime c: Control,
    owner: ?*const AssignState,
    column_shift: f64,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    // A control that is wired to the track has nothing mapped, and nothing to choose.
    const mappable_owner: ?*const AssignState = if (c.fixed) null else owner;
    const disabled = mappable_owner == null;
    if (c.fixed and owner != null) try imgui.BeginDisabled(.{ctx});
    defer if (c.fixed and owner != null) {
        imgui.EndDisabled(.{ctx}) catch {};
    };

    const assigned: ?[:0]const u8 = if (mappable_owner) |assign_state|
        (if (getControlMapping(assign_state, c.cc)) |param|
            (if (param < assign_state.param_store.len()) assign_state.param_store.getName(@intCast(param)) else "?")
        else
            null)
    else
        null;
    const selected = if (mappable_owner) |assign_state| assign_state.selected_control == c.cc else false;
    const label = controlLabel(c, translations);
    const param_store: ?*const statemachine.ParamStore = if (mappable_owner) |assign_state| &assign_state.param_store else null;

    const mVal = switch (c.slot.kind) {
        .knob => blk: {
            try plate.knob(ctx, c.slot);
            if (c.slot.col >= 1 and column_shift > 0) {
                var knob_x: f64 = undefined;
                var knob_y: f64 = undefined;
                try imgui.GetCursorScreenPos(.{ ctx, &knob_x, &knob_y });
                try imgui.SetCursorScreenPos(.{ ctx, knob_x + column_shift, knob_y });
            }
            const label_id = Knobs.LabelId{ .label = label, .id = @tagName(c.cc) };
            const knob_value: f32 = if (mappable_owner) |assign_state| assign_state.knob_values[@backingInt(c.cc)] else 0.5;
            break :blk try mappingKnob.drawWidget(
                ctx,
                knob_value,
                label_id,
                .{ .disabled = disabled, .knob_bg = if (selected) panel_theme.amber_faint else null },
                plate.knob_w,
                c.cc,
                assigned,
                param_store,
                translations,
            );
        },
        .button, .button_below => blk: {
            const position: TextPosition = if (c.slot.kind == .button) .right else .below;
            try plate.button(ctx, c.slot, mappingButton.combo_label, position);
            break :blk try mappingButton.mappingButton(ctx, label, "##" ++ @tagName(c.cc), position, disabled, selected, c.cc, assigned, param_store, translations);
        },
    };

    if (mVal) |val| {
        switch (val) {
            .click => rv = .{ .assign_select_control = c.cc },
            .param_idx => |i| rv = .{ .assign_add_mapping = .{ .param = @intCast(i), .control = c.cc } },
            .remove_mapping => rv = .{ .assign_remove_mapping = c.cc },
            .value_changed => |new_val| rv = .{ .assign_update_knob = .{ .cc = c.cc, .value = new_val } },
        }
    }
    return rv;
}

/// The toggle at the bottom left of the plate of the compressor, which is the one of the VR-09 panel: a rocker that slides and lights
/// up. It is in the column of the first knob, on the row of the last one, where there is room. It has no label: its name is in its
/// tooltip.
fn filtersToggle(ctx: imgui.ContextPtr, plate: Plate, translations: *TranslationStore) !void {
    const column = plate.center(comp_slots.Comp_Ratio);
    const row = plate.center(comp_slots.Comp_Thresh);
    // The rocker is 30 wide and its frame is 20 high.
    try imgui.SetCursorScreenPos(.{ ctx, column.x - 15, row.y - 10 });
    var panel: vr_widgets.Panel = .{ .ctx = ctx };
    _ = vr_widgets.toggle(&panel, "", &comp_filters_view);
    if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None })) try imgui.SetTooltip(.{ ctx, tr(translations, .mapping_comp_filters) });
}

/// Starts the plate of a module, with the measures that it has in the panel of the FX controls. A bare plate is a section of the
/// card of a channel strip: it has no face and no title.
fn beginModulePlate(
    ctx: imgui.ContextPtr,
    comptime def: ModuleDef,
    translations: *TranslationStore,
    bare: bool,
    title_room: f64,
) !Plate {
    const labels = comptime comboLabels(def);
    const bypass_pitch = button_radius * 2 + 4 + try mappingButton.comboWidth(ctx) + 8;
    return Plate.begin(ctx, .{
        .slots = def.slots,
        .columns = def.columns,
        .widest_label = try widestLabel(ctx, def, translations),
        .labels = &labels,
        .min_pitch = if (def.has_bypass) bypass_pitch else 0,
        // Because the memory of a plate is keyed on its table of slots, which the panel of the FX controls has too, the plate
        // of a module here is the size that it has there. The room of the keys at the right of the title is only for this panel,
        // and does not go in that memory.
        .extra_width = title_room,
        .column_gap = def.column_gap,
        .width_trim = def.width_trim,
        .title = if (bare) "" else tr(translations, def.title_key),
        .title_font = c1_theme.fonts.TAB,
        .bare = bare,
    });
}

/// The controls of a module on its plate. A module that has no FX has nothing to map, and its controls are disabled.
fn moduleBody(
    ctx: imgui.ContextPtr,
    comptime def: ModuleDef,
    plate: Plate,
    owner: ?*const AssignState,
    is_strip: bool,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    if (owner == null) try imgui.BeginDisabled(.{ctx});
    defer if (owner == null) {
        imgui.EndDisabled(.{ctx}) catch {};
    };
    // The room that is right of the last column of knobs, half of which the columns after the first move into.
    const free_right = plate.width - (plate.x_shift + plate.knob_w + @as(f64, @floatFromInt(def.columns - 1)) * plate.pitch);
    const column_shift: f64 = if (def.spread) @max(free_right / 2, 0) else 0;
    inline for (def.controls) |c| {
        const in_view = switch (c.view) {
            .always => true,
            .main => !comp_filters_view,
            .filters => comp_filters_view,
        };
        if (in_view and (!c.strip_only or is_strip)) {
            if (try control(ctx, plate, c, owner, column_shift, translations)) |act| rv = act;
        }
    }
    if (def.filters_toggle) try filtersToggle(ctx, plate, translations);
    return rv;
}

/// The plate of a module, under the line of its plugin, with the key that saves its mapping at the right of its title.
fn modulePanel(
    ctx: imgui.ContextPtr,
    comptime def: ModuleDef,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const owner = ownerOf(set, def.module);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (try fxHeader(ctx, def.module, set, translations)) |act| rv = act;

    const title_w = try titleWidth(ctx, tr(translations, def.title_key));
    // Because the keys are at the right of the title, the plate is as wide as all of them.
    const title_room = title_w + 2 + save_gap + 2 * try saveKeyWidth(ctx) + key_gap;
    const plate = try beginModulePlate(ctx, def, translations, false, title_room);

    if (try saveKey(ctx, plate, def.id, title_w, owner != null, translations)) {
        rv = .{ .assign_request_save = def.module };
    }
    if (try storeKey(ctx, plate, def.id, title_w, owner, translations)) {
        rv = .{ .assign_toggle_store_preset = def.module };
    }

    if (try moduleBody(ctx, def, plate, owner, false, translations)) |act| rv = act;
    face_widths[@backingInt(def.module)] = plate.width + module_plate.pad * 2;
    try plate.end(ctx);
    return rv;
}

/// The size that the card of the channel strip had on the frame before.
var strip_card: module_plate.CardSize = .{};
/// What names the keys of the card of the channel strip, which does not change with the language, as its title does.
const strip_id: [:0]const u8 = "CHANNEL STRIP";

/// The channel strip is one plugin: its modules are one card, under the line of the plugin, with the layout that each has on
/// its own plate, and a vertical delimiter between them. The key that saves the mapping, and the one that stores the state of
/// the plugin, are at the right of the title of the card.
fn stripCard(
    ctx: imgui.ContextPtr,
    set: *const AssignSet,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    var rv: ?mapping_actions.MappingPanelAction = null;
    const owner = ownerOf(set, .INPUT);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (try fxHeader(ctx, .INPUT, set, translations)) |act| rv = act;

    var sections = try module_plate.beginSections(ctx, strip_card, tr(translations, .fx_ctrl_card_strip), c1_theme.fonts.TAB);
    defer module_plate.sections_open = false;

    var title_plate: Plate = undefined;
    title_plate.start = .{ .x = sections.x, .y = sections.y };
    const title_w = try titleWidth(ctx, tr(translations, .fx_ctrl_card_strip));
    if (try saveKey(ctx, title_plate, strip_id, title_w, owner != null, translations)) {
        rv = .{ .assign_request_save = .STRIP };
    }
    if (try storeKey(ctx, title_plate, strip_id, title_w, owner, translations)) {
        rv = .{ .assign_toggle_store_preset = .STRIP };
    }
    // The keys moved the cursor: the sections start where the card says.
    try imgui.SetCursorScreenPos(.{ ctx, sections.x + module_plate.pad, sections.y + module_plate.pad + sections.header_h });

    const defs = [_]ModuleDef{ input_def, shape_def, eq_def, comp_def, output_def };
    inline for (defs, 0..) |def, i| {
        const plate = try beginModulePlate(ctx, def, translations, true, 0);
        if (try moduleBody(ctx, def, plate, owner, true, translations)) |act| rv = act;
        try plate.end(ctx);
        try module_plate.afterSection(ctx, &sections, i + 1 == defs.len);
    }
    try module_plate.finishSections(ctx, sections, &strip_card);
    face_widths[@backingInt(ModulesList.INPUT)] = strip_card.w;
    return rv;
}

/// The width of a title, in the font that plates engrave it in.
fn titleWidth(ctx: imgui.ContextPtr, title: [:0]const u8) !f64 {
    try imgui.PushFont(.{ ctx, c1_theme.fonts.TAB });
    defer imgui.PopFont(.{ctx}) catch {};
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, title, &w, &h });
    return w;
}
