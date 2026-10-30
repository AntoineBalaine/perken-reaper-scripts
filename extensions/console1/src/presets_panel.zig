//! The screen of the presets: the modules with their FX, the presets of one of them, the name to save under, and the
//! question about a name that is taken. The unit moves the cursor and confirms, and the mouse and the keyboard do the
//! same here.
const std = @import("std");
const imgui = @import("reaper_imgui");
const statemachine = @import("statemachine.zig");
const PresetsState = statemachine.PresetsState;
const actions = @import("action_types.zig");
const ui_helpers = @import("ui_helpers.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const substituteFirst = @import("translations.zig").substituteFirst;

/// Because the list of presets is a child window with a draw list of its own, and a splitter only works on the draw list
/// that it was created for, the highlight of its rows cannot share the splitter of the rows of the modules.
var list_splitter: imgui.DrawListSplitterPtr = null;

pub fn drawPresetsPanel(
    ctx: imgui.ContextPtr,
    state: *PresetsState,
    drwls_splitter: *imgui.DrawListSplitterPtr,
    translations: *const TranslationStore,
) !?actions.PresetsAction {
    var rv: ?actions.PresetsAction = null;
    var buffer: [768:0]u8 = undefined;
    var text_buffer: [768:0]u8 = undefined;

    try imgui.Text(.{ ctx, tr(translations, switch (state.purpose) {
        .load => .presets_title_load,
        .save => .presets_title_save,
    }) });
    try imgui.Separator(.{ctx});

    switch (state.stage) {
        .modules => {
            try imgui.Text(.{ ctx, tr(translations, .presets_pick_module) });
            for (state.rows, 0..) |row, index| {
                const has_fx = row.fx_index != null;
                // Because the highlight draws its own text, it takes the text without the id that follows the "##".
                const text = std.mem.printSentinel(&text_buffer, "{s}    {s}", .{
                    @tagName(row.module),
                    if (has_fx) row.fx_name else tr(translations, .mapping_no_fx),
                }, 0) catch continue;
                const label = std.mem.printSentinel(&buffer, "{s}##row{d}", .{ text, index }, 0) catch continue;
                if (!has_fx) try imgui.BeginDisabled(.{ctx});
                const clicked = try imgui.Selectable(.{ ctx, label });
                if (!has_fx) try imgui.EndDisabled(.{ctx});
                if (clicked and has_fx) rv = .{ .pick = index };
                if (index == state.module_cursor) {
                    try ui_helpers.drawInvertedSlctblColors(ctx, text, drwls_splitter, try imgui.GetWindowDrawList(.{ctx}));
                }
            }
        },
        .presets => {
            const row = state.rows[state.module_cursor];
            const header = std.mem.printSentinel(&buffer, "{s}    {s}", .{ @tagName(row.module), row.fx_name }, 0) catch "";
            try imgui.Text(.{ ctx, header });
            try imgui.Spacing(.{ctx});
            if (try imgui.BeginChild(.{ ctx, "##preset_list", 0, -30, null, imgui.WindowFlags_None })) {
                for (state.names, 0..) |name, index| {
                    var label_buffer: [320:0]u8 = undefined;
                    const label = std.mem.printSentinel(&label_buffer, "{s}##preset{d}", .{ name, index }, 0) catch continue;
                    if (try imgui.Selectable(.{ ctx, label })) rv = .{ .pick = index };
                    if (index == state.preset_cursor) {
                        try ui_helpers.drawInvertedSlctblColors(ctx, name, &list_splitter, try imgui.GetWindowDrawList(.{ctx}));
                        if (state.scroll_changed) {
                            try imgui.SetScrollHereY(.{ ctx, null });
                            state.scroll_changed = false;
                        }
                    }
                }
            }
            imgui.EndChild(.{ctx}) catch {};
        },
        .name => {
            try imgui.Text(.{ ctx, tr(translations, .preset_name_label) });
            if (state.scroll_changed) {
                try imgui.SetKeyboardFocusHere(.{ ctx, null });
                state.scroll_changed = false;
            }
            const entered = try imgui.InputText(.{
                ctx,
                "##preset_name",
                @as([*]u8, @ptrCast(&state.name_buffer)),
                state.name_buffer.len,
                imgui.InputTextFlags_EnterReturnsTrue,
                null,
            });
            if (entered) rv = .confirm;
            try imgui.Spacing(.{ctx});
            if (try imgui.Button(.{ ctx, tr(translations, .preset_save) })) rv = .confirm;
        },
        .overwrite => {
            const message = substituteFirst(&buffer, tr(translations, .preset_overwrite_confirm), state.nameSlice());
            try imgui.Text(.{ ctx, message });
            try imgui.Spacing(.{ctx});
            if (try imgui.Button(.{ ctx, tr(translations, .preset_yes) })) rv = .confirm;
            try imgui.SameLine(.{ctx});
            if (try imgui.Button(.{ ctx, tr(translations, .preset_no) })) rv = .cancel;
        },
    }

    if (state.message != .none) {
        try imgui.Spacing(.{ctx});
        try imgui.TextColored(.{ ctx, try imgui.GetStyleColor(.{ ctx, imgui.Col_PlotHistogram }), tr(translations, switch (state.message) {
            .none => unreachable,
            .no_presets => .presets_none,
            .unsupported_fx => .presets_unsupported,
            .save_failed => .presets_save_failed,
        }) });
    }

    if (state.stage != .overwrite) {
        try imgui.Spacing(.{ctx});
        if (try imgui.Button(.{ ctx, tr(translations, .preset_cancel) })) rv = .cancel;
    }
    return rv;
}
