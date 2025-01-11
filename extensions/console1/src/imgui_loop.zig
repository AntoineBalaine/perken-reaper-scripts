const std = @import("std");

const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const configurations = @import("configurations.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const globals = @import("globals.zig");

const plugin_name = "CONSOLE1";
pub var action_id: c_int = undefined;
pub var allocator: std.mem.Allocator = undefined;
var ctx: imgui.ContextPtr = null;
var text = std.mem.zeroes([255:0]u8);
var windowFlags: c_int = undefined;

fn init() !void {
    try imgui.init(reaper.plugin_getapi);
    const ctx_flags = imgui.ConfigFlags_DockingEnable;
    ctx = try imgui.CreateContext(.{ plugin_name, ctx_flags });

    try Theme.init(ctx, true);
    try configurations.init(ctx);

    windowFlags =
        imgui.WindowFlags_NoCollapse +
        imgui.WindowFlags_NoTitleBar +
        imgui.WindowFlags_NoNav + imgui.WindowFlags_NoFocusOnAppearing;
}

pub fn deinit() void {}

var buf: [128:0]u8 = undefined;

fn main() !void {
    if (ctx == null) {
        try init();
    }

    var open: bool = true;

    try imgui.SetConfigVar(.{ ctx, imgui.ConfigVar_WindowsMoveFromTitleBarOnly, 1.0 });
    const PopStyle = try configurations.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowDockID(.{ ctx, -1 });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, windowFlags })) {
        defer imgui.End(.{ctx}) catch {};
        try imgui.Text(.{ ctx, "Hello World" });
        if (configurations.rack_style_open) {
            try configurations.StyleEditor(ctx, .rack);
        }
        if (configurations.main_style_open) {
            try configurations.StyleEditor(ctx, .main);
        }
    }
    // Add debug panel
    if (logger.debug_window_active) {
        try debug_panel.drawDebugPanel(ctx, &globals.state, &globals.event_log);
    }

    if (!open)
        reset();
}

pub fn register() void {
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn reset() void {
    _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

fn onTimer() callconv(.C) void {
    main() catch {
        reset();
        _ = reaper.ShowMessageBox(imgui.last_error.?, plugin_name, 0);
    };
}

pub fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };

    if (command == action_id) {
        if (ctx == null) register() else reset();
        return 1;
    }

    return 0;
}
