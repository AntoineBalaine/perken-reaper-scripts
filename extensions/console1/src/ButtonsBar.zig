const imgui = @import("reaper_imgui.zig");
const Theme = @import("theme/Theme.zig");
const defaults = @import("constants.zig");
const styles = @import("styles.zig");
const actions = @import("actions.zig");

pub const Result = struct {
    open: bool,
    action: ?actions.ModeAction,
};

pub fn ButtonsBar(
    ctx: imgui.ContextPtr,
    style_manager: *styles.StyleManager,
) !Result {
    var rv = Result{ .open = true, .action = null };
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        { // close the rack
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, @as([*:0]const u8, Theme.Icons.get(.close)), defaults.button_size, defaults.button_size })) {
                rv.open = false;
            }
        }
        if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_DelayNormal })) {
            try imgui.SetTooltip(.{ ctx, "close" });
        }

        { // settings win
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, Theme.Icons.get(.pin), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .settings = .open };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, "Settings" });
        }

        { // main win style config
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, Theme.Icons.get(.arrow_right), defaults.button_size, defaults.button_size })) {
                style_manager.rack_style_open.* = !style_manager.rack_style_open.*;
            }
        }

        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, "main window styles config" });
        }

        { // Helper Win style config
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, Theme.Icons.get(.arrow_down), defaults.button_size, defaults.button_size })) {
                style_manager.main_style_open.* = !style_manager.main_style_open.*;
            }
        }

        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, "settings window styles config" });
        }

        { // mapping panel shortcut
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, Theme.Icons.get(.plus), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .change_mode = .mapping_panel };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, "Mapping Panel" });
        }
    }

    try imgui.SameLine(.{ctx});
    return rv;
}
