//! The screen of the presets: the modules with their FX, the presets of one of them, the name to save under, and the
//! question about a name that is taken. The unit moves the cursor and confirms, and the mouse and the keyboard do the
//! same here. It has the look of the window of the plugin browser: its heading engraved, and each stage in a card.
const std = @import("std");
const imgui = @import("reaper_imgui");
const statemachine = @import("statemachine.zig");
const PresetsState = statemachine.PresetsState;
const actions = @import("action_types.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const substituteFirst = @import("translations.zig").substituteFirst;
const safePrint = @import("utils").safePrint;
const card_kit = @import("components/panel_card.zig");
const widgets = @import("components/widgets.zig");
const panel_theme = @import("panel_theme");

/// The height under the card that the line of the message and the key that cancels keep.
const footer_height = 44.0;

/// The rows of the modules: each has its FX, and a module that has none cannot be chosen.
fn drawModuleRows(ctx: imgui.ContextPtr, state: *PresetsState, translations: *TranslationStore) !?actions.PresetsAction {
    var rv: ?actions.PresetsAction = null;
    var buffer: [768:0]u8 = undefined;
    for (state.rows, 0..) |row, index| {
        const has_fx = row.fx_index != null;
        // Because the id that follows the "##" is not drawn, the text of the row is only what comes before it.
        const label = std.mem.printSentinel(&buffer, "{s}    {s}##row{d}", .{
            @tagName(row.module),
            if (has_fx) row.fx_name else tr(translations, .mapping_no_fx),
            index,
        }, 0) catch continue;
        if (!has_fx) try imgui.BeginDisabled(.{ctx});
        const clicked = try card_kit.row(ctx, label, false, has_fx and index == state.module_cursor, &state.scroll_changed);
        if (!has_fx) try imgui.EndDisabled(.{ctx});
        if (clicked and has_fx) rv = .{ .pick = index };
    }
    return rv;
}

/// The rows of the presets of the chosen FX.
fn drawPresetRows(ctx: imgui.ContextPtr, state: *PresetsState) !?actions.PresetsAction {
    var rv: ?actions.PresetsAction = null;
    var label_buffer: [320:0]u8 = undefined;
    for (state.names, 0..) |name, index| {
        const label = std.mem.printSentinel(&label_buffer, "{s}##preset{d}", .{ name, index }, 0) catch continue;
        if (try card_kit.row(ctx, label, false, index == state.preset_cursor, &state.scroll_changed)) rv = .{ .pick = index };
    }
    return rv;
}

pub fn drawPresetsPanel(
    ctx: imgui.ContextPtr,
    state: *PresetsState,
    drwls_splitter: *imgui.DrawListSplitterPtr,
    translations: *const TranslationStore,
) !?actions.PresetsAction {
    _ = drwls_splitter;
    var rv: ?actions.PresetsAction = null;
    const text_store: *TranslationStore = @constCast(translations);

    // Because the screen has the look of the panel, it pushes the colors and the styles of the hardware theme, which has the
    // amber of the lit parts of the panel where the theme of REAPER has its own accent.
    panel_theme.push(ctx);
    defer panel_theme.pop(ctx);

    // The arrow at the top steps back to the modules, as the browser has one that steps out of a menu.
    if (state.stage != .modules and state.stage != .overwrite) {
        if (try imgui.ArrowButton(.{ ctx, "##presets_back", imgui.Dir_Left })) rv = .cancel;
        try imgui.SameLine(.{ctx});
    }
    try card_kit.drawEngraved(ctx, tr(translations, switch (state.purpose) {
        .load => .presets_title_load,
        .save => .presets_title_save,
    }));

    var available_w: f64 = undefined;
    var available_h: f64 = undefined;
    try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
    const overhead = try card_kit.cardOverhead(ctx);
    const row_height = try imgui.GetTextLineHeightWithSpacing(.{ctx});
    const key_height = 2 * 8.5 + 8;
    const room = @max(available_h - footer_height, 120) - overhead;

    var title_buf: [256:0]u8 = undefined;
    switch (state.stage) {
        .modules => {
            const card = try card_kit.beginCard(ctx, "##presets_card_modules", tr(translations, .presets_pick_module), room);
            if (card.visible) {
                if (try drawModuleRows(ctx, state, text_store)) |picked| rv = picked;
            }
            try card_kit.endCard(ctx, card.plate);
        },
        .presets => {
            // The card is labelled with the module and the FX whose presets it lists.
            const chosen = state.rows[state.module_cursor];
            const title = safePrint(&title_buf, "{s}    {s}", .{ @tagName(chosen.module), chosen.fx_name });
            const card = try card_kit.beginCard(ctx, "##presets_card_presets", title, room);
            if (card.visible) {
                if (try drawPresetRows(ctx, state)) |picked| rv = picked;
            }
            try card_kit.endCard(ctx, card.plate);
        },
        .name => {
            const card = try card_kit.beginCard(ctx, "##presets_card_name", tr(translations, .preset_name_label), @min(room, row_height * 2 + key_height + 16));
            if (card.visible) {
                if (state.scroll_changed) {
                    try imgui.SetKeyboardFocusHere(.{ ctx, null });
                    state.scroll_changed = false;
                }
                try imgui.PushItemWidth(.{ ctx, -1 });
                const entered = try imgui.InputText(.{
                    ctx,
                    "##preset_name",
                    @as([*]u8, @ptrCast(&state.name_buffer)),
                    state.name_buffer.len,
                    imgui.InputTextFlags_EnterReturnsTrue,
                    null,
                });
                try imgui.PopItemWidth(.{ctx});
                if (entered) rv = .confirm;
                try imgui.Spacing(.{ctx});
                if (try widgets.roundButton(.{ ctx, tr(translations, .preset_save), "##presets_save", null, null, .right })) rv = .confirm;
            }
            try card_kit.endCard(ctx, card.plate);
        },
        .overwrite => {
            const card = try card_kit.beginCard(ctx, "##presets_card_overwrite", tr(translations, .preset_overwrite_title), @min(room, row_height * 2 + key_height + 16));
            if (card.visible) {
                var buffer: [768:0]u8 = undefined;
                try imgui.TextWrapped(.{ ctx, substituteFirst(&buffer, tr(translations, .preset_overwrite_confirm), state.nameSlice()) });
                try imgui.Spacing(.{ctx});
                if (try widgets.roundButton(.{ ctx, tr(translations, .preset_yes), "##presets_yes", null, null, .right })) rv = .confirm;
                try imgui.SameLine(.{ctx});
                if (try widgets.roundButton(.{ ctx, tr(translations, .preset_no), "##presets_no", null, null, .right })) rv = .cancel;
            }
            try card_kit.endCard(ctx, card.plate);
        },
    }

    // Under the card: what went wrong, if something did, and the key that cancels.
    if (state.message != .none) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, panel_theme.amber });
        try imgui.Text(.{ ctx, tr(translations, switch (state.message) {
            .none => unreachable,
            .no_presets => .presets_none,
            .unsupported_fx => .presets_unsupported,
            .save_failed => .presets_save_failed,
        }) });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    if (state.stage != .overwrite) {
        if (try widgets.roundButton(.{ ctx, tr(translations, .preset_cancel), "##presets_cancel", null, null, .right })) rv = .cancel;
    }
    return rv;
}
