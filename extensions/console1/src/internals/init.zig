const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Allocator = std.mem.Allocator;
const fs_helpers = @import("fs_helpers.zig");
const types = @import("types.zig");
const UserSettings = @import("userPrefs.zig").UserSettings;
const State = @import("state.zig");
const getControllerPath = @import("fs_helpers.zig").getControllerPath;
const config = @import("config.zig");

/// retrieve user settings
/// check tha realearn’s installed,
/// check whether realearn instances are present on fx monitoring
/// (load them if not)
/// retrieve the controller config
/// register the actions for each of the buttons
/// return the hook command function that
pub fn controllerInit(allocator: Allocator) !State {
    const userSettings = UserSettings.init(allocator, "c1");
    const controller_dir = try getControllerPath("c1", allocator);
    const state = try State.init(allocator, controller_dir, userSettings);
    _ = try config.init(allocator, controller_dir);
    return state;
}
