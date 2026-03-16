const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const styles = @import("styles.zig");
const PushWindowStyle = @import("styles_components.zig").PushStyle;
const statemachine = @import("statemachine.zig");
const mapping_actions = @import("mapping_actions.zig");
const MappingPanelAction = mapping_actions.MappingPanelAction;
const TranslationStore = @import("translations.zig").TranslationStore;
const log = std.log.scoped(.save_preset_dialog);

/// Render the save preset dialog content.
/// Because this is a pure function, it does not manage window opening/closing.
/// The window management is delegated to the consolidation layer.
pub fn drawSavePresetDialog(
    ctx: imgui.ContextPtr,
    save_state: *statemachine.SaveState,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?MappingPanelAction {
    _ = translations; // Not yet used, but reserved for future i18n
    var rv: ?MappingPanelAction = null;

    const PopWindowStyle = try PushWindowStyle(ctx, .main, style_manager);
    defer PopWindowStyle(ctx) catch {};

    // Because we want to show existing presets for reference, we list them
    if (save_state.existing_presets.items.len > 0) {
        try imgui.Text(.{ ctx, "Existing presets:" });
        var preset_buf: [512:0]u8 = undefined;
        for (save_state.existing_presets.items) |preset_name| {
            const formatted = std.fmt.bufPrintZ(&preset_buf, "  {s}", .{preset_name}) catch continue;
            try imgui.Text(.{ ctx, formatted });
        }
        try imgui.Separator(.{ctx});
    }

    try imgui.Text(.{ ctx, "Preset name:" });

    _ = try imgui.InputText(.{
        ctx,
        "##preset_name",
        @as([*]u8, @ptrCast(&save_state.name_buffer)),
        save_state.name_buffer.len,
        null, // flags
        null, // callback
    });

    try imgui.Separator(.{ctx});

    if (try imgui.Button(.{ ctx, "Save" })) {
        // Because we cannot save a preset with an empty name, we validate first
        const name_to_save = std.mem.span(@as([*:0]const u8, @ptrCast(&save_state.name_buffer)));
        if (name_to_save.len == 0) {
            log.warn("Cannot save preset with empty name", .{});
        } else {
            // Because we need to check if the name already exists, we search the list
            const name_exists = for (save_state.existing_presets.items) |existing| {
                if (std.mem.eql(u8, existing, name_to_save)) break true;
            } else false;

            if (name_exists and !save_state.show_overwrite_confirm) {
                // Show confirmation popup
                save_state.show_overwrite_confirm = true;
                save_state.pending_name = name_to_save;
            } else {
                rv = .{ .save_confirm = name_to_save };
            }
        }
    }

    try imgui.SameLine(.{ctx});

    if (try imgui.Button(.{ ctx, "Cancel" })) {
        rv = .save_cancel;
    }

    // Overwrite confirmation popup
    if (save_state.show_overwrite_confirm) {
        try imgui.OpenPopup(.{ ctx, "Overwrite?" });
    }

    if (try imgui.BeginPopup(.{ ctx, "Overwrite?" })) {
        defer imgui.EndPopup(.{ctx}) catch {};

        var msg_buf: [256:0]u8 = undefined;
        const msg = try std.fmt.bufPrintZ(
            &msg_buf,
            "Preset '{s}' already exists. Overwrite?",
            .{save_state.pending_name},
        );
        try imgui.Text(.{ ctx, msg });

        if (try imgui.Button(.{ ctx, "Yes" })) {
            const name_z = std.mem.span(@as([*:0]const u8, @ptrCast(&save_state.name_buffer)));
            rv = .{ .save_confirm = name_z };
            save_state.show_overwrite_confirm = false;
        }

        try imgui.SameLine(.{ctx});

        if (try imgui.Button(.{ ctx, "No" })) {
            save_state.show_overwrite_confirm = false;
        }
    }

    return rv;
}

test {
    std.testing.refAllDecls(@This());
}
