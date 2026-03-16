const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Globals = @import("globals.zig").Globals;
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const mapping_actions = @import("mapping_actions.zig");
const module_selection_panel = @import("module_selection_panel.zig");
const mapping_panel = @import("mapping_panel.zig");
const save_preset_dialog = @import("save_preset_dialog.zig");

/// Draws the wrapper mapping panel window that consolidates all three sub-mode panels.
/// Because we need a single window for all sub-modes, we route to the appropriate panel
/// based on the current sub-mode state. Each sub-panel manages its own window presentation,
/// and this consolidation layer handles the routing logic.
pub fn drawMappingPanelWindow(
    ctx: imgui.ContextPtr,
    globals: *Globals,
    drwls_splitter: *imgui.DrawListSplitterPtr,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?mapping_actions.MappingPanelAction {
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowSize(.{ ctx, 1500, 500, null });

    var rv: ?mapping_actions.MappingPanelAction = null;

    // Get window title based on mode
    const window_title = switch (globals.state.mapping_panel.mode) {
        .browse => tr(translations, .module_sel_title),
        .assign => tr(translations, .mapping_title),
        .save => tr(translations, .preset_manager_title),
    };

    // Common window management
    var open = true;
    if (try imgui.Begin(.{ ctx, window_title, &open, imgui.WindowFlags_None })) {
        defer imgui.End(.{ctx}) catch {};

        // Route to appropriate sub-panel based on sub-mode
        rv = switch (globals.state.mapping_panel.mode) {
            .browse => |*browse_state| try module_selection_panel.drawModuleSelectionPanel(
                ctx,
                browse_state,
                drwls_splitter,
            ),
            .assign => |*assign_state| try mapping_panel.drawMappingPanel(
                ctx,
                &globals.state,
                assign_state,
                translations,
            ),
            .save => |*save_state| try save_preset_dialog.drawSavePresetDialog(
                ctx,
                save_state,
                style_manager,
                translations,
            ),
        };
    }
    if (!open) rv = .exit_to_fx_ctrl;

    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
