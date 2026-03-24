const std = @import("std");
const imgui = @import("reaper_imgui");
const Preferences = @import("settings.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const FxMaps = @import("mappings_list.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const safePrint = @import("debug_panel.zig").safePrint;

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
};

pub fn draw(
    self: *@This(),
    ctx: imgui.ContextPtr,
    mappings_list: *FxMaps,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?SettingsRV {
    var rv: ?SettingsRV = null;
    const scroll_pos = self.scroll_position_rel;
    const PopStyle = try styles_components.PushStyle(ctx, .rack, style_manager);
    defer PopStyle(ctx) catch {};
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Language Selection at the top
        {
            const popColor = try pushColIfSelected(ctx, .language, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};

            try imgui.PushItemWidth(.{ ctx, 300.0 });
            defer imgui.PopItemWidth(.{ctx}) catch {};

            const current_lang = self.temp_settings.language;
            const current_display = for (translations.getLanguages()) |lang| {
                if (std.mem.eql(u8, lang.code, current_lang)) {
                    break lang.display_name;
                }
            } else current_lang;

            var buf: [256:0]u8 = undefined;
            const label = safePrint(&buf, "{s}##lang", .{tr(translations, .settings_language)});
            if (try imgui.BeginCombo(.{ ctx, label, current_display, null })) {
                defer imgui.EndCombo(.{ctx}) catch {};

                for (translations.getLanguages()) |lang| {
                    var is_selected = std.mem.eql(u8, lang.code, current_lang);
                    if (try imgui.Selectable(.{ ctx, lang.display_name, &is_selected })) {
                        rv = .{ .val_update = .{ .string_val = .{ .field = .language, .val = lang.code } } };
                        self.dirty = true;
                    }
                }
            }

            if (!std.mem.eql(u8, self.temp_settings.language, translations.current_language)) {
                try imgui.Text(.{ ctx, tr(translations, .settings_language_restart) });
            }
        }

        try imgui.Separator(.{ctx});

        var buf: [256:0]u8 = undefined;

        // UI Settings
        {
            const popColor = try pushColIfSelected(ctx, .show_startup_message, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##strtp", .{tr(translations, .settings_show_startup_message)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.show_startup_message })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .show_startup_message, .val = self.temp_settings.show_startup_message } } };
                self.dirty = true;
            }
        }
        {
            const popColor = try pushColIfSelected(ctx, .show_feedback_window, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##fdkw", .{tr(translations, .settings_show_feedback_window)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.show_feedback_window })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .show_feedback_window, .val = self.temp_settings.show_feedback_window } } };
                self.dirty = true;
            }
        }
        {
            const popColor = try pushColIfSelected(ctx, .show_plugin_ui, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##plgui", .{tr(translations, .settings_show_plugin_ui)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.show_plugin_ui })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .show_plugin_ui, .val = self.temp_settings.show_plugin_ui } } };
                self.dirty = true;
            }
        }

        // Routing Settings
        {
            const popColor = try pushColIfSelected(ctx, .manual_routing, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##mnlrtng", .{tr(translations, .settings_manual_routing)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.manual_routing })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .manual_routing, .val = self.temp_settings.manual_routing } } };
                self.dirty = true;
            }
        }

        // Logging Settings
        {
            const popColor = try pushColIfSelected(ctx, .log_to_file, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##lgfd", .{tr(translations, .settings_log_to_file)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.log_to_file })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .log_to_file, .val = self.temp_settings.log_to_file } } };
                self.dirty = true;
            }
        }

        {
            const popColor = try pushColIfSelected(ctx, .start_suspended, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##strt_sspndchkbx", .{tr(translations, .settings_start_suspended)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.start_suspended })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .start_suspended, .val = self.temp_settings.start_suspended } } };
                self.dirty = true;
            }
        }

        try imgui.Separator(.{ctx});

        // Track List View Sync
        {
            const popColor = try pushColIfSelected(ctx, .focus_page_tracks, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##focuspg", .{tr(translations, .settings_focus_page_tracks)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.focus_page_tracks })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .focus_page_tracks, .val = self.temp_settings.focus_page_tracks } } };
                self.dirty = true;
            }
        }

        try imgui.Separator(.{ctx});

        // Track Validation Settings
        {
            const popColor = try pushColIfSelected(ctx, .auto_insert_modules, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##autoins", .{tr(translations, .settings_auto_insert_modules)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.auto_insert_modules })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .auto_insert_modules, .val = self.temp_settings.auto_insert_modules } } };
                self.dirty = true;
            }
        }

        // Indented sub-option: Insert as bypassed
        {
            try imgui.Indent(.{ctx});
            defer imgui.Unindent(.{ctx}) catch {};

            if (!self.temp_settings.auto_insert_modules) {
                try imgui.BeginDisabled(.{ctx});
            }
            defer if (!self.temp_settings.auto_insert_modules) {
                imgui.EndDisabled(.{ctx}) catch {};
            };

            const popColor = try pushColIfSelected(ctx, .auto_insert_bypassed, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "{s}##autobps", .{tr(translations, .settings_auto_insert_bypassed)});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.auto_insert_bypassed })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .auto_insert_bypassed, .val = self.temp_settings.auto_insert_bypassed } } };
                self.dirty = true;
            }
        }

        {
            const popColor = try pushColIfSelected(ctx, .auto_reorder_modules, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            const label = safePrint(&buf, "Auto-reorder modules to canonical order##autoreord", .{});
            if (try imgui.Checkbox(.{ ctx, label, &self.temp_settings.auto_reorder_modules })) {
                rv = .{ .val_update = .{ .bool_val = .{ .field = .auto_reorder_modules, .val = self.temp_settings.auto_reorder_modules } } };
                self.dirty = true;
            }
        }

        // Indented sub-option: Preferred module order
        {
            try imgui.Indent(.{ctx});
            defer imgui.Unindent(.{ctx}) catch {};

            if (!self.temp_settings.auto_reorder_modules) {
                try imgui.BeginDisabled(.{ctx});
            }
            defer if (!self.temp_settings.auto_reorder_modules) {
                imgui.EndDisabled(.{ctx}) catch {};
            };

            const popColor = try pushColIfSelected(ctx, .preferred_module_order, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};

            try imgui.PushItemWidth(.{ ctx, 150.0 });
            defer imgui.PopItemWidth(.{ctx}) catch {};

            const current_order = self.temp_settings.preferred_module_order;
            const current_display = @tagName(current_order);
            const label = safePrint(&buf, "Preferred module order##preforder", .{});
            if (try imgui.BeginCombo(.{ ctx, label, current_display, null })) {
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
        }

        if (try imgui.Button(.{ ctx, safePrint(&buf, "{s}##stngs_sv", .{tr(translations, .settings_save)}) })) {
            return .close_save;
        }
        try imgui.SameLine(.{ctx});
        if (try imgui.Button(.{ ctx, safePrint(&buf, "{s}##stngs_x", .{tr(translations, .settings_cancel)}) })) {
            return .close_cancel;
        }
    }

    {
        try imgui.SameLine(.{ctx});
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Default Channel Strip Settings
        try imgui.Text(.{ ctx, tr(translations, .settings_default_channel_strip) });
        try imgui.Spacing(.{ctx});

        // For each module, show a combo with available mappings
        inline for (comptime std.enums.values(ModulesList)) |module| {
            const current_fx: ?[:0]const u8 = self.temp_settings.default_fx.get(module);

            try imgui.PushItemWidth(.{ ctx, 300.0 });
            defer imgui.PopItemWidth(.{ctx}) catch {};

            {
                const popColor = try pushColIfSelected(ctx, switch (module) {
                    .INPUT => .default_INPUT,
                    .GATE => .default_GATE,
                    .EQ => .default_EQ,
                    .COMP => .default_COMP,
                    .OUTPT => .default_OUTPT,
                    .STRIP => .default_OUTPT,
                }, scroll_pos);
                defer if (popColor) |pop| pop(ctx) catch {};
                // Begin combo for this module
                const module_label = switch (module) {
                    .INPUT => tr(translations, .settings_input),
                    .GATE => tr(translations, .settings_gate),
                    .EQ => tr(translations, .settings_eq),
                    .COMP => tr(translations, .settings_comp),
                    .OUTPT => tr(translations, .settings_output),
                    .STRIP => tr(translations, .settings_default_channel_strip),
                };

                if (try imgui.BeginCombo(.{
                    ctx,
                    module_label,
                    current_fx orelse tr(translations, .settings_none),
                    null,
                })) {
                    defer imgui.EndCombo(.{ctx}) catch {};

                    {
                        var is_selected = current_fx == null;
                        if (try imgui.Selectable(.{ ctx, tr(translations, .settings_none), &is_selected })) {
                            self.dirty = true;
                            // Update temp settings with new selection
                            self.temp_settings.default_fx.set(module, null);
                            self.dirty = true;
                        }
                    } // Get available mappings for this module
                    const mappings = mappings_list.list.get(module);

                    // Show each available FX as a selectable
                    var it = mappings.iterator();
                    while (it.next()) |entry| {
                        const fx_offset = entry.key_ptr.*; // u32 offset into StringPool
                        const fx_name = mappings_list.strings.get(fx_offset);
                        var is_selected = false;
                        if (current_fx) |cur_fx| {
                            is_selected = std.mem.eql(u8, fx_name, cur_fx);
                        }

                        if (try imgui.Selectable(.{ ctx, @as([*:0]const u8, @ptrCast(fx_name)), &is_selected })) {
                            self.dirty = true;
                            // Update temp settings with new selection
                            self.temp_settings.default_fx.set(module, fx_name);
                            self.dirty = true;
                        }
                    }
                }
            }
        }

        // Channel strip mode settings
        try imgui.Spacing(.{ctx});
        try imgui.Separator(.{ctx});
        try imgui.Spacing(.{ctx});
        try imgui.Text(.{ ctx, "Channel Strip Mode" });
    }
    return rv;
}

test {
    std.testing.refAllDecls(@This());
}

fn pushColIfSelected(ctx: imgui.ContextPtr, variant: Preferences.SettingsFields, scroll_pos: u8) !?*const fn (ctx: imgui.ContextPtr) anyerror!void {
    if (@intFromEnum(variant) == scroll_pos) {
        const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
        return struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopStyleColor(.{cntx});
            }
        }.pop;
    } else return null;
}
