const std = @import("std");
const ImGui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
const Allocator = std.mem.Allocator;
const appInit = @import("internals/init.zig");

var ctx: ImGui.ContextPtr = null;
var click_count: u32 = 0;
var text = std.mem.zeroes([255:0]u8);
const plugin_name = "Hello, Zig!";
var action_id: c_int = undefined;

fn loop() !void {
    if (ctx == null) {
        try ImGui.init(reaper.plugin_getapi);
        ctx = try ImGui.CreateContext(.{plugin_name});
    }

    try ImGui.SetNextWindowSize(.{ ctx, 400, 80, ImGui.Cond_FirstUseEver });

    var open: bool = true;
    if (try ImGui.Begin(.{ ctx, plugin_name, &open })) {
        if (try ImGui.Button(.{ ctx, "Click me!" }))
            click_count +%= 1;

        if (click_count & 1 != 0) {
            try ImGui.SameLine(.{ctx});
            try ImGui.Text(.{ ctx, "\\o/" });
        }

        _ = try ImGui.InputText(.{ ctx, "text input", &text, text.len });
        try ImGui.End(.{ctx});
    }

    if (!open)
        reset();
}

fn init() void {
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

fn reset() void {
    _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
    ctx = null;
}

fn onTimer() callconv(.C) void {
    loop() catch {
        reset();
        _ = reaper.ShowMessageBox(ImGui.last_error.?, plugin_name, 0);
    };
}

fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };

    if (command == action_id) {
        if (ctx == null) init() else reset();
        return 1;
    }

    return 0;
}
