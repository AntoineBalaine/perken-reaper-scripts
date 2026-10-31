const std = @import("std");
const imgui = @import("reaper_imgui");
const fx_types = @import("fx_parser_types");
const styles = @import("styles.zig");
const fx_sel_actions = @import("action_types.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const safePrint = @import("utils").safePrint;
const UiState = @import("ui_state.zig").UiState;
const FxSelSubMode = @import("statemachine.zig").FxSelSubMode;
const FxSelectionState = @import("statemachine.zig").FxSelectionState;
const StringPool = @import("string_pool").StringPool;
const MappingsModuleMap = @import("mappings_list.zig").ModuleMap;
const fx_browser = @import("fx_browser.zig");
const c1_theme = @import("theme/c1_theme.zig");
const panel_theme = @import("panel_theme");
const card_kit = @import("components/panel_card.zig");

pub const NAME: [:0]const u8 = "Fx Browser";

/// Bundles the state needed to visually highlight the currently-selected
/// module slot. External consumers that do not use module-slot selection
/// can pass `null` for the `highlight` parameter to disable highlighting.
pub const HighlightConfig = struct {
    current_index: usize,
    scroll_changed: *bool,
    g_drwls_splitter: *imgui.DrawListSplitterPtr,
};

/// The data of the levels of the browser, as the window has it from the plugin parser.
fn browserSource(ui: *UiState, mapped_count: usize) fx_browser.Source {
    return .{
        .mapped_count = mapped_count,
        .fx_chains = ui.fx_chains,
        .track_templates = ui.track_templates,
        .plugins_by_type = ui.fx_plugins_by_type,
        .tags = ui.fx_tags,
    };
}

/// The names of the menus of the first level, in the order of `fx_browser.RootMenu`.
fn rootMenuName(menu: fx_browser.RootMenu, translations: *TranslationStore) [:0]const u8 {
    return switch (menu) {
        .fx_chains => tr(translations, .fx_sel_fx_chains),
        .track_templates => tr(translations, .fx_sel_track_templates),
        .all_plugins => tr(translations, .fx_sel_all_plugins),
        .tags_category => "category",
        .tags_developer => "developer",
        .container => tr(translations, .fx_sel_container),
        .video_processor => tr(translations, .fx_sel_video_processor),
        .recent => tr(translations, .fx_sel_recent),
    };
}

/// A screw of the face of the panel.
fn drawScrew(dl: imgui.DrawListPtr, x: f64, y: f64) !void {
    try imgui.DrawList_AddCircleFilled(.{ dl, x + 0.6, y + 0.9, 3.8, @as(c_int, @bitCast(@as(u32, 0x00000099))), 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, x, y, 3.6, panel_theme.screw_body, 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, x - 0.8, y - 0.8, 1.7, panel_theme.screw_light, 0 });
    try imgui.DrawList_AddLine(.{ dl, x - 2.2, y + 1.1, x + 2.2, y - 1.1, panel_theme.screw_slot, 1.2 });
}

/// The four screws in the corners of the face, under the title bar.
fn drawScrews(ctx: imgui.ContextPtr) !void {
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetWindowPos(.{ ctx, &x, &y });
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.GetWindowSize(.{ ctx, &w, &h });
    const inset = 8.0;
    const top = y + try imgui.GetFrameHeight(.{ctx}) + inset;
    const dl = try imgui.GetWindowDrawList(.{ctx});
    for ([_]f64{ x + inset, x + w - inset }) |screw_x| {
        try drawScrew(dl, screw_x, top);
        try drawScrew(dl, screw_x, y + h - inset);
    }
}

/// What a click on an entry of a level does, which is the same as what confirming it does.
fn clickAction(source: fx_browser.Source, level: fx_browser.Level, index: usize, translations: *TranslationStore) ?fx_sel_actions.FxSelActions {
    var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    return switch (fx_browser.activate(source, level, index, &path_buf)) {
        .enter => .{ .enter_menu = index },
        .plugin => |plugin| .{ .plugin = .{ .name = plugin, .mapping_name = null } },
        .fx_chain => |path| .{ .fx_chain = .{ .path = path } },
        .track_template => |path| .{ .track_template = .{ .path = path } },
        .root_leaf => |leaf| .{ .plugin = .{ .name = rootMenuName(leaf, translations), .mapping_name = null } },
        .mapped, .none => null,
    };
}

/// The path of the open menus as a line of names, the first level being the name of the module.
fn breadcrumb(buf: [:0]u8, source: fx_browser.Source, path: []const usize, translations: *TranslationStore) [:0]const u8 {
    var length: usize = 0;
    buf[0] = 0;
    var level: fx_browser.Level = .root;
    for (path) |index| {
        const text: [:0]const u8 = switch (level) {
            .root => if (fx_browser.rootMenuOf(source, index)) |menu| rootMenuName(menu, translations) else "",
            else => fx_browser.entryName(source, level, index) orelse "",
        };
        const written = std.fmt.bufPrint(buf[length .. buf.len - 1], "{s}{s}", .{ if (length > 0) "  >  " else "", text }) catch break;
        length += written.len;
        level = fx_browser.enter(source, level, index) orelse break;
    }
    buf[length] = 0;
    return buf[0..length :0];
}

/// What the rows of a card need: where the levels come from, and the cursor, which the rows report their clicks to.
const ListContext = struct {
    source: fx_browser.Source,
    level: fx_browser.Level,
    mappings: MappingsModuleMap,
    strings: *const StringPool,
    translations: *TranslationStore,
    /// The row that the cursor of the controller is on, when the window has one.
    cursor: ?usize,
    scroll_changed: ?*bool,
    /// What the user chose with the mouse.
    rv: ?fx_sel_actions.FxSelActions = null,
};

/// The rows of the plugins that have a mapping, which are the first rows of the first level.
fn drawMappedRows(ctx: imgui.ContextPtr, list: *ListContext) !void {
    var iterator = list.mappings.iterator();
    var i: usize = 0;
    while (iterator.next()) |entry| : (i += 1) {
        const fx_offset = entry.key_ptr.*;
        const fx_name = list.strings.get(fx_offset);
        if (try card_kit.row(ctx, @as([:0]const u8, @ptrCast(fx_name)), false, list.cursor == i, list.scroll_changed)) {
            const mapping_offsets = entry.value_ptr.*;
            if (mapping_offsets.items.len == 1) {
                const mapping_name = list.strings.get(mapping_offsets.items[0].name_offset);
                list.rv = .{ .plugin = .{ .name = fx_name, .mapping_name = mapping_name } };
            } else {
                list.rv = .{ .select_fx = fx_offset };
            }
        }
    }
}

/// The menus of the first level, which come after the plugins that have a mapping.
fn drawMenuRows(ctx: imgui.ContextPtr, list: *ListContext) !void {
    for (std.enums.values(fx_browser.RootMenu)) |menu| {
        const index = list.source.mapped_count + @backingInt(menu);
        const is_menu = fx_browser.isMenu(list.source, list.level, index);
        if (try card_kit.row(ctx, rootMenuName(menu, list.translations), is_menu, list.cursor == index, list.scroll_changed)) {
            list.rv = clickAction(list.source, list.level, index, list.translations);
        }
    }
}

/// The rows of a level under the first one.
fn drawLevelRows(ctx: imgui.ContextPtr, list: *ListContext) !void {
    switch (list.level) {
        .root => {},
        .fx_list => |plugins| {
            // Because a list of plugins can have thousands of them, its rows are walked once and not looked up one by one.
            var index: usize = 0;
            for (plugins.keys()) |plugin_name| {
                if (!fx_browser.isListed(plugin_name)) continue;
                if (try card_kit.row(ctx, @as([:0]const u8, @ptrCast(plugin_name)), false, list.cursor == index, list.scroll_changed)) {
                    list.rv = clickAction(list.source, list.level, index, list.translations);
                }
                index += 1;
            }
        },
        else => {
            const menus_end = fx_browser.leafStart(list.level);
            const count = fx_browser.entryCount(list.source, list.level);
            var index: usize = 0;
            while (index < count) : (index += 1) {
                const label = fx_browser.entryName(list.source, list.level, index) orelse continue;
                if (try card_kit.row(ctx, label, index < menus_end, list.cursor == index, list.scroll_changed)) {
                    list.rv = clickAction(list.source, list.level, index, list.translations);
                }
            }
        },
    }
}

/// The rows of the mappings of one plugin.
fn drawMappingRows(ctx: imgui.ContextPtr, list: *ListContext, sel: @FieldType(FxSelSubMode, "select_mapping")) !void {
    const mapping_entries = list.mappings.get(sel.fx_string_pool_offset) orelse return;
    for (mapping_entries.items, 0..) |map_entry, i| {
        const mapping_name = list.strings.get(map_entry.name_offset);
        if (try card_kit.row(ctx, @as([:0]const u8, @ptrCast(mapping_name)), false, list.cursor == i, list.scroll_changed)) {
            list.rv = .{ .plugin = .{ .name = sel.fx_name, .mapping_name = mapping_name } };
        }
    }
}

pub fn ModulePopup(
    ctx: imgui.ContextPtr,
    module: @import("statemachine.zig").ModulesList,
    mappings: MappingsModuleMap,
    strings: *const StringPool,
    sub_mode: FxSelSubMode,
    display_menus: bool,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
    ui: *UiState,
    highlight: ?*HighlightConfig,
) !?fx_sel_actions.FxSelActions {
    _ = style_manager;
    var rv: ?fx_sel_actions.FxSelActions = null;

    // Because the window has the look of the panel, it pushes the colors and the styles of the hardware theme, which has
    // the amber that the lit parts of the panel have where the theme of REAPER has its own accent.
    panel_theme.push(ctx);
    defer panel_theme.pop(ctx);

    try imgui.SetNextWindowSize(.{ ctx, 460, 480, imgui.Cond_FirstUseEver });

    var open = true;

    if (try imgui.Begin(.{ ctx, tr(translations, .fx_sel_title), &open })) {
        defer imgui.End(.{ctx}) catch {};
        try drawScrews(ctx);

        const source = browserSource(ui, mappings.count());
        // The menus only exist in the browser of the main window, which is also the only one with a path.
        const path: []const usize = if (display_menus) ui.state.fx_sel.path() else &.{};
        const level = fx_browser.levelAt(source, path) orelse .root;
        const inside_menu = path.len > 0;

        // The key that leaves a menu, or the mappings of a plugin, is an arrow at the top.
        const can_leave = inside_menu or sub_mode == .select_mapping;
        if (can_leave) {
            if (try imgui.ArrowButton(.{ ctx, "##fx_back", imgui.Dir_Left })) rv = .back;
            try imgui.SameLine(.{ctx});
        }
        try card_kit.drawEngraved(ctx, @tagName(module));
        var crumb_buf: [512:0]u8 = undefined;
        const subtitle: [:0]const u8 = switch (sub_mode) {
            .browse_fx => breadcrumb(&crumb_buf, source, path, translations),
            .select_mapping => |sel| sel.fx_name,
        };
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, panel_theme.text_dim });
        try imgui.Text(.{ ctx, if (subtitle.len > 0) subtitle else " " });
        try imgui.PopStyleColor(.{ ctx, 1 });

        var list: ListContext = .{
            .source = source,
            .level = level,
            .mappings = mappings,
            .strings = strings,
            .translations = translations,
            .cursor = if (highlight) |hl| hl.current_index else null,
            .scroll_changed = if (highlight) |hl| hl.scroll_changed else null,
        };

        // What the cards can share: the height under the header, less the line under the cards where the place of the
        // cursor is written.
        var available_w: f64 = undefined;
        var available_h: f64 = undefined;
        try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
        const footer_height = 24.0;
        const overhead = try card_kit.cardOverhead(ctx);
        const row_height = try imgui.GetTextLineHeightWithSpacing(.{ctx});
        const room = @max(available_h - footer_height, 120);

        var entry_count: usize = 0;
        var cursor_index: usize = 0;
        switch (sub_mode) {
            .browse_fx => {
                entry_count = fx_browser.entryCount(source, level);
                cursor_index = list.cursor orelse 0;
                switch (level) {
                    .root => if (display_menus) {
                        // The plugins that have a mapping are in one card, and the menus of the browser in another.
                        const menus_height = row_height * @as(f64, @floatFromInt(fx_browser.root_menu_count)) + 4;
                        const mapped_height = @max(room - menus_height - overhead * 2, row_height * 3);

                        const mapped_card = try card_kit.beginCard(ctx, "##fx_card_mapped", "Mapped plugins", mapped_height);
                        if (mapped_card.visible) try drawMappedRows(ctx, &list);
                        try card_kit.endCard(ctx, mapped_card.plate);

                        const menus_card = try card_kit.beginCard(ctx, "##fx_card_menus", "Browse", menus_height);
                        if (menus_card.visible) try drawMenuRows(ctx, &list);
                        try card_kit.endCard(ctx, menus_card.plate);
                    } else {
                        const card = try card_kit.beginCard(ctx, "##fx_card_mapped", "Mapped plugins", @max(room - overhead, row_height * 3));
                        if (card.visible) try drawMappedRows(ctx, &list);
                        try card_kit.endCard(ctx, card.plate);
                    },
                    else => {
                        // A menu that is open has a card of its own, labelled with its name.
                        var title_buf: [128:0]u8 = undefined;
                        const title: [:0]const u8 = if (path.len > 0) lastName(&title_buf, source, path, translations) else "Plugins";
                        const card = try card_kit.beginCard(ctx, "##fx_card_level", title, @max(room - overhead, row_height * 3));
                        if (card.visible) try drawLevelRows(ctx, &list);
                        try card_kit.endCard(ctx, card.plate);
                    },
                }
            },
            .select_mapping => |sel| {
                if (mappings.get(sel.fx_string_pool_offset)) |mapping_entries| entry_count = mapping_entries.items.len;
                cursor_index = sel.scroll_position_rel;
                list.cursor = if (highlight) |hl| hl.current_index else null;
                const card = try card_kit.beginCard(ctx, "##fx_card_mappings", "Mappings", @max(room - overhead, row_height * 3));
                if (card.visible) try drawMappingRows(ctx, &list, sel);
                try card_kit.endCard(ctx, card.plate);
            },
        }
        if (list.rv) |chosen| rv = chosen;

        // Under the cards: the place of the cursor in the list.
        var count_buf: [48:0]u8 = undefined;
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, panel_theme.text_dim });
        try imgui.Text(.{ ctx, safePrint(&count_buf, "{d} / {d}", .{ if (entry_count == 0) 0 else cursor_index + 1, entry_count }) });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    if (!open) rv = .close_browser;

    return rv;
}

/// The name of the menu that is open, which is the last entry of the path.
fn lastName(buf: [:0]u8, source: fx_browser.Source, path: []const usize, translations: *TranslationStore) [:0]const u8 {
    var level: fx_browser.Level = .root;
    var text: [:0]const u8 = "";
    for (path) |index| {
        text = switch (level) {
            .root => if (fx_browser.rootMenuOf(source, index)) |menu| rootMenuName(menu, translations) else "",
            else => fx_browser.entryName(source, level, index) orelse "",
        };
        level = fx_browser.enter(source, level, index) orelse break;
    }
    const length = @min(text.len, buf.len - 1);
    @memcpy(buf[0..length], text[0..length]);
    buf[length] = 0;
    return buf[0..length :0];
}
