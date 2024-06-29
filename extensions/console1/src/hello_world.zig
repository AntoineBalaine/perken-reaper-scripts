// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const ImGui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
const ControllerConfig = @import("internals/ControllerConfigLoader.zig");
const appInit = @import("internals/init.zig");
const State = @import("internals/state.zig");
const c = @cImport({
    @cInclude("csurf/control_surface_wrapper.h");
});

const plugin_name = "Hello, Zig!";
var state: State = undefined;
var action_id: c_int = undefined;
var myCsurf: c.C_ControlSurface = undefined;

var gpa_int = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_int.allocator();

// to implement the csurf interface, you'd probably want to do that from C++ instead of Zig to not have to deal with ABI headaches...
// eg. the C++ csurf implementation just forwarding the calls to extern "C" functions implemented in Zig

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
    _ = instance;

    if (rec == null or !reaper.init(rec.?)) {
        deinit();
        return 0;
    }

    reaper.ShowConsoleMsg("Hello, Zig!\n");
    state = appInit.controllerInit(gpa) catch {
        std.debug.print("state init failed\n", .{});
        return 0;
    };
    // Define the opaque struct to represent IReaperControlSurface
    myCsurf = control_surface.init(&state);
    if (myCsurf == null) {
        std.debug.print("Failed to create fake csurf\n", .{});
        deinit();
        return 0;
    }
    _ = reaper.plugin_register("csurf_inst", myCsurf.?);

    // const action = reaper.custom_action_register_t{ .section = 0, .id_str = "REAIMGUI_ZIG", .name = "ReaImGui Zig example" };
    // action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
    _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));

    return 1;
}

fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };
    std.debug.print("{any}\n", .{action_id});

    if (state.hookCommand(command)) {
        return 1;
    } else {
        return 0;
    }
}

test {
    std.testing.refAllDecls(@This());
}
