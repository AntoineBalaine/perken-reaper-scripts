const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Preferences = @import("settings.zig");
const globals = @import("globals.zig");

// Temporary copy for editing
temp_settings: Preferences,
dirty: bool = false, // Track if changes were made

const SettingsPanel = @This();
pub fn init(current: *const Preferences, allocator: std.mem.Allocator) !SettingsPanel {
    return .{
        .temp_settings = try current.clone(allocator),
    };
}

pub fn deinit(self: *SettingsPanel) void {
    self.temp_settings.deinit();
}

pub fn draw(self: *@This(), ctx: imgui.ContextPtr) !enum { stay_open, close_save, close_cancel } {
    if (try imgui.Begin(.{ ctx, "Settings", null })) {
        defer imgui.End(.{ctx}) catch {};

        // Edit settings...
        var changed = false;

        // UI Settings
        try imgui.TextWrapped(.{ ctx, "UI Settings" });
        if (try imgui.Checkbox(.{ ctx, "Show Startup Message", &self.temp_settings.show_startup_message })) {
            changed = true;
        }
        if (try imgui.Checkbox(.{ ctx, "Show Feedback Window", &self.temp_settings.show_feedback_window })) {
            changed = true;
        }
        if (try imgui.Checkbox(.{ ctx, "Show Plugin UI", &self.temp_settings.show_plugin_ui })) {
            changed = true;
        }
        try imgui.Spacing(.{ctx});

        // Routing Settings
        try imgui.TextWrapped(.{ ctx, "Routing Settings" });
        if (try imgui.Checkbox(.{ ctx, "Manual Routing", &self.temp_settings.manual_routing })) {
            changed = true;
        }
        try imgui.Spacing(.{ctx});

        // Logging Settings
        try imgui.TextWrapped(.{ ctx, "Logging Settings" });
        if (try imgui.Checkbox(.{ ctx, "Log to File", &self.temp_settings.log_to_file })) {
            changed = true;
        }
        const log_levels: [:0]const u8 = "Debug\x00Info\x00Warning\x00Error";
        // const log_levels = [_][:0]const u8{ "Debug", "Info", "Warning", "Error" };
        var current_level: c_int = @intFromEnum(self.temp_settings.log_level);
        try imgui.TextWrapped(.{ ctx, "Log Level" });
        if (try imgui.Combo(.{ ctx, "##log_level", &current_level, log_levels, -1 })) {
            self.temp_settings.log_level = @enumFromInt(current_level);
            changed = true;
        }

        if (changed) self.dirty = true;

        if (try imgui.Button(.{ ctx, "Save" })) {
            if (self.dirty) {
                return .close_save;
            }
        }
        try imgui.SameLine(.{ctx});
        if (try imgui.Button(.{ ctx, "Cancel" })) {
            return .close_cancel;
        }
    }
    return .stay_open;
}

pub fn save(self: *@This()) !void {
    // Copy temp settings back to global settings
    try globals.preferences.copyFrom(&self.temp_settings);
    try globals.preferences.save();

    // Apply changes that need immediate effect
    if (self.temp_settings.log_to_file != globals.preferences.log_to_file) {
        try globals.updateLoggerFile();
    }
}

test {
    std.testing.refAllDecls(@This());
}
