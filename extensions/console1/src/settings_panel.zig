const std = @import("std");
const imgui = @import("reaper_imgui");
const config = @import("config");
const Preferences = @import("settings.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const FxMaps = @import("mappings_list.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const safePrint = @import("utils").safePrint;
const Knobs = @import("knob");
const widgets = @import("components/widgets.zig");
const button = @import("components/button.zig");
const module_plate = @import("components/module_plate.zig");
const c1_theme = @import("theme/c1_theme.zig");
const StepField = @import("action_types.zig").StepField;
const Plate = module_plate.Plate;
const panel_theme = @import("panel_theme");
const palette = @import("ui_palette");

// Temporary copy for editing
temp_settings: Preferences,
dirty: bool = false, // Track if changes were made
scroll_position_rel: u8 = 0,
scroll_position_abs: u8 = 0,

const SettingsPanel = @This();
pub fn init(current: *const Preferences) !SettingsPanel {
    return .{
        .temp_settings = current.*,
    };
}

pub const SettingsValUpdate = @import("action_types.zig").SettingsValUpdate;
const SettingsRV = union(enum) {
    close_save,
    close_cancel,
    val_update: SettingsValUpdate,
    install_presets,
};

/// The height that the content of each of the four plates took on the frame before. Because a plate is drawn before its
/// content, and its height is that of the content, the plates take the height that the tallest content had on the last frame.
var measured_height: [plate_count]f64 = @splat(0);
const plate_count = 4;

const button_radius = button.default_radius;
/// The width of the combos of the plates.
const combo_width = 230.0;
/// The modules in the order of the columns of the default plugins, and how many of them stand in a column.
const default_fx_order = [_]ModulesList{ .INPUT, .GATE, .EQ, .COMP, .OUTPT, .STRIP };
const default_fx_rows = 3;
/// The space between the two columns of the default plugins.
const default_fx_column_gap = 16.0;
/// The label of the setting that has no entry in the language packs.
const auto_reorder_label: [:0]const u8 = "Auto-reorder modules to canonical order";
const preferred_order_label: [:0]const u8 = "Preferred module order";

/// The width that a toggle takes: its round button, and its label at the right.
fn toggleWidth(ctx: imgui.ContextPtr, label: [:0]const u8) !f64 {
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, label, &w, &h });
    return button_radius * 2 + 4 + w;
}

/// The widest of the toggles that a plate has, or `at_least` when they are narrower.
fn widestToggle(ctx: imgui.ContextPtr, labels: []const [:0]const u8, at_least: f64) !f64 {
    var widest = at_least;
    for (labels) |label| widest = @max(widest, try toggleWidth(ctx, label));
    return widest;
}

/// The height of a plate's content that is not known yet, on the first frame: the rows that it has.
fn estimateHeight(ctx: imgui.ContextPtr, toggles: usize, combos: usize) !f64 {
    var spacing_x: f64 = undefined;
    var spacing_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y });
    const line = try imgui.GetTextLineHeight(.{ctx});
    const frame = try imgui.GetFrameHeight(.{ctx});
    return @as(f64, @floatFromInt(toggles)) * (button_radius * 2 + spacing_y) + @as(f64, @floatFromInt(combos)) * (line + frame + spacing_y * 2);
}

/// Starts a plate at the cursor, and puts the cursor at the top left of its content.
fn beginPlate(ctx: imgui.ContextPtr, title: [:0]const u8, width: f64, estimate: f64) !Plate {
    const plate = try Plate.begin(ctx, .{
        .slots = &.{},
        .columns = 1,
        .widest_label = "Ag",
        .title = title,
        .title_font = c1_theme.fonts.TAB,
        .min_width = width,
        // Because the four plates are as tall as the tallest, each one is given the tallest content of the last frame.
        .min_content_h = @max(std.mem.max(f64, &measured_height), estimate),
        .independent = true,
    });
    try imgui.SetCursorScreenPos(.{ ctx, plate.origin.x, plate.origin.y });
    return plate;
}

/// Puts the cursor back at the left edge of the plate's content, at the height where it is. Because ImGui moves the cursor
/// back to the left edge of the window after each widget, every row of a plate must start with this.
fn lineUp(ctx: imgui.ContextPtr, plate: Plate) !void {
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &x, &y });
    try imgui.SetCursorScreenPos(.{ ctx, plate.origin.x, y });
}

/// Writes the label of a combo at the left of the plate, and leaves the cursor just under it, where the combo goes. The gap
/// between the two is small and fixed, whatever the spacing of the window is.
fn labelAbove(ctx: imgui.ContextPtr, x: f64, label: [:0]const u8) !void {
    var unused_x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &unused_x, &y });
    try imgui.SetCursorScreenPos(.{ ctx, x, y });
    try imgui.Text(.{ ctx, label });
    try imgui.SetCursorScreenPos(.{ ctx, x, y + try imgui.GetTextLineHeight(.{ctx}) + 2 });
}

/// The colors of a combo and of its list, as the combos of the MFT panel have them: a dark recessed frame, a light outline,
/// and the amber of the panel for what is hovered and chosen.
const combo_colors = [_]palette.ColorPair{
    .{ .col = &imgui.Col_FrameBg, .val = panel_theme.frame_bg },
    .{ .col = &imgui.Col_FrameBgHovered, .val = panel_theme.amber_faint },
    .{ .col = &imgui.Col_FrameBgActive, .val = panel_theme.amber_soft },
    .{ .col = &imgui.Col_Border, .val = panel_theme.frame_border },
    .{ .col = &imgui.Col_Button, .val = palette.rgba(0x3A3A3EFF) },
    .{ .col = &imgui.Col_ButtonHovered, .val = panel_theme.amber_soft },
    .{ .col = &imgui.Col_ButtonActive, .val = panel_theme.amber },
    .{ .col = &imgui.Col_Header, .val = palette.rgba(0x3A3A3EFF) },
    .{ .col = &imgui.Col_HeaderHovered, .val = panel_theme.amber_faint },
    .{ .col = &imgui.Col_HeaderActive, .val = panel_theme.amber_soft },
    .{ .col = &imgui.Col_PopupBg, .val = panel_theme.panel_bg },
    .{ .col = &imgui.Col_Text, .val = panel_theme.text },
};
const combo_var_count: c_int = 3;

/// Pushes the style of the combos of the MFT panel. `popComboStyle` takes it off once the list is closed.
fn pushComboStyle(ctx: imgui.ContextPtr) void {
    palette.push(ctx, &combo_colors);
    panel_theme.pushVar(ctx, imgui.StyleVar_FrameRounding, 3);
    panel_theme.pushVar(ctx, imgui.StyleVar_FrameBorderSize, 1);
    panel_theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 8, 4);
}

fn popComboStyle(ctx: imgui.ContextPtr) void {
    var vars = combo_var_count;
    imgui.api.PopStyleVar(ctx, &vars);
    palette.pop(ctx, combo_colors.len);
}

/// Ends a plate, and remembers how tall its content was, for the next frame.
fn endPlate(ctx: imgui.ContextPtr, index: usize, plate: Plate) !void {
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &x, &y });
    var spacing_x: f64 = undefined;
    var spacing_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y });
    measured_height[index] = @max(y - plate.origin.y - spacing_y, 0);
    try plate.end(ctx);
}

/// The space between two plates, as the modules of the main panel have it.
fn betweenPlates(ctx: imgui.ContextPtr) !void {
    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + styles.section_spacing });
}

/// A setting that is on or off: a round key, lit when the setting is on, with its label at the right. It returns whether
/// the key was pressed.
fn toggle(ctx: imgui.ContextPtr, label: [:0]const u8, id: [:0]const u8, value: bool, disabled: bool) !bool {
    var id_buf: [128:0]u8 = undefined;
    const full_id = safePrint(&id_buf, "##{s}", .{id});
    return widgets.roundButton(.{ ctx, label, full_id, null, null, .right, disabled, if (value and !disabled) Knobs.led_orange else null });
}

/// The toggle of a boolean setting. A press flips the setting in the copy that is edited, and reports the change.
fn boolSetting(
    self: *SettingsPanel,
    ctx: imgui.ContextPtr,
    label: [:0]const u8,
    id: [:0]const u8,
    comptime field: Preferences.SettingsFields,
    disabled: bool,
    rv: *?SettingsRV,
) !void {
    const value = &@field(self.temp_settings, @tagName(field));
    if (try toggle(ctx, label, id, value.*, disabled)) {
        value.* = !value.*;
        rv.* = .{ .val_update = .{ .bool_val = .{ .field = field, .val = value.* } } };
        self.dirty = true;
    }
}

/// A knob for a setting that goes from `min` to `max`, where each turn of the range multiplies the value by the same
/// factor, as the steps of a knob are felt. The right of the knob's range is the one of the knob of the panel.
fn knobSetting(
    self: *SettingsPanel,
    ctx: imgui.ContextPtr,
    comptime field: StepField,
    label: [:0]const u8,
    min: f64,
    max: f64,
    rv: *?SettingsRV,
) !void {
    std.debug.assert(min > 0 and max > min);
    const current: f64 = @field(self.temp_settings, @tagName(field));
    std.debug.assert(current > 0);
    const span = @log(max / min);
    var position = std.math.clamp(@log(current / min) / span, 0.0, 1.0);
    const before = position;
    var text_buf: [32:0]u8 = undefined;
    const label_width = try toggleWidth(ctx, label) - button_radius * 2 - 4;
    const label_id = Knobs.LabelId{
        .label = label,
        .id = @tagName(field),
        .value_text = safePrint(&text_buf, "{d:.2}", .{current}),
    };
    _ = try Knobs.drawWidget(ctx, &position, label_id, .{}, @max(Knobs.knob_size, label_width), null);
    if (position != before) {
        const value = min * std.math.exp(position * span);
        @field(self.temp_settings, @tagName(field)) = value;
        rv.* = .{ .val_update = .{ .float_val = .{ .field = field, .val = value } } };
        self.dirty = true;
    }
}

pub fn draw(
    self: *@This(),
    ctx: imgui.ContextPtr,
    mappings_list: *FxMaps,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?SettingsRV {
    var rv: ?SettingsRV = null;
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    const language_label = tr(translations, .settings_language);
    const save_label = tr(translations, .settings_save);
    const cancel_label = tr(translations, .settings_cancel);
    const install_label = tr(translations, .install_presets_button);

    // Where the page starts, and where the first column ends, which is under the buttons of the page: the credits go under it.
    var page_left: f64 = undefined;
    var page_top: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &page_left, &page_top });
    var first_column_bottom: f64 = page_top;

    // The general settings: the language, and what shows and what is logged.
    {
        const labels = [_][:0]const u8{
            tr(translations, .settings_show_startup_message),
            tr(translations, .settings_show_feedback_window),
            tr(translations, .settings_show_plugin_ui),
            tr(translations, .settings_log_to_file),
            tr(translations, .settings_start_suspended),
        };
        try imgui.BeginGroup(.{ctx});
        const plate = try beginPlate(ctx, "GENERAL", try widestToggle(ctx, &labels, combo_width), try estimateHeight(ctx, labels.len, 1) + 24);

        try labelAbove(ctx, plate.origin.x, language_label);
        try imgui.PushItemWidth(.{ ctx, combo_width });
        const current_lang = self.temp_settings.language;
        const current_display = for (translations.getLanguages()) |lang| {
            if (std.mem.eql(u8, lang.code, current_lang)) break lang.display_name;
        } else current_lang;
        pushComboStyle(ctx);
        if (try imgui.BeginCombo(.{ ctx, "##lang", current_display, null })) {
            defer imgui.EndCombo(.{ctx}) catch {};
            for (translations.getLanguages()) |lang| {
                var is_selected = std.mem.eql(u8, lang.code, current_lang);
                if (try imgui.Selectable(.{ ctx, lang.display_name, &is_selected })) {
                    rv = .{ .val_update = .{ .string_val = .{ .field = .language, .val = lang.code } } };
                    self.dirty = true;
                }
            }
        }
        popComboStyle(ctx);
        try imgui.PopItemWidth(.{ctx});
        if (!std.mem.eql(u8, self.temp_settings.language, translations.current_language)) {
            try lineUp(ctx, plate);
            try imgui.Text(.{ ctx, tr(translations, .settings_language_restart) });
        }
        try imgui.Spacing(.{ctx});

        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[0], "strtp", .show_startup_message, false, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[1], "fdkw", .show_feedback_window, false, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[2], "plgui", .show_plugin_ui, false, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[3], "lgfd", .log_to_file, false, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[4], "strt_sspndchkbx", .start_suspended, false, &rv);
        try endPlate(ctx, 0, plate);

        // The buttons that close the page are under the plate, in a row.
        var id_buf: [128:0]u8 = undefined;
        if (try widgets.roundButton(.{ ctx, save_label, safePrint(&id_buf, "{s}##stngs_sv", .{save_label}), null, null, .right })) rv = .close_save;
        try imgui.SameLine(.{ctx});
        if (try widgets.roundButton(.{ ctx, cancel_label, safePrint(&id_buf, "{s}##stngs_x", .{cancel_label}), null, null, .right })) rv = .close_cancel;
        try imgui.SameLine(.{ctx});
        if (try widgets.roundButton(.{ ctx, install_label, safePrint(&id_buf, "{s}##stngs_ip", .{install_label}), null, null, .right })) rv = .install_presets;
        try imgui.EndGroup(.{ctx});
        var group_right: f64 = undefined;
        try imgui.GetItemRectMax(.{ ctx, &group_right, &first_column_bottom });
    }

    // The settings of the tracks: how they are routed, validated and ordered.
    try betweenPlates(ctx);
    {
        const labels = [_][:0]const u8{
            tr(translations, .settings_manual_routing),
            tr(translations, .settings_focus_page_tracks),
            tr(translations, .settings_auto_insert_modules),
            tr(translations, .settings_auto_insert_bypassed),
            auto_reorder_label,
        };
        const plate = try beginPlate(ctx, "TRACKS", try widestToggle(ctx, &labels, combo_width), try estimateHeight(ctx, labels.len, 1));

        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[0], "mnlrtng", .manual_routing, false, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[1], "focuspg", .focus_page_tracks, false, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[2], "autoins", .auto_insert_modules, false, &rv);
        // Because the modules are only inserted when the first one is on, the bypass option is off without it.
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[3], "autobps", .auto_insert_bypassed, !self.temp_settings.auto_insert_modules, &rv);
        try lineUp(ctx, plate);
        try boolSetting(self, ctx, labels[4], "autoreord", .auto_reorder_modules, false, &rv);

        try imgui.Spacing(.{ctx});
        try labelAbove(ctx, plate.origin.x, preferred_order_label);
        const reorder_off = !self.temp_settings.auto_reorder_modules;
        if (reorder_off) try imgui.BeginDisabled(.{ctx});
        try imgui.PushItemWidth(.{ ctx, combo_width });
        const current_order = self.temp_settings.preferred_module_order;
        pushComboStyle(ctx);
        if (try imgui.BeginCombo(.{ ctx, "##preforder", @tagName(current_order), null })) {
            defer imgui.EndCombo(.{ctx}) catch {};
            inline for (comptime std.enums.values(ModulesOrder)) |order| {
                var is_selected = current_order == order;
                if (try imgui.Selectable(.{ ctx, @tagName(order), &is_selected })) {
                    rv = .{ .val_update = .{ .enum_val = .{ .field = .preferred_module_order, .val = order } } };
                    self.temp_settings.preferred_module_order = order;
                    self.dirty = true;
                }
            }
        }
        popComboStyle(ctx);
        try imgui.PopItemWidth(.{ctx});
        if (reorder_off) try imgui.EndDisabled(.{ctx});
        try endPlate(ctx, 1, plate);
    }

    // The step of a tick of a knob of the sysex unit.
    try betweenPlates(ctx);
    {
        const sensitivity_label = tr(translations, .settings_knob_sensitivity);
        const fine_label = tr(translations, .settings_knob_fine);
        const knobs_width = (try toggleWidth(ctx, sensitivity_label) - button_radius * 2 - 4) + (try toggleWidth(ctx, fine_label) - button_radius * 2 - 4) + 16;
        const plate = try beginPlate(ctx, "KNOBS", knobs_width, Knobs.knob_size * 1.5);

        try lineUp(ctx, plate);
        try knobSetting(self, ctx, .sensitivity, sensitivity_label, 0.1, 10.0, &rv);
        try imgui.SameLine(.{ctx});
        try knobSetting(self, ctx, .fine_multiplier, fine_label, 0.01, 1.0, &rv);
        try endPlate(ctx, 2, plate);
    }

    // The plugins that a new track gets for each module.
    try betweenPlates(ctx);
    {
        const plate = try beginPlate(ctx, "DEFAULT FX", combo_width * 2 + default_fx_column_gap, try estimateHeight(ctx, 0, default_fx_rows));
        // The modules go down a column, and the next column takes over after `default_fx_rows` of them.
        inline for (default_fx_order, 0..) |module, index| {
            const column_x = plate.origin.x + @as(f64, @floatFromInt(index / default_fx_rows)) * (combo_width + default_fx_column_gap);
            if (index % default_fx_rows == 0) try imgui.SetCursorScreenPos(.{ ctx, column_x, plate.origin.y });
            const current_fx: ?[:0]const u8 = self.temp_settings.default_fx.get(module);
            const module_label = switch (module) {
                .INPUT => tr(translations, .settings_input),
                .GATE => tr(translations, .settings_gate),
                .EQ => tr(translations, .settings_eq),
                .COMP => tr(translations, .settings_comp),
                .OUTPT => tr(translations, .settings_output),
                .STRIP => tr(translations, .settings_default_channel_strip),
            };
            try labelAbove(ctx, column_x, module_label);
            try imgui.PushItemWidth(.{ ctx, combo_width });
            defer imgui.PopItemWidth(.{ctx}) catch {};
            var combo_id_buf: [64:0]u8 = undefined;
            const combo_id = safePrint(&combo_id_buf, "##dfx_{s}", .{@tagName(module)});
            pushComboStyle(ctx);
            defer popComboStyle(ctx);
            if (try imgui.BeginCombo(.{ ctx, combo_id, current_fx orelse tr(translations, .settings_none), null })) {
                defer imgui.EndCombo(.{ctx}) catch {};
                {
                    var is_selected = current_fx == null;
                    if (try imgui.Selectable(.{ ctx, tr(translations, .settings_none), &is_selected })) {
                        self.temp_settings.default_fx.set(module, null);
                        self.dirty = true;
                    }
                }
                // Each plugin that has a mapping for the module is a choice.
                const mappings = mappings_list.list.get(module);
                var it = mappings.iterator();
                while (it.next()) |entry| {
                    const fx_name = mappings_list.strings.get(entry.key_ptr.*);
                    var is_selected = if (current_fx) |cur_fx| std.mem.eql(u8, fx_name, cur_fx) else false;
                    if (try imgui.Selectable(.{ ctx, @as([*:0]const u8, @ptrCast(fx_name)), &is_selected })) {
                        self.temp_settings.default_fx.set(module, fx_name);
                        self.dirty = true;
                    }
                }
            }
        }
        try endPlate(ctx, 3, plate);
    }

    // Because the plates were laid out side by side, the cursor is at the bottom of the last one, which is shorter than the
    // first column with its buttons. The credits go under that column.
    try imgui.SetCursorScreenPos(.{ ctx, page_left, first_column_bottom + 8 });
    {
        var buf: [256:0]u8 = undefined;
        const version_label = safePrint(&buf, "Console1 v{s} - by Perken", .{config.version});
        try imgui.Text(.{ ctx, version_label });
    }

    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
