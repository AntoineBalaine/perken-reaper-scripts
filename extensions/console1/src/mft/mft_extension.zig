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
const mft_fx = @import("mft_fx.zig");
const mft_order = @import("mft_order.zig");
const mft_actions = @import("mft_actions.zig");

pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .debug => .debug,
        .safe => .info,
        .fast => .warn,
        .small => .err,
    },
};

// The toggle decision is saved, so that it survives a restart of REAPER.
const ext_section = "console1_mft";
const ext_visible_key = "panel_visible";

fn loadPanelVisible() void {
    const raw = reaper.GetExtState(ext_section, ext_visible_key);
    if (@intFromPtr(raw) == 0) return;
    MftGlobals.get().mft.panel_visible = !std.mem.eql(u8, std.mem.span(raw), "0");
}

fn setOrder(globals: *MftGlobals, order: mft_order.Order) void {
    const track = globals.current_track orelse return;
    mft_fx.applyOrder(track, order);
}

/// Runs an action of the controller (see mft_actions.zig).
fn run(kind: mft_actions.Kind, globals: *MftGlobals) void {
    switch (kind) {
        .toggle_ui => {
            globals.mft.panel_visible = !globals.mft.panel_visible;
            reaper.SetExtState(ext_section, ext_visible_key, if (globals.mft.panel_visible) "1" else "0", true);
        },
        .order_eq_s_c => setOrder(globals, .eq_s_c),
        .order_s_c_eq => setOrder(globals, .s_c_eq),
        .order_s_eq_c => setOrder(globals, .s_eq_c),
        .order_next => midi_events.stepOrder(globals, 1),
        .order_previous => midi_events.stepOrder(globals, -1),
        // The wizard is a card under the device, so the window of the device opens with it.
        .calibrate => if (globals.wizard.active) globals.wizard.stop() else {
            globals.wizard.start();
            globals.mft.panel_visible = true;
        },
    }
}

/// The registrations, which REAPER keeps pointers to, so they live for the whole session.
const registrations = blk: {
    var regs: [mft_actions.entries.len]reaper.custom_action_register_t = undefined;
    for (mft_actions.entries, 0..) |a, i| regs[i] = .{ .section = 0, .id_str = a.id.ptr, .name = a.name.ptr };
    break :blk regs;
};
var action_ids: [mft_actions.entries.len]c_int = @splat(0);

fn onCommand(sec: ?reaper.KbdSectionInfo, command: c_int, val: c_int, valhw: c_int, relmode: c_int, hwnd: ?reaper.HWND) callconv(.c) bool {
    _ = .{ sec, val, valhw, relmode, hwnd };
    if (command == 0) return false;
    for (action_ids, 0..) |id, i| {
        if (id != command) continue;
        run(mft_actions.entries[i].kind, MftGlobals.get());
        return true;
    }
    return false;
}

// Report the toggle state so the action shows a checkmark in menus.
fn toggleActionHook(command_id: c_int) callconv(.c) c_int {
    // The toggle of the panel is the first action, whose checkmark this reports.
    comptime std.debug.assert(mft_actions.entries[0].kind == .toggle_ui);
    if (command_id != 0 and command_id == action_ids[0]) {
        return if (MftGlobals.get().mft.panel_visible) 1 else 0;
    }
    return -1;
}

fn registerActions() void {
    for (&registrations, 0..) |*reg, i| {
        action_ids[i] = reaper.plugin_register("custom_action", @ptrCast(@constCast(reg)));
        if (action_ids[i] == 0) std.log.scoped(.mft).warn("the action {s} could not be registered", .{reg.id_str});
    }
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
    loadPanelVisible();
    mft_imgui.register();

    return 1;
}
