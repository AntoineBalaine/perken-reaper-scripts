// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
const c = @cImport({
    @cInclude("csurf/control_surface_wrapper.h");
});
const ImGuiLoop = @import("imgui_loop.zig");
const debugconfig = @import("config");
const Globals = @import("globals.zig");

pub fn getGlobals() *Globals {
    return &Globals.instance;
}

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

// var action_id: c_int = undefined;
var myCsurf: c.C_ControlSurface = undefined;

var queries_id: c_int = undefined;

/// retrieve user settings
/// retrieve the controller config
/// register the actions for each of the buttons
fn init() !void {
    logger.init();
    try Globals.init();
    try Globals.instance.initLoggerState();
    myCsurf = control_surface.init(-1, -1, null);
}

fn deinit() void {
    logger.deinit();
    Globals.instance.deinit();
    control_surface.deinit(myCsurf);
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

    if (Globals.instance.state.current_mode != .suspended) {
        ImGuiLoop.register();
    }

    return 1;
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("rapidcheck/rapidcheck_tests.zig");
    _ = @import("models/playground.zig");
    _ = @import("tests/c1_model_tests.zig");
    _ = @import("tests/mode_switch_tests.zig");
}
