const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const SettingsPanel = @import("settings_panel.zig");
const dispatch = @import("actions.zig").dispatch;

pub const SettingsActions = union(enum) {
    open, // Request to open settings
    save, // Save and close
    cancel, // Cancel and close
};

pub fn settingsActions(state: *State, set_action: SettingsActions) void {
    switch (set_action) {
        .open => {
            if (globals.settings_panel == null) {
                globals.settings_panel = SettingsPanel.init(&globals.preferences, globals.allocator) catch blk: {
                    logger.log(.err, "open settings failed: {s}", .{@tagName(set_action)}, null, globals.allocator);
                    break :blk null;
                };
            }
            if (globals.settings_panel) |_| {
                dispatch(state, .{ .change_mode = .settings });
            } else {
                logger.log(.err, "settings_panel data unfound: {s}", .{@tagName(set_action)}, null, globals.allocator);
            }
        },
        .save => {
            if (globals.settings_panel) |*panel| {
                panel.save() catch {
                    logger.log(.err, "save settings failed: {s}", .{@tagName(set_action)}, null, globals.allocator);
                    return;
                    // TODO: implement error handling
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
    }
}
