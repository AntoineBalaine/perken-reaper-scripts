const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const ControllerConfig = @import("types.zig").ControllerConfig;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;
const ini = @import("ini");
const types = @import("types.zig");
const UserSettings = types.UserSettings;

/// read config:
/// find the reaper resource path
/// append the /Data/Perken/C1 folder
/// read the controller config INI file
/// get the controller rfxChain
/// read the fx prefs INI file
fn getUserPrefs(allocator: Allocator, userPrefsPath: []const u8, userSettings: *UserSettings) !void {
    const file = try std.fs.cwd().openFile(userPrefsPath, .{});
    defer file.close();

    var parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                const Case = std.meta.FieldEnum(UserSettings);
                const case = std.meta.stringToEnum(Case, kv.key) orelse continue;
                switch (case) {
                    .show_start_up_message => userSettings.show_start_up_message = std.mem.eql(u8, @tagName(case), "true"),
                    .show_feedback_window => userSettings.show_feedback_window = std.mem.eql(u8, @tagName(case), "true"),
                    .show_plugin_ui => userSettings.show_plugin_ui = std.mem.eql(u8, @tagName(case), "true"),
                }
            },
            .section => {},
            .enumeration => {},
        }
    }
}

/// caller must free
fn getPerkenPath(allocator: Allocator) ![]const u8 {
    const reaper_path = reaper.GetResourcePath();

    const paths = [_][]const u8{ std.mem.span(reaper_path), "Data", "PerkenControl" };
    const Prk_path = try std.fs.path.join(allocator, &paths);
    return Prk_path;
}

/// caller must free
pub fn parseConfig(allocator: Allocator, controller_name: []const u8) !*UserSettings {
    const perken_path = try getPerkenPath(allocator);

    const paths = [_][]const u8{ perken_path, controller_name };
    const controller_path = try std.fs.path.join(allocator, &paths);
    const userPrefs = try allocator.create(UserSettings);
    userPrefs.* = UserSettings{};
    try getUserPrefs(allocator, controller_path, userPrefs);
    return userPrefs;
}

test "userPrefs" {
    const allocator = std.testing.allocator;
    const userPrefsPath = "resources/userPrefs.ini";
    const userPrefs = try allocator.create(UserSettings);
    defer allocator.destroy(userPrefs);
    userPrefs.* = UserSettings{};
    try getUserPrefs(allocator, userPrefsPath, userPrefs);
    try std.testing.expectEqual(userPrefs.show_start_up_message, false);
    try std.testing.expectEqual(userPrefs.show_start_up_message, false);
    try std.testing.expectEqual(userPrefs.show_plugin_ui, false);
}

test "controller prefs" {
    const ref =
        \\\[CONFIG]
        \\\name=Console1
        \\\channelStripPath=c1_chain.RfxChain
        \\\[MODULES]
        \\\module0=c1_Eq.json
        \\\module1=c1_Comp.json
        \\\module2=c1_Gate.json
        \\\[MODES]
        \\\mode0=fx_control
        \\\mode1=fx_select
        \\\mode3=settings
    ;
    _ = ref;
}
