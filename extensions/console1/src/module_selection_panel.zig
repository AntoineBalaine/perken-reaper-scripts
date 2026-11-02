//! The screen where the module to map is chosen. It has the look of the presets screen: its heading engraved, and the modules
//! in a card whose rows light up under the mouse and under the cursor of the controller.
const std = @import("std");
const imgui = @import("reaper_imgui");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const BrowseState = statemachine.BrowseState;
const mapping_actions = @import("mapping_actions.zig");
const MappingPanelAction = mapping_actions.MappingPanelAction;
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const card_kit = @import("components/panel_card.zig");
const ui_helpers = @import("ui_helpers.zig");
const widgets = @import("components/widgets.zig");
const panel_theme = @import("panel_theme");

/// The height under the card that the key that cancels keeps.
const footer_height = 44.0;

pub fn drawModuleSelectionPanel(
    ctx: imgui.ContextPtr,
    browse_state: *const BrowseState,
    drwls_splitter: *imgui.DrawListSplitterPtr,
    translations: *const TranslationStore,
) !?MappingPanelAction {
    _ = drwls_splitter;
    var rv: ?MappingPanelAction = null;

    // Because the screen has the look of the panel, it pushes the colors and the styles of the hardware theme.
    panel_theme.push(ctx);
    defer panel_theme.pop(ctx);

    try card_kit.drawEngraved(ctx, tr(translations, .mapping_title));

    var available_w: f64 = undefined;
    var available_h: f64 = undefined;
    try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
    const overhead = try card_kit.cardOverhead(ctx);
    const row_height = try imgui.GetTextLineHeightWithSpacing(.{ctx});
    const module_values = comptime std.enums.values(ModulesList);
    // The card is as tall as its rows, or as the room that the window leaves it when the rows do not fit.
    const rows_height = row_height * @as(f64, @floatFromInt(module_values.len)) + 4;
    const room = @min(rows_height, @max(available_h - footer_height - overhead, 120));

    var fx_name_buf: [512:0]u8 = undefined;
    const card = try card_kit.beginCard(ctx, "##modules_card", tr(translations, .module_sel_title), room);
    if (card.visible) {
        inline for (module_values, 0..) |module, i| {
            const display_text = if (browse_state.available_modules[i]) |cached|
                cached
            else
                std.mem.printSentinel(&fx_name_buf, "{s}    {s}", .{ ui_helpers.moduleName(translations, module), tr(translations, .mapping_no_fx) }, 0) catch ui_helpers.moduleName(translations, module);

            if (try card_kit.row(ctx, display_text, false, browse_state.selected_module == module, null)) {
                rv = .{ .enter_assign = module };
            }
        }
    }
    try card_kit.endCard(ctx, card.plate);

    if (try widgets.roundButton(.{ ctx, tr(translations, .module_sel_cancel), "##module_sel_cancel", null, null, .right })) {
        rv = .browse_cancel;
    }

    return rv;
}
