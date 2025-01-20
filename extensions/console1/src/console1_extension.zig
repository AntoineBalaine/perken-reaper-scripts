// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
const c = @cImport({
    @cInclude("csurf/control_surface_wrapper.h");
});
const getControllerPath = @import("internals/fs_helpers.zig").getControllerPath;
const ImGuiLoop = @import("imgui_loop.zig");
const debugconfig = @import("config");
const globals = @import("globals.zig");
const logger = @import("logger.zig");
const hooks = @import("hooks.zig");
const log = std.log.scoped(.extension);

const plugin_name = "Perken C1";
pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .Debug => .debug,
        .ReleaseSafe => .info,
        .ReleaseFast => .warn,
        .ReleaseSmall => .err,
    },
    .logFn = logger.logFn,
};

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
    logger.init();
    myCsurf = control_surface.init(-1, -1, null);
    controller_dir = getControllerPath(gpa) catch |err| {
        log.warn("Failed to create controller dir", .{});
        return err;
    };
    errdefer |err| {
        log.err("C1 init failed: {s}", .{@errorName(err)});
        gpa.free(std.mem.span(controller_dir));
    }

    ImGuiLoop.allocator = gpa;

    control_surface.controller_dir = controller_dir;
    try globals.init(gpa, controller_dir);
}

fn deinit() void {
    logger.deinit();
    gpa.free(std.mem.span(controller_dir));
    // gpa.free(std.mem.span(controller_dir));
    // gpa.free(controller_dir);
    globals.deinit(gpa);
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

    // Register toggle actions
    _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&hooks.onCommand)));

    hooks.registerCommands();

    if (globals.state.current_mode != .suspended) {
        ImGuiLoop.register();
    }

    if (debugconfig.@"test") {
        const query_action = reaper.custom_action_register_t{ .section = 0, .id_str = "C1 TEST", .name = "C1 TEST" };
        queries_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&query_action)));
    }
    return 1;
}

test {
    std.testing.refAllDecls(@This());
}
