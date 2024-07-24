// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const ImGui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
const State = @import("internals/state.zig");
const c = @cImport({
    @cInclude("csurf/control_surface_wrapper.h");
});
const UserSettings = @import("internals/userPrefs.zig").UserSettings;
const getControllerPath = @import("internals/fs_helpers.zig").getControllerPath;
const config = @import("internals/config.zig");

const plugin_name = "Hello, Zig!";
var state: State = undefined;
var action_id: c_int = undefined;
var myCsurf: c.C_ControlSurface = undefined;

var gpa_int = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }){};
const gpa = gpa_int.allocator();

/// retrieve user settings
/// check tha realearn’s installed,
/// check whether realearn instances are present on fx monitoring
/// (load them if not)
/// retrieve the controller config
/// register the actions for each of the buttons
/// return the hook command function that
fn init() !void {
    const userSettings = UserSettings.init(gpa, "c1");
    const controller_dir = try getControllerPath("c1", gpa);
    state = try State.init(gpa, controller_dir, userSettings);
    _ = try config.init(gpa, controller_dir);
}

fn deinit() void {
    std.debug.print("Deinit\n", .{});
    control_surface.deinit(myCsurf);
    try state.deinit(gpa);
    const deinit_status = gpa_int.deinit();
    if (deinit_status == .leak) {
        std.debug.print("Memory leak detected\n", .{});
    }
}

export fn ReaperPluginEntry(instance: reaper.HINSTANCE, rec: ?*reaper.plugin_info_t) c_int {
    std.debug.print("entry\n", .{});

    if (rec == null or !reaper.init(rec.?)) {
        deinit();
        std.debug.print("deinit\n", .{});
        return 0;
    }

    control_surface.g_hInst = instance;
    // init() catch {
    //     std.debug.print("catch\n", .{});
    //     return 0;
    // };
    std.debug.print("init\n", .{});

    // Define the opaque struct to represent IReaperControlSurface
    // myCsurf = control_surface.init();
    // if (myCsurf == null) {
    //     std.debug.print("Failed to create fake csurf\n", .{});
    //     deinit();
    //     return 0;
    // }
    // _ = reaper.plugin_register("csurf_inst", myCsurf.?);

    _ = reaper.plugin_register("csurf", @constCast(@ptrCast(&control_surface.c1_reg)));

    // const action = reaper.custom_action_register_t{ .section = 0, .id_str = "REAIMGUI_ZIG", .name = "ReaImGui Zig example" };
    // action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
    _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));

    return 1;
}

fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };

    if (state.hookCommand(command)) {
        return 1;
    } else {
        return 0;
    }
}

test {
    std.testing.refAllDecls(@This());
}
