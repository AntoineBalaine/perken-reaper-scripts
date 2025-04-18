const std = @import("std");
const Globals = @import("../globals.zig").Globals;
const SettingsPanel = @import("../settings_panel.zig");
const actions = @import("../actions.zig");
const settings_actions = @import("../settings_actions.zig");
const rapidcheck = @cImport({
    @cInclude("settings_test.h");
});

const StatefulTest = struct {
    globals: Globals,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !StatefulTest {
        const test_env = StatefulTest{
            .globals = try @import("../models/globals_model.zig").initMinimalGlobals(),
            .allocator = allocator,
        };
        return test_env;
    }

    pub fn deinit(self: *StatefulTest) void {
        self.globals.deinit();
    }
};

export fn rc_dispatch_settings_action(env: *anyopaque, action: *rapidcheck.RC_SettingsAction) void {
    const test_env: StatefulTest = @ptrCast(@alignCast(env));

    switch (action.action_type) {
        .Open => {
            actions.dispatch(&test_env.globals, .{ .settings = .open });
        },
        .Save => {
            actions.dispatch(&test_env.globals, .{ .settings = .save });
        },
        .Cancel => {
            actions.dispatch(&test_env.globals, .{ .settings = .cancel });
        },
        .Scroll => {
            actions.dispatch(&test_env.globals, .{ .settings = .{ .scroll = action.scroll_pos } });
        },
        .Toggle => {
            actions.dispatch(&test_env.globals, .{ .settings = .toggle });
        },
        .Update => {
            const field = std.mem.sliceTo(&action.update.field, 0);

            if (action.update.is_bool) {
                const bool_update = .{
                    .field = field,
                    .val = action.update.bool_value,
                };
                actions.dispatch(&test_env.globals, .{ .settings = .{ .update_val = .{ .bool_val = bool_update } } });
            } else {
                const string_update = .{
                    .field = field,
                    .val = std.mem.sliceTo(&action.update.string_value, 0),
                };
                actions.dispatch(&test_env.globals, .{ .settings = .{ .update_val = .{ .string_val = string_update } } });
            }
        },
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
    std.mem.copy(u8, buffer[0..copy_size], value[0..copy_size]);
    buffer[copy_size] = 0; // Null terminate
}

// Run a single test
fn runSettingsTest() callconv(.C) c_int {
    const allocator = std.heap.c_allocator;

    var test_env = StatefulTest.init(allocator) catch {
        return 0; // Failure
    };
    defer test_env.deinit();

    // ... test logic here ...

    return 1; // Success
}

test "settings panel with RapidCheck" {
    const success = rapidcheck.rc_run_settings_tests();
    try std.testing.expect(success);
}
