const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const SettingsPanel = @import("settings_panel.zig");
const Preferences = @import("settings.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.settings);

pub const SettingsActions = union(enum) {
    open, // Request to open settings
    save, // Save and close
    cancel, // Cancel and close
    scroll: u8,
    toggle,
};

pub fn settingsActions(state: *State, set_action: SettingsActions) void {
    switch (set_action) {
        .open => {
            if (globals.settings_panel == null) {
                globals.settings_panel = SettingsPanel.init(&globals.preferences) catch blk: {
                    log.err("open settings failed: {s}", .{@tagName(set_action)});
                    break :blk null;
                };
            }
            if (globals.settings_panel) |_| {
                dispatch(state, .{ .change_mode = .settings });
            } else {
                log.err("settings_panel data unfound: {s}", .{@tagName(set_action)});
            }
        },
        .save => {
            if (globals.settings_panel) |*panel| {
                panel.save() catch {
                    log.err("save settings failed: {s}", .{@tagName(set_action)});
                    return;
                    // settings: implement error handling
                    // Show user notification
                };
                globals.settings_panel = null;
            }
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .cancel => {
            if (globals.settings_panel) |_| {
                globals.settings_panel = null;
            }
            state.current_mode = .fx_ctrl;
            // Dunno why, calling dispatch here crashes the UI.
            // dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .toggle => {
            if (globals.settings_panel) |*panel| {
                if (Preferences.SettingsFields.fromIndex(panel.scroll_position_rel)) |field| {
                    _ = panel.temp_settings.toggleField(field);
                }
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
        .Struct => blk: {
            var count = 0;
            inline for (type_info.Struct.fields) |field| {
                // If it's an EnumArray, count the enum variants
                if (std.mem.eql(u8, field.name, "default_fx")) {
                    const enum_type = @import("statemachine.zig").ModulesList;
                    count += @typeInfo(enum_type).Enum.fields.len;
                } else {
                    // Recursively count fields for nested structs
                    count += countFields(field.type);
                }
            }
            break :blk count;
        },
        .Enum => type_info.Enum.fields.len,
        // Scalar types count as 1
        .Bool, .Int, .Float, .Pointer => 1,
        else => @compileError("Unsupported type: " ++ @typeName(T)),
    };
}
