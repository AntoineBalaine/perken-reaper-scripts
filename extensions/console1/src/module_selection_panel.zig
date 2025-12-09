const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Theme = @import("theme/Theme.zig");
const styles = @import("styles.zig");
const PushWindowStyle = @import("styles_components.zig").PushStyle;
const PopWindowStyle = @import("styles_components.zig").PopStyle;
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const BrowseState = statemachine.BrowseState;
const mapping_actions = @import("mapping_actions.zig");
const MappingPanelAction = mapping_actions.MappingPanelAction;
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const ui_helpers = @import("ui_helpers.zig");

pub fn drawModuleSelectionPanel(
    ctx: imgui.ContextPtr,
    browse_state: *const BrowseState,
    drwls_splitter: *imgui.DrawListSplitterPtr,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?MappingPanelAction {
    var rv: ?MappingPanelAction = null;

    const PopStyle = try PushWindowStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowSize(.{ ctx, 500, 300, null });

    var open = true;

    if (try imgui.Begin(.{ ctx, tr(translations, .module_sel_title), &open })) {
        defer imgui.End(.{ctx}) catch {};

        const module_values = comptime std.enums.values(ModulesList);

        var fx_name_buf: [512:0]u8 = undefined;

        inline for (module_values, 0..) |module, i| {
            const is_selected = (browse_state.selected_module == module);
            const module_name = @tagName(module);

            const display_text = if (browse_state.available_modules[i]) |cached|
                cached
            else
                std.fmt.bufPrintZ(&fx_name_buf, "{s}    [No FX]", .{module_name}) catch module_name;

            if (try imgui.Selectable(.{ ctx, display_text })) {
                rv = .browse_confirm;
            }

            if (is_selected) {
                try ui_helpers.drawInvertedSlctblColors(ctx, display_text, drwls_splitter);
            }
        }

        try imgui.Separator(.{ctx});

        if (try imgui.Button(.{ ctx, "Cancel" })) {
            rv = .browse_cancel;
        }
    }

    if (!open) {
        rv = .browse_cancel;
    }

    return rv;
}
