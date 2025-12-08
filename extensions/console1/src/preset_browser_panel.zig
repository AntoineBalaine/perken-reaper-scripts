const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Theme = @import("theme/Theme.zig");
const styles = @import("styles.zig");
const PushWindowStyle = @import("styles_components.zig").PushStyle;
const preset_browser_actions = @import("preset_browser_actions.zig");
const PresetBrowserAction = preset_browser_actions.PresetBrowserAction;
const TranslationStore = @import("translations.zig").TranslationStore;
const Globals = @import("globals.zig").Globals;
const drawInvertedSlctblColors = @import("fx_ctrl_panel.zig").drawInvertedSlctblColors;

pub const NAME: [:0]const u8 = "Preset Browser";

/// Renders the preset browser popup window, displaying available presets for the current FX.
/// Returns an action if the user selects a preset or closes the window.
pub fn PresetBrowserPopup(
    ctx: imgui.ContextPtr,
    globals: *Globals,
    g_drwls_splitter: *imgui.DrawListSplitterPtr,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?PresetBrowserAction {
    _ = translations;
    var rv: ?PresetBrowserAction = null;

    const browser_state = globals.state.preset_browser;

    const PopWindowStyle = try PushWindowStyle(ctx, .main, style_manager);
    defer PopWindowStyle(ctx) catch {};

    try imgui.SetNextWindowSize(.{ ctx, 400, 300, null });

    var open = true;

    // Because we want to show for which FX and module this preset browser is,
    // we include them in the window title.
    var title_buf: [256:0]u8 = undefined;
    const title = try std.fmt.bufPrintZ(
        &title_buf,
        "Presets: {s} ({s})",
        .{ browser_state.target_fx, @tagName(browser_state.target_module) },
    );

    if (try imgui.Begin(.{ ctx, title, &open })) {
        defer imgui.End(.{ctx}) catch {};

        // Because there may be no presets available, we show a message
        if (browser_state.available_presets.len == 0) {
            try imgui.Text(.{ ctx, "No presets found for this FX." });
            try imgui.Text(.{ ctx, "Create a preset by editing mappings and saving." });
        } else {
            for (browser_state.available_presets, 0..) |preset_name, i| {
                const is_selected = (i == browser_state.scroll_position_rel);

                if (try imgui.Selectable(.{ ctx, preset_name })) {
                    rv = .{ .select_preset = .{ .mapping_name = preset_name } };
                }

                if (is_selected) {
                    try drawInvertedSlctblColors(ctx, preset_name, g_drwls_splitter);
                }
            }
        }
    }

    // Because the user clicked the close button, we return the close action
    if (!open) rv = .close;

    return rv;
}
