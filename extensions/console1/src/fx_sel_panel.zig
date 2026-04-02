const std = @import("std");
const imgui = @import("reaper_imgui");
const Theme = @import("theme/ReaperTheme.zig");
const fx_types = @import("fx_parser_types.zig");
const styles = @import("styles.zig");
const PushWindowStyle = @import("styles_components.zig").PushStyle;
const safePrint = @import("debug_panel.zig").safePrint;
const fx_sel_actions = @import("action_types.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const ui_helpers = @import("ui_helpers.zig");
const UiState = @import("ui_state.zig").UiState;
const FxSelSubMode = @import("statemachine.zig").FxSelSubMode;
const FxSelectionState = @import("statemachine.zig").FxSelectionState;
const StringPool = @import("string_pool.zig").StringPool;

pub const NAME: [:0]const u8 = "Fx Browser";
/// last used fx name
var last_used_fx: ?[:0]const u8 = null;

fn Directory(ctx: imgui.ContextPtr, directory: fx_types.Directory, isFxChain: bool) !?fx_sel_actions.FxSelActions {
    var buf: [std.fs.max_path_bytes:0]u8 = undefined;

    var rv: ?fx_sel_actions.FxSelActions = null;
    if (directory.subdirs) |subdirs| {
        var subdirIt = subdirs.iterator();
        while (subdirIt.next()) |subdir| {
            if (try imgui.BeginMenu(.{ ctx, subdir.value_ptr.*.name, null })) {
                defer imgui.EndMenu(.{ctx}) catch {};
                if (try Directory(ctx, subdir.value_ptr.*, isFxChain)) |action| {
                    rv = action;
                }
            }
        }
    }
    if (directory.files) |files| {
        var filesIt = files.iterator();
        while (filesIt.next()) |entry| {
            const file = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (try imgui.Selectable(.{ ctx, file })) {
                const fullPathFile = safePrint(&buf, "{s}/{s}", .{ directory.path, file });
                if (isFxChain) {
                    rv = .{ .fx_chain = .{ .path = fullPathFile } };
                } else {
                    rv = .{ .track_template = .{ .path = fullPathFile } };
                }
            }
        }
    }
    return rv;
}

fn FxList(ctx: imgui.ContextPtr, menuName: [:0]const u8, fxList: fx_types.FxList) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(menuName)), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fxList.iterator();
        while (iterator.next()) |entry| {
            const cast = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (cast.len >= 9 and std.mem.eql(u8, cast[0..9], "WaveShell")) {
                continue;
            }
            if (try imgui.Selectable(.{ ctx, cast })) {
                rv = .{ .plugin = .{ .name = cast, .mapping_name = null } };
            }
        }
    }
    return rv;
}

fn PluginsByType(ctx: imgui.ContextPtr, ui: *UiState, translations: *TranslationStore) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(tr(translations, .fx_sel_all_plugins))), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = ui.fx_plugins_by_type.iterator();
        while (iterator.next()) |entry| {
            if (try FxList(ctx, @tagName(entry.key), entry.value.*)) |selection| {
                rv = selection;
            }
        }
    }
    return rv;
}

fn FxTags(ctx: imgui.ContextPtr, ui: *UiState) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;
    inline for (@typeInfo(fx_types.FxTags).@"struct".fields) |field| {
        var tagList = @field(ui.fx_tags.*, field.name);
        if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(field.name)), null })) {
            defer imgui.EndMenu(.{ctx}) catch {};
            var iterator = tagList.iterator();
            while (iterator.next()) |entry| {
                const tagName = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
                if (try FxList(ctx, tagName, entry.value_ptr.*)) |selection| {
                    rv = selection;
                }
            }
        }
    }
    return rv;
}

fn Menus(ctx: imgui.ContextPtr, ui: *UiState, translations: *TranslationStore) !?fx_sel_actions.FxSelActions {
    const filteredFxCount = null;
    if (filteredFxCount != null) return null;

    var rv: ?fx_sel_actions.FxSelActions = null;

    if (try imgui.BeginMenu(.{ ctx, tr(translations, .fx_sel_fx_chains), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        if (try Directory(ctx, ui.fx_chains.*, true)) |selection| {
            rv = selection;
        }
    }

    if (try imgui.BeginMenu(.{ ctx, tr(translations, .fx_sel_track_templates), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        if (try Directory(ctx, ui.track_templates.*, false)) |selection| {
            rv = selection;
        }
    }

    if (try PluginsByType(ctx, ui, translations)) |selection| {
        rv = selection;
    }

    if (try FxTags(ctx, ui)) |selection| {
        rv = selection;
    }

    const elements = [3][:0]const u8{ tr(translations, .fx_sel_container), tr(translations, .fx_sel_video_processor), tr(translations, .fx_sel_recent) };
    for (elements) |element| {
        if (try imgui.Selectable(.{ ctx, element })) {
            const isLastUsed = std.mem.eql(u8, element, "recent: ");
            const lastUsed = if (isLastUsed) if (last_used_fx) |lastUsed| lastUsed else element else element;
            rv = .{ .plugin = .{ .name = lastUsed, .mapping_name = null } };
        }
    }

    return rv;
}

pub fn ModulePopup(
    ctx: imgui.ContextPtr,
    module: @import("statemachine.zig").ModulesList,
    mappings: @import("mappings_list.zig").ModuleMap,
    strings: *const StringPool,
    current_index: usize,
    sub_mode: FxSelSubMode,
    scroll_changed: *bool,
    display_menus: bool,
    g_drwls_splitter: *imgui.DrawListSplitterPtr,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
    ui: *UiState,
) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;

    const PopWindowStyle = try PushWindowStyle(ctx, .config, style_manager);
    defer PopWindowStyle(ctx) catch {};

    try imgui.SetNextWindowSize(.{ ctx, 400, 300, imgui.Cond_FirstUseEver });

    var open = true;

    if (try imgui.Begin(.{ ctx, tr(translations, .fx_sel_title), &open })) {
        defer imgui.End(.{ctx}) catch {};

        try imgui.Text(.{ ctx, @tagName(module) });

        switch (sub_mode) {
            .browse_fx => {
                var iterator = mappings.iterator();
                var i: usize = 0;
                while (iterator.next()) |entry| : (i += 1) {
                    const fx_offset = entry.key_ptr.*;
                    const fx_name = strings.get(fx_offset);
                    const is_selected = (i == current_index);

                    if (try imgui.Selectable(.{ ctx, @as([*:0]const u8, @ptrCast(fx_name)) })) {
                        const mapping_offsets = entry.value_ptr.*;
                        if (mapping_offsets.items.len == 1) {
                            const mapping_name = strings.get(mapping_offsets.items[0].name_offset);
                            rv = .{ .plugin = .{ .name = fx_name, .mapping_name = mapping_name } };
                        } else {
                            rv = .{ .select_fx = fx_offset };
                        }
                    }
                    if (is_selected) {
                        try ui_helpers.drawInvertedSlctblColors(ctx, fx_name, g_drwls_splitter, try imgui.GetWindowDrawList(.{ctx}));
                        if (scroll_changed.*) {
                            try imgui.SetScrollHereY(.{ ctx, 0.5 });
                            scroll_changed.* = false;
                        }
                    }
                }

                if (display_menus) {
                    try imgui.Separator(.{ctx});
                    if (try Menus(ctx, ui, translations)) |selection| {
                        rv = selection;
                    }
                    try imgui.Separator(.{ctx});
                }
            },
            .select_mapping => |sel| {
                try imgui.Text(.{ ctx, @as([*:0]const u8, @ptrCast(sel.fx_name)) });
                try imgui.Separator(.{ctx});

                // Because the mappings use MapEntry (with name_offset and path_offset),
                // we look up by the fx's StringPool offset and iterate the entries.
                const entries = mappings.get(sel.fx_string_pool_offset) orelse return null;
                for (entries.items, 0..) |map_entry, i| {
                    const mapping_name = strings.get(map_entry.name_offset);
                    const is_selected = (i == current_index);

                    if (try imgui.Selectable(.{ ctx, @as([*:0]const u8, @ptrCast(mapping_name)) })) {
                        rv = .{ .plugin = .{ .name = sel.fx_name, .mapping_name = mapping_name } };
                    }
                    if (is_selected) {
                        try ui_helpers.drawInvertedSlctblColors(ctx, mapping_name, g_drwls_splitter, try imgui.GetWindowDrawList(.{ctx}));
                        if (scroll_changed.*) {
                            try imgui.SetScrollHereY(.{ ctx, 0.5 });
                            scroll_changed.* = false;
                        }
                    }
                }
            },
        }
    }
    if (!open) rv = .close_browser;

    return rv;
}
