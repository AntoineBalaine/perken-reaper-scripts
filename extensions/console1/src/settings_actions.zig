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
                globals.settings_panel = SettingsPanel.init(&globals.preferences, globals.arena) catch blk: {
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
                panel.deinit();
                globals.settings_panel = null;
            }
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .cancel => {
            if (globals.settings_panel) |*panel| {
                panel.deinit();
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
            if (globals.settings_panel == null) return;
            const old_pos_abs = globals.settings_panel.?.scroll_position_abs;
            globals.settings_panel.?.scroll_position_abs = new_pos;

            var delta: i16 = undefined;
            if ((old_pos_abs == 127 or old_pos_abs == 0) and new_pos == old_pos_abs) {
                if (old_pos_abs == 127) delta = 1 else delta = -1;
            } else {
                delta = @as(i16, @intCast(new_pos)) - @as(i16, @intCast(old_pos_abs));
            }

            const prefs_count: i16 = 12;

            if (prefs_count == 0) return; // Guard against empty list
            // Update scroll position with wrapping
            // Calculate new position with wrapping
            const new_pos_rel = @as(i16, @intCast(globals.settings_panel.?.scroll_position_rel)) + delta;

            // Wrap around using modulo
            // Add max_pos before taking modulo to handle negative numbers correctly
            if (new_pos_rel >= prefs_count) {
                // Wrap forward using remainder
                globals.settings_panel.?.scroll_position_rel = @intCast(@rem(new_pos_rel, prefs_count));
            } else if (new_pos_rel < 0) {
                // Wrap backward
                const wrapped = prefs_count - @rem(@as(i32, @intCast(@abs(new_pos_rel))), prefs_count);
                globals.settings_panel.?.scroll_position_rel = @intCast(if (wrapped == prefs_count) 0 else wrapped);
            } else {
                globals.settings_panel.?.scroll_position_rel = @intCast(new_pos_rel);
            }

            // Log scroll action
            log.debug("Settings scroll: abs={d} delta={d} rel={d}/{d}", .{
                globals.settings_panel.?.scroll_position_abs,
                delta,
                globals.settings_panel.?.scroll_position_rel,
                prefs_count,
            });
        },
    }
}
