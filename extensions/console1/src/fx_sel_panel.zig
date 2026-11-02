const std = @import("std");
const imgui = @import("reaper_imgui");
const fx_types = @import("fx_parser_types");
const styles = @import("styles.zig");
const fx_sel_actions = @import("action_types.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const tr = @import("translations.zig").tr;
const ui_helpers = @import("ui_helpers.zig");
const safePrint = @import("utils").safePrint;
const UiState = @import("ui_state.zig").UiState;
const FxSelSubMode = @import("statemachine.zig").FxSelSubMode;
const FxSelectionState = @import("statemachine.zig").FxSelectionState;
const StringPool = @import("string_pool").StringPool;
const MappingsModuleMap = @import("mappings_list.zig").ModuleMap;
const fx_browser = @import("fx_browser.zig");
const fuzzy = @import("fuzzy");
const c1_theme = @import("theme/c1_theme.zig");
const panel_theme = @import("panel_theme");
const card_kit = @import("components/panel_card.zig");

pub const NAME: [:0]const u8 = "Fx Browser";

/// What was typed in the search of the browser. It is kept in this library, as it is only read here, so that it does not
/// depend on the layout of the state that the host shares.
var search_buffer: [96:0]u8 = std.mem.zeroes([96:0]u8);
/// The result of the search that the keys are on, which Enter inserts, and what the text was when it was set.
var search_cursor: usize = 0;
var search_text_hash: u64 = 0;
/// The list has to scroll to the cursor, which is so after a key moved it.
var search_scroll = false;

/// Whether the search had the keyboard on the frame before: Escape deactivates the field in the frame that it is pressed in, so it is
/// the frame before that says whether the key was meant for the field.
var search_was_active = false;

/// The text of the search, for the tests.
pub fn testSearchBuffer() *[96:0]u8 {
    return &search_buffer;
}

/// When the browser was drawn last, and for which module.
var search_last_ms: u64 = 0;
var search_last_module: ?@import("statemachine.zig").ModulesList = null;

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
        // Because the browser that was opened from a mapping only chooses a plugin that can be mapped, it has no FX chains, no
        // track templates and no container.
        .hidden_menus = if (ui.state.fx_sel.return_to_mapping) fx_browser.plugins_only_hidden else .{},
        .recent = ui.fx_recent,
    };
}

/// The names of the menus of the first level, in the order of `fx_browser.RootMenu`.
fn rootMenuName(menu: fx_browser.RootMenu, translations: *TranslationStore) [:0]const u8 {
    return switch (menu) {
        .fx_chains => tr(translations, .fx_sel_fx_chains),
        .track_templates => tr(translations, .fx_sel_track_templates),
        .all_plugins => tr(translations, .fx_sel_all_plugins),
        .tags_category => tr(translations, .fx_sel_tags_category),
        .tags_developer => tr(translations, .fx_sel_tags_developer),
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
    /// Whether shift is held, which lights the label of the alternative use of a row in the accent color.
    shift_held: bool = false,
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
    var listed: usize = 0;
    for (std.enums.values(fx_browser.RootMenu)) |menu| {
        if (list.source.hidden_menus.contains(menu)) continue;
        const index = list.source.mapped_count + listed;
        listed += 1;
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

/// The rows of the mappings of one plugin. Each row has a "set as default" button over its right edge, in the accent color, which
/// makes the map the one that the plugin starts from, and the button of the default map is drawn active. Because the controller
/// reaches the button with shift, the accent is lit while shift is held.
fn drawMappingRows(ctx: imgui.ContextPtr, list: *ListContext, sel: @FieldType(FxSelSubMode, "select_mapping")) !void {
    const mapping_entries = list.mappings.get(sel.fx_string_pool_offset) orelse return;
    const default_label = tr(list.translations, .fx_sel_default_map);
    const accent = ui_helpers.altColor(list.shift_held);
    for (mapping_entries.items, 0..) |map_entry, i| {
        const mapping_name = list.strings.get(map_entry.name_offset);
        const is_default = if (sel.default_map) |default_name| std.mem.eql(u8, default_name, mapping_name) else false;
        switch (try card_kit.rowWithTag(ctx, @as([:0]const u8, @ptrCast(mapping_name)), default_label, accent, is_default, list.cursor == i, list.scroll_changed)) {
            .none => {},
            .row => list.rv = .{ .plugin = .{ .name = sel.fx_name, .mapping_name = mapping_name } },
            .tag => list.rv = .{ .set_default_map = .{ .name = sel.fx_name, .mapping_name = mapping_name } },
        }
    }
}

/// What the keys of the computer do in the maps of a plugin: the arrows move the cursor by one row, and Enter chooses the map that
/// it is on. Escape steps back, and is read where the search would be.
fn mappingKeyAction(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_DownArrow })) return .{ .scroll_by = 1 };
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_UpArrow })) return .{ .scroll_by = -1 };
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Enter }) or try imgui.IsKeyPressed(.{ ctx, imgui.Key_KeypadEnter })) return .confirm;
    return null;
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
        try card_kit.drawEngraved(ctx, ui_helpers.moduleName(translations, module));

        // The search is next to the name of the window. Only the main browser has it, because the choice of the default plugin
        // of a module is among the plugins that have a mapping, and a search among all of them would not be one of those.
        // Escape closes the browser, unless the search has the keyboard: then it only clears what was typed, and the next Escape closes.
        var escape_closes = false;
        const search_text: []const u8 = blk: {
            if (!display_menus) break :blk "";
            // Because a browser that was not drawn for a moment, or that is for another module, has just been opened, the search
            // starts empty and has the keyboard, so that what is typed goes in it right away.
            const now = ui.state.fx_ctrl.now_ms;
            const just_opened = now -| search_last_ms > 400 or search_last_module != module;
            search_last_ms = now;
            search_last_module = module;
            if (just_opened) search_buffer[0] = 0;
            if (sub_mode != .browse_fx) {
                // Inside the mappings of a plugin, Escape steps back, as the cancel of the controller does.
                if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Escape })) rv = .back;
                break :blk "";
            }

            try imgui.SameLine(.{ctx});
            const had_text = search_buffer[0] != 0;
            if (just_opened) try imgui.SetKeyboardFocusHere(.{ctx});
            try imgui.SetNextItemWidth(.{ ctx, 220 });
            // Because the text is only written back to the buffer when the field says that it changed, the field has no flag that makes it
            // say so only on Enter: the results follow each letter, and Enter is read from the keyboard.
            _ = try imgui.InputText(.{ ctx, "##fx_search", @as([*]u8, @ptrCast(&search_buffer)), search_buffer.len, null, null });
            const active = try imgui.IsItemActive(.{ctx});
            // The hint is written in the empty field, in the dim of the panel.
            if (search_buffer[0] == 0 and !active) {
                var x1: f64 = undefined;
                var y1: f64 = undefined;
                var x2: f64 = undefined;
                var y2: f64 = undefined;
                try imgui.GetItemRectMin(.{ ctx, &x1, &y1 });
                try imgui.GetItemRectMax(.{ ctx, &x2, &y2 });
                const hint = tr(translations, .fx_sel_search);
                var hint_w: f64 = undefined;
                var hint_h: f64 = undefined;
                try imgui.CalcTextSize(.{ ctx, hint, &hint_w, &hint_h });
                const dl = try imgui.GetWindowDrawList(.{ctx});
                try imgui.DrawList_AddText(.{ dl, x1 + 8, (y1 + y2) / 2 - hint_h / 2, panel_theme.text_dim, hint });
            }
            if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Escape })) {
                // The field had the keyboard when the key was pressed, and had text: Escape clears it, and the menus are back.
                if (had_text and (active or search_was_active)) search_buffer[0] = 0 else escape_closes = true;
            }
            search_was_active = active;
            break :blk std.mem.trim(u8, std.mem.sliceTo(&search_buffer, 0), " \t");
        };
        const searching = search_text.len > 0;
        var crumb_buf: [512:0]u8 = undefined;
        const subtitle: [:0]const u8 = switch (sub_mode) {
            .browse_fx => breadcrumb(&crumb_buf, source, path, translations),
            .select_mapping => |sel| sel.fx_name,
        };
        // Because a line with nothing in it would leave a gap over the first card, the subtitle is only there when it has a text.
        if (subtitle.len > 0) {
            try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, panel_theme.text_dim });
            try imgui.Text(.{ ctx, subtitle });
            try imgui.PopStyleColor(.{ ctx, 1 });
        }

        var list: ListContext = .{
            .source = source,
            .level = level,
            .mappings = mappings,
            .strings = strings,
            .translations = translations,
            .cursor = if (highlight) |hl| hl.current_index else null,
            .scroll_changed = if (highlight) |hl| hl.scroll_changed else null,
            .shift_held = ui.shift_held,
        };

        // What the cards can share: the height under the header, less the line under the cards where the place of the
        // cursor is written.
        var available_w: f64 = undefined;
        var available_h: f64 = undefined;
        try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
        const overhead = try card_kit.cardOverhead(ctx);
        const row_height = try imgui.GetTextLineHeightWithSpacing(.{ctx});
        const room = @max(available_h, 120);

        if (searching) {
            // While there is a search, it takes the place of the cards: the plugins of every type that match it, the best first. The
            // first one is the one that Enter inserts.
            var hits: [fx_browser.search_capacity]fuzzy.Ranked = undefined;
            const count = fx_browser.search(source, search_text, &hits);

            // The cursor starts on the best result each time that the text changes, and the keys move it: the arrows by one result,
            // and the page keys by a page of them. Enter inserts the plugin that it is on.
            const hash = std.hash.Wyhash.hash(0, search_text);
            if (hash != search_text_hash) {
                search_text_hash = hash;
                search_cursor = 0;
                search_scroll = true;
            }
            const page: usize = @max(1, @as(usize, @intFromFloat(@max(room - overhead, 0) / @max(row_height, 1))) -| 1);
            if (count > 0) {
                if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_DownArrow })) {
                    search_cursor = @min(search_cursor + 1, count - 1);
                    search_scroll = true;
                }
                if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_UpArrow })) {
                    search_cursor -|= 1;
                    search_scroll = true;
                }
                if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_PageDown })) {
                    search_cursor = @min(search_cursor + page, count - 1);
                    search_scroll = true;
                }
                if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_PageUp })) {
                    search_cursor -|= page;
                    search_scroll = true;
                }
            }
            search_cursor = @min(search_cursor, count -| 1);

            const card = try card_kit.beginCard(ctx, "##fx_card_search", tr(translations, .fx_sel_results), @max(room - overhead, row_height * 3));
            if (card.visible) {
                for (hits[0..count], 0..) |hit, i| {
                    const name = fx_browser.pluginAt(source, hit.index) orelse continue;
                    if (try card_kit.row(ctx, name, false, i == search_cursor, &search_scroll)) list.rv = .{ .plugin = .{ .name = name, .mapping_name = null } };
                }
            }
            try card_kit.endCard(ctx, card.plate);
            const enter = try imgui.IsKeyPressed(.{ ctx, imgui.Key_Enter }) or try imgui.IsKeyPressed(.{ ctx, imgui.Key_KeypadEnter });
            if (enter and count > 0) {
                if (fx_browser.pluginAt(source, hits[search_cursor].index)) |name| list.rv = .{ .plugin = .{ .name = name, .mapping_name = null } };
            }
        } else switch (sub_mode) {
            .browse_fx => {
                switch (level) {
                    .root => if (display_menus) {
                        // The plugins that have a mapping are in one card, and the menus of the browser in another.
                        const menus_height = row_height * @as(f64, @floatFromInt(fx_browser.rootMenuCount(source))) + 4;
                        const mapped_height = @max(room - menus_height - overhead * 2, row_height * 3);

                        const mapped_card = try card_kit.beginCard(ctx, "##fx_card_mapped", tr(translations, .fx_sel_mapped_plugins), mapped_height);
                        if (mapped_card.visible) try drawMappedRows(ctx, &list);
                        try card_kit.endCard(ctx, mapped_card.plate);

                        const menus_card = try card_kit.beginCard(ctx, "##fx_card_menus", tr(translations, .fx_sel_browse), menus_height);
                        if (menus_card.visible) try drawMenuRows(ctx, &list);
                        try card_kit.endCard(ctx, menus_card.plate);
                    } else {
                        const card = try card_kit.beginCard(ctx, "##fx_card_mapped", tr(translations, .fx_sel_mapped_plugins), @max(room - overhead, row_height * 3));
                        if (card.visible) try drawMappedRows(ctx, &list);
                        try card_kit.endCard(ctx, card.plate);
                    },
                    else => {
                        // A menu that is open has a card of its own, labelled with its name.
                        var title_buf: [128:0]u8 = undefined;
                        const title: [:0]const u8 = if (path.len > 0) lastName(&title_buf, source, path, translations) else tr(translations, .fx_sel_plugins);
                        const card = try card_kit.beginCard(ctx, "##fx_card_level", title, @max(room - overhead, row_height * 3));
                        if (card.visible) try drawLevelRows(ctx, &list);
                        try card_kit.endCard(ctx, card.plate);
                    },
                }
            },
            .select_mapping => |sel| {
                list.cursor = if (highlight) |hl| hl.current_index else null;
                const card = try card_kit.beginCard(ctx, "##fx_card_mappings", tr(translations, .fx_sel_mappings), @max(room - overhead, row_height * 3));
                if (card.visible) try drawMappingRows(ctx, &list, sel);
                try card_kit.endCard(ctx, card.plate);
                // Because the cursor of the maps is kept in the state, the keys of the computer ask the state to move it or to
                // confirm it, as the controller does. A click on a row, which is already in the result, has the priority.
                if (list.rv == null) list.rv = try mappingKeyAction(ctx);
            },
        }
        if (escape_closes) rv = .close_browser;
        if (list.rv) |chosen| rv = chosen;
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
