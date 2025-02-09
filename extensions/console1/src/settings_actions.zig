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
                if (@import("utils.zig").calculateNewScrollPosition(
                    i16,
                    &settings_panel.scroll_position_abs,
                    &settings_panel.scroll_position_rel,
                    new_pos,
                    12,
                )) |delta| {
                    log.debug("Settings scroll: abs={d} delta={d} rel={d}/{d}", .{
                        settings_panel.scroll_position_abs,
                        delta,
                        settings_panel.scroll_position_rel,
                        12,
                    });
                }
            }
        },
    }
}
