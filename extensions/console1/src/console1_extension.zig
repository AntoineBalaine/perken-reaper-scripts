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
const Conf = @import("internals/config.zig");
const ImGuiLoop = @import("imgui_loop.zig");
const debugconfig = @import("config");
const ConfigManager = @import("config_manager.zig");
const plugin_name = "Hello, Zig!";

var state: State = undefined;
pub var userSettings: UserSettings = .{};
var controller_dir: [*:0]const u8 = undefined;
// var action_id: c_int = undefined;
var myCsurf: c.C_ControlSurface = undefined;

var gpa_int = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }){};
const gpa = gpa_int.allocator();
var queries_id: c_int = undefined;

/// retrieve user settings
/// retrieve the controller config
/// register the actions for each of the buttons
fn init() !void {
    myCsurf = control_surface.init(-1, -1, null);
    controller_dir = getControllerPath(gpa) catch |err| {
        std.debug.print("Failed to create controller dir \n", .{});
        return err;
    };
    errdefer gpa.free(std.mem.span(controller_dir));
    Conf.init(gpa, controller_dir) catch |err| {
        std.debug.print("Failed to load config \n", .{});
        return err;
    };
    errdefer Conf.deinit(gpa);
    userSettings = try UserSettings.init(gpa, controller_dir);
    state = State.init(gpa) catch |err| {
        std.debug.print("Failed to init state \n", .{});
        return err;
    };
    ImGuiLoop.allocator = gpa;

    control_surface.state = state;
    control_surface.controller_dir = controller_dir;
    const config_manager = try ConfigManager.init(gpa, std.mem.span(controller_dir));
    _ = config_manager; // autofix

}

fn deinit() void {
    gpa.free(std.mem.span(controller_dir));
    // gpa.free(std.mem.span(controller_dir));
    // gpa.free(controller_dir);
    Conf.deinit(gpa);
    ImGuiLoop.deinit();
    state.deinit();
    control_surface.deinit(myCsurf);
    const deinit_status = gpa_int.deinit();
    if (deinit_status == .leak) {
        std.debug.print("Memory leak detected\n", .{});
    }
}

export fn ReaperPluginEntry(instance: reaper.HINSTANCE, rec: ?*reaper.plugin_info_t) c_int {
    _ = instance; // autofix

    if (rec == null or !reaper.init(rec.?)) {
        deinit();
        return 0;
    }

    init() catch {
        return 0;
    };

    // _ = reaper.plugin_register("csurf_inst", myCsurf.?);
    _ = reaper.plugin_register("csurf", @constCast(@ptrCast(&control_surface.c1_reg)));

    _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&ImGuiLoop.onCommand)));
    ImGuiLoop.register();
    // const action = reaper.custom_action_register_t{ .section = 0, .id_str = "REAIMGUI_ZIG", .name = "ReaImGui Zig example" };
    // action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
    // _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));

    if (debugconfig.@"test") {
        const query_action = reaper.custom_action_register_t{ .section = 0, .id_str = "C1 TEST", .name = "C1 TEST" };
        queries_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&query_action)));
    }
    return 1;
}

test {
    std.testing.refAllDecls(@This());
}
