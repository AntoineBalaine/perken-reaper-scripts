const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const styles = @import("styles.zig");
const PushWindowStyle = @import("styles_components.zig").PushStyle;
const Globals = @import("globals.zig").Globals;
const mapping_browser = @import("mapping_browser.zig");
const log = std.log.scoped(.save_preset_dialog);

pub const SavePresetAction = union(enum) {
    save: [:0]const u8,
    cancel: void,
};

pub const SavePresetDialog = struct {
    name_buffer: [256:0]u8 = undefined,
    existing_presets: [][:0]const u8 = &.{},
    show_overwrite_confirm: bool = false,
    pending_name: [:0]const u8 = "",

    /// Initialize the dialog with the current FX context.
    /// Because we need to list existing presets, we load them from disk.
    /// Because we use the arena allocator for existing_presets, we do not need a deinit() method.
    /// The arena will be cleaned up when the mode changes.
    pub fn init(
        allocator: std.mem.Allocator,
        fx_name: [:0]const u8,
        module: @import("statemachine.zig").ModulesList,
        resource_path: [*:0]const u8,
    ) !SavePresetDialog {
        var dialog = SavePresetDialog{};

        const default_name: [:0]const u8 = "default";
        std.mem.copyForwards(u8, &dialog.name_buffer, default_name.ptr[0 .. default_name.len + 1]);

        // Load existing presets for reference
        // Because we use the arena allocator, the presets will be freed when the arena is reset,
        // which happens when we exit the mode.
        dialog.existing_presets = mapping_browser.getMappingNames(
            allocator,
            resource_path,
            fx_name,
            module,
        ) catch |err| {
            log.warn("Failed to load existing presets: {}", .{err});
            return dialog;
        };

        return dialog;
    }

    /// Render the save preset dialog and return an action if user confirms or cancels.
    pub fn draw(
        self: *SavePresetDialog,
        ctx: imgui.ContextPtr,
        style_manager: *styles.StyleManager,
    ) !?SavePresetAction {
        var rv: ?SavePresetAction = null;

        const PopWindowStyle = try PushWindowStyle(ctx, .main, style_manager);
        defer PopWindowStyle(ctx) catch {};

        try imgui.SetNextWindowSize(.{ ctx, 400, 300, null });

        var open = true;

        if (try imgui.Begin(.{ ctx, "Save Preset", &open })) {
            defer imgui.End(.{ctx}) catch {};

            // Because we want to show existing presets for reference, we list them
            if (self.existing_presets.len > 0) {
                try imgui.Text(.{ ctx, "Existing presets:" });
                for (self.existing_presets) |preset_name| {
                    try imgui.Text(.{ ctx, preset_name });
                }
                try imgui.Separator(.{ctx});
            }

            try imgui.Text(.{ ctx, "Preset name:" });

            // TODO: Implement text input when ImGui binding is available
            // For now, we show the current buffer content as text
            const current_name = std.mem.span(@as([*:0]const u8, &self.name_buffer));
            try imgui.Text(.{ ctx, current_name });
            try imgui.Text(.{ ctx, "(Text input not yet implemented)" });

            try imgui.Separator(.{ctx});

            // Save and Cancel buttons
            if (try imgui.Button(.{ ctx, "Save" })) {
                // Because we cannot save a preset with an empty name, we validate first
                if (self.name_len == 0) {
                    log.warn("Cannot save preset with empty name", .{});
                } else {
                    const name_to_save = self.name_buffer[0..self.name_len :0];

                    // Because we need to check if the name already exists, we search the list
                    const name_exists = for (self.existing_presets) |existing| {
                        if (std.mem.eql(u8, existing, name_to_save)) break true;
                    } else false;

                    if (name_exists and !self.show_overwrite_confirm) {
                        // Show confirmation popup
                        self.show_overwrite_confirm = true;
                        self.pending_name = name_to_save;
                    } else {
                        rv = .{ .save = name_to_save };
                    }
                }
            }

            try imgui.SameLine(.{ctx});

            if (try imgui.Button(.{ ctx, "Cancel" })) {
                rv = .cancel;
            }

            // Overwrite confirmation popup
            if (self.show_overwrite_confirm) {
                try imgui.OpenPopup(.{ ctx, "Overwrite?" });
            }

            if (try imgui.BeginPopup(.{ ctx, "Overwrite?" })) {
                defer imgui.EndPopup(.{ctx}) catch {};

                var msg_buf: [256:0]u8 = undefined;
                const msg = try std.fmt.bufPrintZ(
                    &msg_buf,
                    "Preset '{s}' already exists. Overwrite?",
                    .{self.pending_name},
                );
                try imgui.Text(.{ ctx, msg });

                if (try imgui.Button(.{ ctx, "Yes" })) {
                    rv = .{ .save = self.pending_name };
                    self.show_overwrite_confirm = false;
                }

                try imgui.SameLine(.{ctx});

                if (try imgui.Button(.{ ctx, "No" })) {
                    self.show_overwrite_confirm = false;
                }
            }
        }

        // Because the user clicked the close button, we cancel
        if (!open) rv = .cancel;

        return rv;
    }
};

test {
    std.testing.refAllDecls(@This());
}
