const imgui = @import("reaper_imgui");
const c1_theme = @import("theme/c1_theme.zig");
const theme_editor = @import("theme_editor.zig");
const config = @import("config");
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
            try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, @as([*:0]const u8, c1_theme.Icons.get(.close)), defaults.button_size, defaults.button_size })) {
                rv.open = false;
            }
        }
        if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_DelayNormal })) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_close) });
        }

        { // settings win
            try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, c1_theme.Icons.get(.wrench), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .settings = .open };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_settings) });
        }

        { // load a preset
            try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, c1_theme.Icons.get(.arrow_down), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .presets = .{ .enter = .load } };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_load_preset) });
        }

        { // save a preset
            try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
            defer imgui.PopFont(.{ctx}) catch {};
            if (try imgui.Button(.{ ctx, c1_theme.Icons.get(.save), defaults.button_size, defaults.button_size })) {
                rv.action = .{ .presets = .{ .enter = .save } };
            }
        }
        if (try imgui.IsItemHovered(.{ctx})) {
            try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_save_preset) });
        }

        if (comptime @field(config, "test")) {
            { // mapping panel shortcut (dev only)
                try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
                defer imgui.PopFont(.{ctx}) catch {};
                if (try imgui.Button(.{ ctx, c1_theme.Icons.get(.plus), defaults.button_size, defaults.button_size })) {
                    rv.action = .{ .change_mode = .mapping_panel };
                }
            }
            if (try imgui.IsItemHovered(.{ctx})) {
                try imgui.SetTooltip(.{ ctx, tr(translations, .buttons_mapping_panel) });
            }

            { // theme editor (dev only)
                try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
                defer imgui.PopFont(.{ctx}) catch {};
                if (try imgui.Button(.{ ctx, c1_theme.Icons.get(.pin), defaults.button_size, defaults.button_size })) {
                    theme_editor.theme_editor_open = !theme_editor.theme_editor_open;
                }
            }
            if (try imgui.IsItemHovered(.{ctx})) {
                try imgui.SetTooltip(.{ ctx, "Theme Editor" });
            }
        }
    }

    try imgui.SameLine(.{ctx});
    return rv;
}
