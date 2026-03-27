const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const actions = @import("actions.zig");
const Mode = @import("statemachine.zig").Mode;
const debugconfig = @import("config");
const reentrancy = @import("reentrancy.zig");
const test_api = @import("test_api.zig");
const preset_installer = @import("preset_installer.zig");
const Globals = @import("globals.zig").Globals;
const tr = @import("translations.zig").tr;
const log = std.log.scoped(.hooks);
const getGlobals = @import("console1_extension.zig").getGlobals;
const theme_dump = @import("theme_dump.zig");

// Store command IDs returned from registration
pub var suspend_cmd_id: c_int = undefined;
pub var toggle_gui_cmd_id: c_int = undefined;
pub var install_presets_cmd_id: c_int = undefined;
pub var save_theme_cmd_id: c_int = undefined;
pub var reentrancy_test_cmd_id: c_int = undefined;
pub var track_state_tests_cmd_id: c_int = undefined;
var testCommandIds: TestCommandIds = undefined;

const TestCommandIds = struct {
    map: std.EnumMap(reentrancy.TestApiCall, ?c_int),

    pub fn init() @This() {
        var self: @This() = .{ .map = std.EnumMap(reentrancy.TestApiCall, ?c_int).init(.{}) };
        // Initialize all entries as null
        inline for (std.meta.fields(reentrancy.TestApiCall)) |field| {
            const variant = @field(reentrancy.TestApiCall, field.name);
            self.map.put(variant, null);
        }
        return self;
    }

    pub fn get(self: *TestCommandIds, variant: reentrancy.TestApiCall) ?c_int {
        return self.map.get(variant) orelse null;
    }

    pub fn set(self: *TestCommandIds, variant: reentrancy.TestApiCall, id: c_int) void {
        self.map.put(variant, id);
    }
};

// Command handler
pub fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };

    if (command == suspend_cmd_id) {
        // Toggle suspended state
        var globals = getGlobals();
        _ = &globals;
        const new_mode: Mode = if (globals.state.current_mode == .suspended)
            .fx_ctrl
        else
            .suspended;
        actions.dispatch(globals, .{ .change_mode = new_mode });
        return 1;
    } else if (command == toggle_gui_cmd_id) {
        const globals = getGlobals();
        if (globals.state.current_mode == .suspended) {
            actions.dispatch(globals, .{ .change_mode = .fx_ctrl });
        }
        actions.dispatch(globals, .set_fx_ctrl_gui);
        return 1;
    } else if (command == install_presets_cmd_id) {
        const globals = getGlobals();
        runInstallPresets(globals);
        return 1;
    } else if (command == save_theme_cmd_id) {
        theme_dump.saveThemeToFile();
        return 1;
    } else if (debugconfig.@"test" and command == reentrancy_test_cmd_id) {
        reentrancy.runAllTests() catch |err| {
            log.err("Failed to run reentrancy tests: {}", .{err});
        };
        // reentrancy.runInitialTest() catch |err| {
        //     log.err("Failed to run initial reentrancy test: {}", .{err});
        // };
        return 1;
    } else if (debugconfig.@"test") {
        // Check if command matches any of our test command IDs
        inline for (std.meta.fields(reentrancy.TestApiCall)) |field| {
            const variant = @field(reentrancy.TestApiCall, field.name);
            if (testCommandIds.get(variant)) |cmd_id| {
                if (command == cmd_id) {
                    reentrancy.runSingleTest(variant) catch |err| {
                        log.err("Failed to run reentrancy test for {s}: {}", .{ @tagName(variant), err });
                    };
                    return 1;
                }
            }
        }
    }
    return 0;
}

pub fn runInstallPresets(globals: *Globals) void {
    const title = tr(&globals.translations, .install_presets_title);

    // Because the user needs to confirm before we modify their preset files,
    // we show a message box and only proceed if they click OK
    const confirm = reaper.ShowMessageBox(
        tr(&globals.translations, .install_presets_confirm),
        title,
        1, // MB_OKCANCEL
    );
    if (confirm != 1) return; // 1 = IDOK

    var preset_dir_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const resource_path = std.mem.span(reaper.GetResourcePath());
    const preset_dir = std.fmt.bufPrintZ(&preset_dir_buf, "{s}/presets", .{resource_path}) catch return;

    const result = preset_installer.installPresets(
        &globals.mappings_list,
        preset_dir,
    ) catch |err| {
        log.err("Failed to install presets: {}", .{err});
        _ = reaper.ShowMessageBox(tr(&globals.translations, .install_presets_error), title, 0);
        return;
    };

    var msg_buf: [512:0]u8 = undefined;
    const result_msg = std.fmt.bufPrintZ(&msg_buf, "{s} {d} presets -> {d} files.\n{s} {d} duplicates.\n\n{s}", .{
        tr(&globals.translations, .install_presets_installed),
        result.installed,
        result.files_written,
        tr(&globals.translations, .install_presets_skipped),
        result.skipped,
        tr(&globals.translations, .install_presets_restart),
    }) catch return;
    _ = reaper.ShowMessageBox(result_msg, title, 0);
}

// Registration helper
pub fn registerCommands() void {
    const suspend_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_SUSPEND",
        .name = "Console1: Suspend",
    };
    suspend_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&suspend_action)));

    const toggle_gui_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_HIDE_GUI",
        .name = "Console1: Hide FX Control Window",
    };
    toggle_gui_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&toggle_gui_action)));

    const install_presets_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_INSTALL_MAP_PRESETS",
        .name = "Console1: Install Map Presets",
    };
    install_presets_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&install_presets_action)));

    const save_theme_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_SAVE_THEME",
        .name = "Console1: Save Theme Colors to INI",
    };
    save_theme_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&save_theme_action)));

    if (debugconfig.@"test") {
        testCommandIds = TestCommandIds.init();
        inline for (comptime std.meta.fields(reentrancy.TestApiCall)) |field| {
            const variant = @field(reentrancy.TestApiCall, field.name);
            const id_str = std.fmt.comptimePrint("C1_REENTRANCE_TEST_{s}", .{@tagName(variant)});
            const name = std.fmt.comptimePrint("Console1: Run Reentrancy test {s}", .{@tagName(variant)});
            const action = reaper.custom_action_register_t{
                .section = 0,
                .id_str = id_str,
                .name = name,
            };
            const cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
            testCommandIds.set(variant, cmd_id);
        }

        const reentrancy_test_action: reaper.custom_action_register_t = .{
            .section = 0,
            .id_str = "C1_REENTRANCY_TEST",
            .name = "Console1: Run Reentrancy Tests",
        };
        reentrancy_test_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&reentrancy_test_action)));
    }
    _ = reaper.plugin_register("toggleaction", @constCast(@ptrCast(&toggleActionHook)));

    if (debugconfig.@"test") {
        test_api.registerTestApis();
    }
}

// Returns:
// -1 = action does not belong to this extension, or does not toggle
//  0 = action belongs to this extension and is currently set to "off"
//  1 = action belongs to this extension and is currently set to "on"
pub export fn toggleActionHook(command_id: c_int) callconv(.C) c_int {
    if (command_id == suspend_cmd_id) {
        // Check if we're disconnected
        return if (getGlobals().state.current_mode == .suspended) 1 else 0;
    }

    if (command_id == toggle_gui_cmd_id) {
        // Only valid when not suspended
        return if (getGlobals().state.fx_ctrl_gui_visible) 0 else 1;
    }

    return -1; // Not our action
}
