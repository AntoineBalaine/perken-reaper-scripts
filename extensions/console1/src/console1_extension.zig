// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const Reaper = @import("reaper");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
const ImGuiLoop = @import("imgui_loop.zig");
const Globals = @import("globals.zig");

pub fn getGlobals() *Globals {
    return &Globals.instance;
}

const logger = @import("logger.zig");
const hooks = @import("hooks.zig");

pub const std_options = blk: {
    const config = @import("config");
    const is_test = @hasDecl(config, "test") and @field(config, "test");

    break :blk std.Options{
        .log_level = if (is_test) .err else switch (@import("builtin").mode) {
            .debug => .debug,
            .safe => .info,
            .fast => .warn,
            .small => .err,
        },
        .logFn = logger.logFn,
    };
};

// var action_id: c_int = undefined;
var myCsurf: c.C_ControlSurface = undefined;

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

    // In headless mode, we register a control surface instance directly so
    // that csurf callbacks fire without needing a valid reaper.ini csurf
    // config. In normal mode (including test mode with real hardware), we
    // register via csurf so REAPER uses the configured MIDI devices.
    const debugconfig = @import("config");
    if (debugconfig.headless) {
        const csurf_inst = control_surface.init(-1, -1, null);
        _ = reaper.plugin_register("csurf_inst", @ptrCast(csurf_inst));
    } else {
        _ = reaper.plugin_register("csurf", @ptrCast(@constCast(&control_surface.c1_reg)));
    }

    // Register toggle actions
    _ = reaper.plugin_register("hookcommand2", @ptrCast(@constCast(&hooks.onCommand)));

    hooks.registerCommands();

    if (Globals.instance.state.current_mode != .suspended) {
        ImGuiLoop.register();
    }

    return 1;
}

test {
    _ = @import("tests/zlowcheck.zig");
    _ = @import("tests/shift_test.zig");
    _ = @import("tests/relative_knob_test.zig");
    _ = @import("unit/protocol.zig");
    _ = @import("unit/ids.zig");
    _ = @import("unit/led_state.zig");
    _ = @import("unit/input.zig");
    _ = @import("unit/unit.zig");
    _ = @import("unit/step.zig");
    _ = @import("models/models.zig");
    _ = @import("tests/mode_switch_tests.zig");
    _ = @import("tests/settings_pbt.zig");
    _ = @import("tests/track_validation_pbt.zig");
    _ = @import("tests/mapping_panel_stateful_test.zig");
    _ = @import("tests/param_store_test.zig");
    _ = @import("tests/param_store_integration_test.zig");
    _ = @import("tests/mapping_panel_fx_ctrl_forward_test.zig");
    _ = @import("tests/fx_sel_fx_ctrl_forward_test.zig");
    _ = @import("tests/fx_ctrl_pbt.zig");
    _ = @import("tests/transport_pbt.zig");
    _ = @import("tests/fx_sel_pbt.zig");
    _ = @import("tests/fx_sel_swap_test.zig");
    _ = @import("tests/fx_sel_insertion_order_test.zig");
    _ = @import("tests/midi_learn_test.zig");
    _ = @import("tests/mappings_integration_tests.zig");
    _ = @import("tests/strip_mode_transitions_test.zig");
    _ = @import("tests/label_pool_integration_test.zig");
    _ = @import("tests/button_cycling_test.zig");
    _ = @import("tests/mock_imgui_test.zig");
    _ = @import("models/test_ui_state.zig");
    _ = @import("tests/panel_trace_test.zig");
    _ = @import("tests/gui_integration_test.zig");
    _ = @import("tests/knob_edit_test.zig");
    _ = @import("label_pool.zig");
    _ = @import("mappings.zig");
    _ = @import("mapping_browser.zig");
    _ = @import("preset_file_reader");
    _ = @import("preset_installer.zig");
    _ = @import("theme/c1_theme.zig");
}
