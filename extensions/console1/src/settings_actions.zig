const std = @import("std");
const Globals = @import("globals.zig").Globals;
const SettingsPanel = @import("settings_panel.zig");
const Preferences = @import("settings.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.settings);

pub const SettingsActions = @import("action_types.zig").SettingsActions;

pub fn settingsActions(globals: *Globals, set_action: SettingsActions) void {
    switch (set_action) {
        .open => {
            if (globals.settings_panel == null) {
                globals.settings_panel = SettingsPanel.init(&globals.preferences) catch blk: {
                    log.err("open settings failed: {s}", .{@tagName(set_action)});
                    break :blk null;
                };
            }
            if (globals.settings_panel) |_| {
                dispatch(globals, .{ .change_mode = .settings });
            } else {
                log.err("settings_panel data unfound: {s}", .{@tagName(set_action)});
            }
        },
        .save => {
            if (globals.settings_panel) |*panel| {
                globals.preferences = panel.temp_settings;
                if (!comptime @import("builtin").is_test) {
                    globals.preferences.saveToDisk(globals.resource_path) catch {
                        log.err("save settings to disk failed", .{});
                    };
                    if (panel.temp_settings.log_to_file != globals.preferences.log_to_file) {
                        globals.updateLoggerState() catch {};
                    }
                }
                globals.settings_panel = null;
            }
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
        .cancel => {
            if (globals.settings_panel) |_| {
                globals.settings_panel = null;
            }
            globals.state.current_mode = .fx_ctrl;
            // Dunno why, calling dispatch here crashes the UI.
            // dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
        .toggle => {
            if (globals.settings_panel) |*panel| {
                if (Preferences.SettingsFields.fromIndex(panel.scroll_position_rel)) |field| {
                    switch (field) {
                        .language,
                        .show_startup_message,
                        .show_feedback_window,
                        .show_plugin_ui,
                        .manual_routing,
                        .log_to_file,
                        .start_suspended,
                        // .show_track_list,
                        // .focus_page_tracks,
                        .auto_insert_modules,
                        .auto_insert_bypassed,
                        .auto_reorder_modules,
                        .preferred_module_order,
                        => {
                            const toggled = panel.temp_settings.toggleField(field);
                            if (toggled) panel.dirty = true;
                        },
                        .default_INPUT,
                        .default_GATE,
                        .default_COMP,
                        .default_EQ,
                        .default_OUTPT,
                        => |cat| {
                            globals.state.default_fx_sel.current_category = switch (cat) {
                                .default_INPUT => .INPUT,
                                .default_GATE => .GATE,
                                .default_COMP => .COMP,
                                .default_EQ => .EQ,
                                .default_OUTPT => .OUTPT,
                                else => unreachable,
                            };
                            dispatch(globals, .{ .change_mode = .default_fx_sel });
                        },
                    }
                }
            }
        },
        .update_val => |val_update| {
            if (globals.settings_panel) |*panel| {
                switch (val_update) {
                    .bool_val => |bool_update| {
                        // Handle boolean settings
                        switch (bool_update.field) {
                            .show_startup_message => panel.temp_settings.show_startup_message = bool_update.val,
                            .show_feedback_window => panel.temp_settings.show_feedback_window = bool_update.val,
                            .show_plugin_ui => panel.temp_settings.show_plugin_ui = bool_update.val,
                            .manual_routing => panel.temp_settings.manual_routing = bool_update.val,
                            .log_to_file => panel.temp_settings.log_to_file = bool_update.val,
                            .start_suspended => panel.temp_settings.start_suspended = bool_update.val,
                            // .show_track_list => panel.temp_settings.show_track_list = bool_update.val,
                            // .focus_page_tracks => panel.temp_settings.focus_page_tracks = bool_update.val,
                            .auto_insert_modules => panel.temp_settings.auto_insert_modules = bool_update.val,
                            .auto_insert_bypassed => panel.temp_settings.auto_insert_bypassed = bool_update.val,
                            .auto_reorder_modules => panel.temp_settings.auto_reorder_modules = bool_update.val,
                            else => unreachable,
                        }
                    },
                    .string_val => |string_update| {
                        // Handle string settings
                        switch (string_update.field) {
                            .language => panel.temp_settings.language = string_update.val,
                            else => unreachable,
                        }
                    },
                    .enum_val => |enum_update| {
                        // Handle enum settings
                        switch (enum_update.field) {
                            .preferred_module_order => panel.temp_settings.preferred_module_order = enum_update.val,
                            else => unreachable,
                        }
                    },
                }
                panel.dirty = true;
                dispatch(globals, .{ .midi_out = .{ .settings_changed = val_update } });
            }
        },
        .scroll => |new_pos| {
            if (globals.settings_panel) |*settings_panel| {
                const fields_count = comptime countFields(@TypeOf(globals.preferences));
                if (@import("utils.zig").calculateNewScrollPosition(
                    i16,
                    &settings_panel.scroll_position_abs,
                    &settings_panel.scroll_position_rel,
                    new_pos,
                    fields_count,
                    1,
                )) |delta| {
                    log.debug("Settings scroll: abs={d} delta={d} rel={d}/{d}", .{
                        settings_panel.scroll_position_abs,
                        delta,
                        settings_panel.scroll_position_rel,
                        fields_count,
                    });
                }
            }
        },
    }
}

fn countFields(comptime T: type) comptime_int {
    const type_info = @typeInfo(T);
    return switch (type_info) {
        .@"struct" => blk: {
            var count = 0;
            inline for (type_info.@"struct".fields) |field| {
                // If it's an EnumArray, count the enum variants
                if (std.mem.eql(u8, field.name, "default_fx")) {
                    const enum_type = @import("statemachine.zig").ModulesList;
                    count += @typeInfo(enum_type).@"enum".fields.len;
                } else {
                    // Recursively count fields for nested structs
                    count += countFields(field.type);
                }
            }
            break :blk count;
        },
        .@"enum" => type_info.@"enum".fields.len,
        // Scalar types count as 1
        .bool, .int, .float, .pointer => 1,
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    };
}
