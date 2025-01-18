const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Preferences = @import("settings.zig");
const globals = @import("globals.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const styles = @import("styles.zig");

// Temporary copy for editing
temp_settings: Preferences,
dirty: bool = false, // Track if changes were made

const SettingsPanel = @This();
pub fn init(current: *const Preferences, gpa: std.mem.Allocator) !SettingsPanel {
    return .{
        .temp_settings = try current.clone(gpa),
    };
}

pub fn deinit(self: *SettingsPanel) void {
    self.temp_settings.deinit();
}

pub fn draw(self: *@This(), ctx: imgui.ContextPtr) !enum { stay_open, close_save, close_cancel } {
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        // Edit settings...

        // UI Settings
        try imgui.TextWrapped(.{ ctx, "UI Settings" });
        if (try imgui.Checkbox(.{ ctx, "Show Startup Message##strtp", &self.temp_settings.show_startup_message })) {
            self.dirty = true;
        }
        if (try imgui.Checkbox(.{ ctx, "Show Feedback Window##fdkw", &self.temp_settings.show_feedback_window })) {
            self.dirty = true;
        }
        if (try imgui.Checkbox(.{ ctx, "Show Plugin UI##plgui", &self.temp_settings.show_plugin_ui })) {
            self.dirty = true;
        }
        try imgui.Spacing(.{ctx});

        // Routing Settings
        try imgui.TextWrapped(.{ ctx, "Routing Settings ##rtstngs" });
        if (try imgui.Checkbox(.{ ctx, "Manual Routing ##mnlrtng", &self.temp_settings.manual_routing })) {
            self.dirty = true;
        }
        try imgui.Spacing(.{ctx});

        // Logging Settings
        try imgui.TextWrapped(.{ ctx, "Logging Settings##lgstng" });
        if (try imgui.Checkbox(.{ ctx, "Log to File##lgfd", &self.temp_settings.log_to_file })) {
            self.dirty = true;
        }

        try imgui.Spacing(.{ctx});

        // Logging Settings
        try imgui.TextWrapped(.{ ctx, "Start extension suspended##strt_sspnd" });
        if (try imgui.Checkbox(.{ ctx, "Start extension suspended##strt_sspndchkbx", &self.temp_settings.start_suspended })) {
            self.dirty = true;
        }

        try imgui.TextWrapped(.{ ctx, "Log Level" });
        const log_levels = [_][:0]const u8{ "Debug", "Info", "Warning", "Error" };
        var current_level = @intFromEnum(self.temp_settings.log_level);

        // Begin combo
        {
            try imgui.PushItemWidth(.{ ctx, 100.0 });
            defer imgui.PopItemWidth(.{ctx}) catch {};
            if (try imgui.BeginCombo(.{
                ctx,
                "Log Level##log_level",
                log_levels[@intCast(current_level)],
                null,
            })) {
                defer imgui.EndCombo(.{ctx}) catch {};

                // Draw selectable item for each level
                for (log_levels, 0..) |level_name, i| {
                    var is_selected = (i == current_level);
                    if (try imgui.Selectable(.{
                        ctx,
                        level_name,
                        &is_selected,
                        null,
                        null,
                    })) {
                        current_level = @intCast(i);
                        self.temp_settings.log_level = @enumFromInt(current_level);
                        self.dirty = true;
                    }
                }
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
            const current_fx = self.temp_settings.default_fx.get(module);

            try imgui.PushItemWidth(.{ ctx, 300.0 });
            defer imgui.PopItemWidth(.{ctx}) catch {};

            // Begin combo for this module
            if (try imgui.BeginCombo(.{
                ctx,
                module_name,
                current_fx,
                null,
            })) {
                defer imgui.EndCombo(.{ctx}) catch {};

                // Get available mappings for this module
                const mappings: std.StringHashMap(void) = globals.mappings_list.list.get(module);

                // Show each available mapping as a selectable
                var it = mappings.keyIterator();
                while (it.next()) |fx_name| {
                    var is_selected = std.mem.eql(u8, fx_name.*, current_fx);
                    if (try imgui.Selectable(.{
                        ctx,
                        @as([:0]const u8, @ptrCast(fx_name.*)),
                        &is_selected,
                        null,
                        null,
                    })) {
                        self.dirty = true;
                        // Update temp settings with new selection
                        const new_fx = try self.temp_settings.allocator.dupeZ(u8, fx_name.*);
                        self.temp_settings.allocator.free(self.temp_settings.default_fx.get(module));
                        self.temp_settings.default_fx.set(module, new_fx);
                        self.dirty = true;
                    }
                }
            }
        }
    }
    return .stay_open;
}

/// Copy temp_settings to `globals.preferences`.
///
/// If the copy fails, just return without committing the changes.
pub fn save(self: *@This()) !void {
    // Copy temp settings back to global settings
    var copy: Preferences = .{
        .default_fx = undefined,
        .allocator = undefined,
        .resource_path = undefined,
    };
    try copy.copyFrom(&copy, globals.allocator);
    globals.preferences.deinit();
    globals.preferences = copy;
    try globals.preferences.saveToDisk();

    // Apply changes that need immediate effect
    if (self.temp_settings.log_to_file != globals.preferences.log_to_file) {
        try globals.updateLoggerState();
    }
}

test {
    std.testing.refAllDecls(@This());
}
