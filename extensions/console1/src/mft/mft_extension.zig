const std = @import("std");
const host_io = @import("host_io");
const mft_globals = @import("mft_globals.zig");
const Reaper = @import("reaper");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface_mft.zig");
const defaults_mft = @import("defaults_mft.zig");
const fs_helpers = @import("fs_helpers");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const mft_imgui = @import("mft_imgui.zig");
const midi_events = @import("csurf/midi_events_mft.zig");

pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .debug => .debug,
        .safe => .info,
        .fast => .warn,
        .small => .err,
    },
};

// Command id of the "MFT: Toggle UI" custom action, so it can be bound to a key.
var toggle_ui_cmd_id: c_int = undefined;

fn onCommand(sec: ?reaper.KbdSectionInfo, command: c_int, val: c_int, valhw: c_int, relmode: c_int, hwnd: ?reaper.HWND) callconv(.c) bool {
    _ = .{ sec, val, valhw, relmode, hwnd };
    if (command == toggle_ui_cmd_id) {
        const g = MftGlobals.get();
        g.mft.panel_visible = !g.mft.panel_visible;
        return true;
    }
    return false;
}

// Report the toggle state so the action shows a checkmark in menus.
fn toggleActionHook(command_id: c_int) callconv(.c) c_int {
    if (command_id == toggle_ui_cmd_id) {
        return if (MftGlobals.get().mft.panel_visible) 1 else 0;
    }
    return -1;
}

fn registerActions() void {
    const toggle_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "PRKN_MFT_TOGGLE_UI",
        .name = "MFT: Toggle UI",
    };
    toggle_ui_cmd_id = reaper.plugin_register("custom_action", @ptrCast(@constCast(&toggle_action)));
    _ = reaper.plugin_register("hookcommand2", @ptrCast(@constCast(&onCommand)));
    _ = reaper.plugin_register("toggleaction", @ptrCast(@constCast(&toggleActionHook)));
}

fn init() !void {
    mft_globals.io_threaded = host_io.create();
    const io = mft_globals.hostIo();
    defaults_mft.ensureConfigPath(io, fs_helpers.RealFileSystem.fileSystemOps(mft_globals.hostIo())) catch {};
    MftGlobals.get().init();
    midi_events.installSettingsHook();
}

export fn ReaperPluginEntry(instance: reaper.HINSTANCE, rec: ?*reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null or !reaper.init(rec.?)) {
        return 0;
    }

    init() catch {
        return 0;
    };

    _ = reaper.plugin_register("csurf", @ptrCast(@constCast(&control_surface.mft_reg)));

    registerActions();
    mft_imgui.register();

    return 1;
}
