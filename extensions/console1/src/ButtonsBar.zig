const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const defaults = @import("constants.zig");
const styles = @import("styles.zig");
const globals = @import("globals.zig");
pub fn ButtonsBar(ctx: imgui.ContextPtr) !bool {
    var rv = true;
    try imgui.BeginGroup(.{ctx});

    { // close the rack
        try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
        defer imgui.PopFont(.{ctx}) catch {};
        if (try imgui.Button(.{ ctx, @as([*:0]const u8, Theme.Icons.get(.close)), defaults.button_size, defaults.button_size })) {
            rv = false;
        }
    }
    if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_DelayNormal })) {
        try imgui.SetTooltip(.{ ctx, "close" });
    }

    { // track routing matrix
        try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
        defer imgui.PopFont(.{ctx}) catch {};
        const pinIcon = Theme.Icons.get(.pin);
        if (try imgui.Button(.{ ctx, @as([*:0]const u8, pinIcon), defaults.button_size, defaults.button_size })) {
            globals.state.current_mode = .settings;
        }
    }
    if (try imgui.IsItemHovered(.{ctx})) {
        try imgui.SetTooltip(.{ ctx, "Settings" });
    }

    { // Rack win style config
        try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
        defer imgui.PopFont(.{ctx}) catch {};
        const pinIcon = Theme.Icons.get(.arrow_right);
        if (try imgui.Button(.{ ctx, @as([*:0]const u8, pinIcon), defaults.button_size, defaults.button_size })) {
            try styles.toggle_rack_style_win();
        }
    }

    if (try imgui.IsItemHovered(.{ctx})) {
        try imgui.SetTooltip(.{ ctx, "rack styles config" });
    }

    { // Main Win styles config
        try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
        defer imgui.PopFont(.{ctx}) catch {};
        const pinIcon = Theme.Icons.get(.arrow_down);
        if (try imgui.Button(.{ ctx, @as([*:0]const u8, pinIcon), defaults.button_size, defaults.button_size })) {
            try styles.toggle_main_style_win();
        }
    }

    if (try imgui.IsItemHovered(.{ctx})) {
        try imgui.SetTooltip(.{ ctx, "main window styles config" });
    }

    try imgui.EndGroup(.{ctx});
    try imgui.SameLine(.{ctx});
    const posX = try imgui.GetCursorPosX(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, posX - 20 });
    return rv;
}
