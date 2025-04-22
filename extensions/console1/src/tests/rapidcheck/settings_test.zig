const std = @import("std");
const Globals = @import("../../globals.zig").Globals;
const SettingsPanel = @import("../../settings_panel.zig");
const actions = @import("../../actions.zig");
const settings_actions = @import("../../settings_actions.zig");
const rapidcheck = @cImport({
    @cInclude("tests/rapidcheck/rapidcheck_wrapper.h");
    @cInclude("tests/rapidcheck/settings_test.h");
});

const StatefulTest = struct {
    globals: Globals,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !StatefulTest {
        const test_env = StatefulTest{
            .globals = try @import("../../models/globals_model.zig").initMinimalGlobals(),
            .allocator = allocator,
        };
        return test_env;
    }

    pub fn deinit(self: *StatefulTest) void {
        self.globals.deinit();
    }
};

export fn rc_dispatch_settings_action(env: *anyopaque, action: rapidcheck.RC_SettingsAction) void {
    const test_env: *StatefulTest = @ptrCast(@alignCast(env));

    switch (action.action_type) {
        rapidcheck.OPEN => {
            actions.dispatch(&test_env.globals, .{ .settings = .open });
        },
        rapidcheck.SAVE => {
            actions.dispatch(&test_env.globals, .{ .settings = .save });
        },
        rapidcheck.CANCEL => {
            actions.dispatch(&test_env.globals, .{ .settings = .cancel });
        },
        rapidcheck.SCROLL => {
            actions.dispatch(&test_env.globals, .{ .settings = .{ .scroll = action.data.scroll_pos } });
        },
        rapidcheck.TOGGLE => {
            actions.dispatch(&test_env.globals, .{ .settings = .toggle });
        },
        rapidcheck.UPDATE => {
            const field = std.mem.span(action.data.update.field);

            if (action.data.update.type == rapidcheck.BOOL_SETTING) {
                // Create a proper Zig struct with the correct types
                const bool_val = SettingsPanel.SettingsValUpdate{
                    .bool_val = .{
                        .field = field,
                        .val = action.data.update.value.bool_value,
                    },
                };
                actions.dispatch(&test_env.globals, .{ .settings = .{ .update_val = bool_val } });
            } else {
                // Create a proper Zig struct with the correct types
                const string_val = SettingsPanel.SettingsValUpdate{
                    .string_val = .{
                        .field = field,
                        .val = std.mem.span(action.data.update.value.string_value),
                    },
                };
                actions.dispatch(&test_env.globals, .{ .settings = .{ .update_val = string_val } });
            }
        },
        else => unreachable,
    }
}

export fn rc_is_settings_panel_open(env: *anyopaque) bool {
    const test_env: *StatefulTest = @alignCast(@ptrCast(env));
    return test_env.globals.settings_panel != null;
}

export fn rc_get_settings_scroll_position(env: *anyopaque) u8 {
    const test_env: *StatefulTest = @ptrCast(@alignCast(env));
    return if (test_env.globals.settings_panel) |panel|
        panel.scroll_position_abs
    else
        0;
}

export fn rc_get_settings_bool(env: *anyopaque, field: [*:0]const u8) bool {
    const test_env: *StatefulTest = @ptrCast(@alignCast(env));
    const field_str = std.mem.span(field);

    if (test_env.globals.settings_panel) |panel| {
        // Use temp settings if panel is open
        return if (std.mem.eql(u8, field_str, "show_startup_message"))
            panel.temp_settings.show_startup_message
        else if (std.mem.eql(u8, field_str, "show_feedback_window"))
            panel.temp_settings.show_feedback_window
        else if (std.mem.eql(u8, field_str, "show_plugin_ui"))
            panel.temp_settings.show_plugin_ui
        else if (std.mem.eql(u8, field_str, "manual_routing"))
            panel.temp_settings.manual_routing
        else if (std.mem.eql(u8, field_str, "log_to_file"))
            panel.temp_settings.log_to_file
        else if (std.mem.eql(u8, field_str, "start_suspended"))
            panel.temp_settings.start_suspended
        else
            false;
    } else {
        // Use global preferences if panel is closed
        return if (std.mem.eql(u8, field_str, "show_startup_message"))
            test_env.globals.preferences.show_startup_message
        else if (std.mem.eql(u8, field_str, "show_feedback_window"))
            test_env.globals.preferences.show_feedback_window
        else if (std.mem.eql(u8, field_str, "show_plugin_ui"))
            test_env.globals.preferences.show_plugin_ui
        else if (std.mem.eql(u8, field_str, "manual_routing"))
            test_env.globals.preferences.manual_routing
        else if (std.mem.eql(u8, field_str, "log_to_file"))
            test_env.globals.preferences.log_to_file
        else if (std.mem.eql(u8, field_str, "start_suspended"))
            test_env.globals.preferences.start_suspended
        else
            false;
    }
}

export fn rc_get_settings_string(env: *anyopaque, field: [*:0]const u8, buffer: [*]u8, buffer_size: usize) void {
    const test_env: *StatefulTest = @ptrCast(@alignCast(env));
    const field_str = std.mem.span(field);

    var value: []const u8 = "";

    if (test_env.globals.settings_panel) |panel| {
        // Use temp settings if panel is open
        if (std.mem.eql(u8, field_str, "language")) {
            value = panel.temp_settings.language;
        }
    } else {
        // Use global preferences if panel is closed
        if (std.mem.eql(u8, field_str, "language")) {
            value = test_env.globals.preferences.language;
        }
    }

    const copy_size = @min(value.len, buffer_size - 1);
    std.mem.copyForwards(u8, buffer[0..copy_size], value[0..copy_size]);
    buffer[copy_size] = 0; // Null terminate
}

// Export functions for C++ to create and manage the Zig test environment
export fn rc_initialize_zig_environment() ?*anyopaque {
    const allocator = std.heap.c_allocator;

    var test_env = allocator.create(StatefulTest) catch return null;
    _ = &test_env;
    test_env.* = StatefulTest.init(allocator) catch {
        allocator.destroy(test_env);
        return null;
    };

    return @ptrCast(test_env);
}

export fn rc_cleanup_zig_environment(env: *anyopaque) void {
    const test_env: *StatefulTest = @ptrCast(@alignCast(env));
    const allocator = std.heap.c_allocator;

    test_env.deinit();
    allocator.destroy(test_env);
}

test "settings panel with RapidCheck" {
    const success = rapidcheck.rc_run_settings_tests();
    try std.testing.expect(success);
}
