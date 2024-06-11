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
// read config:
// find the reaper resource path
// append the /Data/Perken/C1 folder
// read the controller config INI file
// get the controller rfxChain
// read the fx prefs INI file

fn getUserPrefs(allocator: Allocator, controller_path: []const u8, userSettings: *UserSettings) !void {
    const userPrefsPath = try std.fs.path.join(allocator, &[_][*:0]const u8{ controller_path, "c1_config.ini" });
    const file = try std.fs.cwd().openFile(userPrefsPath, .{});
    defer file.close();

    var parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                // const Case = enum { show_start_up_message, show_feedback_window, show_plugin_ui };
                const Case = std.meta.FieldEnum(UserSettings);
                const case = std.meta.stringToEnum(Case, kv.key) orelse continue;
                switch (case) {
                    .show_start_up_message => userSettings.show_start_up_message = std.mem.eql(case, "true"),
                    .show_feedback_window => userSettings.show_feedback_window = std.mem.eql(case, "true"),
                    .show_plugin_ui => userSettings.show_plugin_ui = std.mem.eql(case, "true"),
                    else => {},
                }
            },
            .section => {},
            .enumeration => {},
        }
    }
}

// caller must free
fn getPerkenPath(allocator: Allocator) ![*:0]const u8 {
    const reaper_path = reaper.GetResourcePath();

    const Prk_path = try std.fs.path.join(allocator, &[_][*:0]const u8{ reaper_path, "Data", "PerkenControl" });
    return Prk_path;
}

pub fn parseConfig(allocator: Allocator, controller_name: []const u8) !void {
    const perken_path = getPerkenPath(allocator);

    const controller_path = try std.fs.path.join(allocator, &[_][*:0]const u8{ perken_path, controller_name });
    const userPrefs: UserSettings = try allocator.create(UserSettings{});
    try getUserPrefs(allocator, controller_path, userPrefs);
    return userPrefs;
}

test "userPrefs" {
    const alloc = std.testing.allocator;
    // create temp dir with temp files.
    const tmpDir = "path/to/dir";
    var settings = UserSettings{};
    const prefs = try getUserPrefs(alloc, tmpDir, &settings);
    defer alloc.free(prefs);
    try std.testing.expectEqual(settings.show_start_up_message, true);
    try std.testing.expectEqual(settings.show_start_up_message, true);
    try std.testing.expectEqual(settings.show_plugin_ui, true);
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
