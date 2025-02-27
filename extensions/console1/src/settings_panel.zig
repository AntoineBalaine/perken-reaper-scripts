const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Preferences = @import("settings.zig");
const Globals = @import("globals.zig").Globals;
const ModulesList = @import("statemachine.zig").ModulesList;
const settings_actions = @import("settings_actions.zig");
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const MappingsList = @import("mappings_list.zig");

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

pub const SettingsValUpdate = struct { field: []const u8, val: bool };
const SettingsRV = union(enum) {
    close_save,
    close_cancel,
    val_update: SettingsValUpdate,
};
pub fn draw(self: *@This(), ctx: imgui.ContextPtr, mappings_list: *MappingsList, style_manager: *styles.StyleManager) !?SettingsRV {
    var rv: ?SettingsRV = null;
    const scroll_pos = self.scroll_position_rel;
    const PopStyle = try styles_components.PushStyle(ctx, .rack, style_manager);
    defer PopStyle(ctx) catch {};
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Edit settings...

        // UI Settings
        {
            const popColor = try pushColIfSelected(ctx, .show_startup_message, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            if (try imgui.Checkbox(.{ ctx, "Show Startup Message##strtp", &self.temp_settings.show_startup_message })) {
                rv = .{ .val_update = .{ .field = "show_startup_message", .val = self.temp_settings.show_startup_message } };
                self.dirty = true;
            }
        }
        {
            const popColor = try pushColIfSelected(ctx, .show_feedback_window, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            if (try imgui.Checkbox(.{ ctx, "Show Feedback Window##fdkw", &self.temp_settings.show_feedback_window })) {
                rv = .{ .val_update = .{ .field = "show_feedback_window", .val = self.temp_settings.show_feedback_window } };
                self.dirty = true;
            }
        }
        {
            const popColor = try pushColIfSelected(ctx, .show_plugin_ui, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            if (try imgui.Checkbox(.{ ctx, "Show Plugin UI##plgui", &self.temp_settings.show_plugin_ui })) {
                rv = .{ .val_update = .{ .field = "show_plugin_ui", .val = self.temp_settings.show_plugin_ui } };
                self.dirty = true;
            }
        }

        // Routing Settings
        {
            const popColor = try pushColIfSelected(ctx, .manual_routing, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            if (try imgui.Checkbox(.{ ctx, "Manual Routing ##mnlrtng", &self.temp_settings.manual_routing })) {
                rv = .{ .val_update = .{ .field = "manual_routing", .val = self.temp_settings.manual_routing } };
                self.dirty = true;
            }
        }

        // Logging Settings
        {
            const popColor = try pushColIfSelected(ctx, .log_to_file, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            if (try imgui.Checkbox(.{ ctx, "Log to File##lgfd", &self.temp_settings.log_to_file })) {
                rv = .{ .val_update = .{ .field = "log_to_file", .val = self.temp_settings.log_to_file } };
                self.dirty = true;
            }
        }

        {
            const popColor = try pushColIfSelected(ctx, .start_suspended, scroll_pos);
            defer if (popColor) |pop| pop(ctx) catch {};
            if (try imgui.Checkbox(.{ ctx, "Start extension suspended##strt_sspndchkbx", &self.temp_settings.start_suspended })) {
                rv = .{ .val_update = .{ .field = "start_suspended", .val = self.temp_settings.start_suspended } };
                self.dirty = true;
            }
        }

        if (try imgui.Button(.{ ctx, "Save##stngs_sv" })) {
            if (self.dirty) {
                return .close_save;
            }
        }
        try imgui.SameLine(.{ctx});
        if (try imgui.Button(.{ ctx, "Cancel##stngs_x" })) {
            return .close_cancel;
        }
    }

    {
        try imgui.SameLine(.{ctx});
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Default Channel Strip Settings
        try imgui.Text(.{ ctx, "Default Channel Strip" });
        try imgui.Spacing(.{ctx});

        // For each module, show a combo with available mappings
        inline for (comptime std.enums.values(ModulesList)) |module| {
            const module_name = @tagName(module);
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
                }, scroll_pos);
                defer if (popColor) |pop| pop(ctx) catch {};
                // Begin combo for this module
                if (try imgui.BeginCombo(.{
                    ctx,
                    module_name,
                    current_fx orelse "none",
                    null,
                })) {
                    defer imgui.EndCombo(.{ctx}) catch {};

                    {
                        var is_selected = current_fx == null;
                        if (try imgui.Selectable(.{ ctx, "none", &is_selected })) {
                            self.dirty = true;
                            // Update temp settings with new selection
                            self.temp_settings.default_fx.set(module, null);
                            self.dirty = true;
                        }
                    } // Get available mappings for this module
                    const mappings = mappings_list.list.get(module);

                    // Show each available mapping as a selectable
                    var it = mappings.iterator();
                    while (it.next()) |entry| {
                        const fx_name = entry.key_ptr.*;
                        var is_selected = false;
                        if (current_fx) |cur_fx| {
                            is_selected = std.mem.eql(u8, fx_name, cur_fx);
                        }

                        if (try imgui.Selectable(.{ ctx, @as([:0]const u8, @ptrCast(fx_name)), &is_selected })) {
                            self.dirty = true;
                            // Update temp settings with new selection
                            self.temp_settings.default_fx.set(module, @ptrCast(fx_name));
                            self.dirty = true;
                        }
                    }
                }
            }
        }
    }
    return rv;
}

/// Copy temp_settings to `globals.preferences`.
///
/// If the copy fails, just return without committing the changes.
pub fn save(self: *@This(), globals: *Globals) !void {
    // Just copy the values, including string slices
    globals.preferences = self.temp_settings;
    try globals.preferences.saveToDisk(globals.resource_path);

    if (self.temp_settings.log_to_file != globals.preferences.log_to_file) {
        try globals.updateLoggerState();
    }

    // Apply changes that need immediate effect
    if (self.temp_settings.log_to_file != globals.preferences.log_to_file) {
        try globals.updateLoggerState();
    }
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
