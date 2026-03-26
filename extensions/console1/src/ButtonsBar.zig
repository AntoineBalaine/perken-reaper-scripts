const imgui = @import("reaper_imgui");
const Theme = @import("theme/Theme.zig");
const defaults = @import("constants.zig");
const styles = @import("styles.zig");
const actions = @import("action_types.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;

pub const Result = struct {
    open: bool,
    action: ?actions.ModeAction,
};

pub fn ButtonsBar(
    ctx: imgui.ContextPtr,
    translations: *const TranslationStore,
) !Result {
    var rv = Result{ .open = true, .action = null };
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        { // close the main window
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, @as([*:0]const u8, Theme.Icons.get(.close)), defaults.button_size, defaults.button_size })) {
                rv.open = false;
            }
        }
        if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_DelayNormal })) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_close) });
        }

        { // settings win
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, Theme.Icons.get(.pin), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .settings = .open };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_settings) });
        }

        { // mapping panel shortcut
            try imgui.PushFont(.{ ctx, Theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, Theme.Icons.get(.plus), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .change_mode = .mapping_panel };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_mapping_panel) });
        }
    }

    try imgui.SameLine(.{ctx});
    return rv;
}
