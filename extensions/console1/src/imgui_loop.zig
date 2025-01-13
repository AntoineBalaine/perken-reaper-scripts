const std = @import("std");

const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const styles = @import("styles.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const globals = @import("globals.zig");
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");
const SettingsPanel = @import("settings_panel.zig");
const ButtonsBar = @import("ButtonsBar.zig").ButtonsBar;
const fxParser = @import("fx_parser.zig");
const fx_browser = @import("fx_browser.zig");
const actions = @import("actions.zig");
const mapping_panel = @import("mapping_panel.zig");

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

    try fxParser.init(allocator);
    try Theme.init(ctx, true);
    try styles.init(ctx);

    windowFlags =
        imgui.WindowFlags_NoCollapse +
        imgui.WindowFlags_NoTitleBar +
        imgui.WindowFlags_NoNav + imgui.WindowFlags_NoFocusOnAppearing;
}

pub fn deinit() void {
    fxParser.deinit(allocator);
}

var buf: [128:0]u8 = undefined;

fn main() !void {
    if (ctx == null) {
        try init();
    }

    var open: bool = true;

    try imgui.SetConfigVar(.{ ctx, imgui.ConfigVar_WindowsMoveFromTitleBarOnly, 1.0 });
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowDockID(.{ ctx, -1 });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, windowFlags })) {
        defer imgui.End(.{ctx}) catch {};

        open = try ButtonsBar(ctx);
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });
        if (styles.rack_style_open) {
            try styles.StyleEditor(ctx, .rack);
        }
        if (styles.main_style_open) {
            try styles.StyleEditor(ctx, .main);
        }
        switch (globals.state.current_mode) {
            .fx_ctrl => {
                try fx_ctrl_panel.drawFxControlPanel(ctx, &globals.state);
            },
            .settings => {
                if (globals.settings_panel) |*panel| {
                    switch (try panel.draw(ctx)) {
                        .stay_open => {},
                        .close_save => {
                            actions.dispatch(&globals.state, .{ .settings = .save });
                        },
                        .close_cancel => {
                            actions.dispatch(&globals.state, .{ .settings = .cancel });
                        },
                    }
                }
            },
            .fx_sel => {
                try fx_ctrl_panel.drawFxControlPanel(ctx, &globals.state);
                const module = globals.state.fx_sel.current_category;
                const list = switch (module) {
                    .INPUT => globals.mappings_list.list.get(.INPUT),
                    .GATE => globals.mappings_list.list.get(.GATE),
                    .EQ => globals.mappings_list.list.get(.EQ),
                    .COMP => globals.mappings_list.list.get(.COMP),
                    .OUTPT => globals.mappings_list.list.get(.OUTPT),
                };

                if (!try fx_browser.ModulePopup(ctx, module, list)) {
                    actions.dispatch(&globals.state, .{ .fx_sel = .close_module_browser });
                }
            },
            .mapping_panel => {
                try mapping_panel.drawMappingPanel(ctx, &globals.state);
            },
            else => {},
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
