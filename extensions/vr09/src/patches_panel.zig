//! The Scenes and Patches tabs, ported from the design lab's `panel.lua`.
//!
//! The Scenes tab has the library of patches: one table that holds the keyboard's registrations, its single
//! tones and the player's own presets, with a search, a type and a group filter, and sorting by a column. A
//! double click on a row sends it to the keyboard, and the Add button puts it at the end of the session's
//! scenes. Beside it is the list of the session's scenes. The Patches tab has the keyboard's read and write
//! buttons and the options.
//!
//! Because a performer picks a sound by name, the registrations and the single tones share one table. The last
//! column is the value of the plugin's Patch parameter that would select the row, and a value never changes
//! once given: the registrations take 1 to 100, the tones take 101 and up in the order of `tones.zig`, which
//! only grows at its end, and the presets take an ID that comes from their name.
const std = @import("std");
const imgui = @import("reaper_imgui");
const plugin = @import("plugin.zig");
const library = @import("library.zig");
const types = @import("action_types.zig");
const fuzzy = @import("fuzzy");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");

const Plugin = plugin.Plugin;
const Row = library.Row;
const nameOf = library.nameOf;
const groupOf = library.groupOf;
const numberOf = library.numberOf;
const typeOf = library.typeOf;

const group_cap = library.group_cap;
const search_cap = 64;
const rows_cap = library.rows_cap;

const all_groups = "All groups";
const type_names = [_][:0]const u8{ "All", "Registration", "Tone", "Preset" };

/// What the library keeps between frames.
pub const State = struct {
    search: [search_cap:0]u8 = [_:0]u8{0} ** search_cap,
    /// The chosen entry of `type_names`.
    type_index: usize = 0,
    group: [group_cap:0]u8 = initialGroup(),
    /// The hash of the key of the selected row, or 0.
    selected: u64 = 0,
    /// The column the player clicked last, counted from 0, or -1 for the table's own order.
    sort_column: i32 = -1,
    sort_descending: bool = false,
    /// The hash of the key of the preset whose deletion is armed, or 0.
    delete_armed: u64 = 0,
    /// The rows of the table, which are rebuilt when the registrations or the presets have changed. They take
    /// about 120 KB, so they are allocated when the table is first drawn, and freed when the panel closes.
    library: ?*library.Library = null,
    /// The rows of the library that the filters let through, in the order they are shown, as positions in
    /// the library's rows.
    shown: [rows_cap]u32 = undefined,
    shown_count: usize = 0,
};

/// The rows of the table, allocated the first time. Null when there is no memory for them.
fn libraryOf(w: *State) ?*library.Library {
    if (w.library == null) {
        const rows = plugin.allocator.create(library.Library) catch return null;
        rows.* = .{};
        w.library = rows;
    }
    return w.library;
}

/// Frees what the panel holds. The window calls it when it closes.
pub fn free(w: *State) void {
    if (w.library) |rows| plugin.allocator.destroy(rows);
    w.library = null;
}

fn copyName(dest: *[group_cap:0]u8, text: []const u8) void {
    const n = @min(text.len, group_cap);
    @memcpy(dest[0..n], text[0..n]);
    dest[n] = 0;
}

fn initialGroup() [group_cap:0]u8 {
    var group = [_:0]u8{0} ** group_cap;
    @memcpy(group[0..all_groups.len], all_groups);
    return group;
}

// ---- the filters, the search and the sort ----

/// Whether the type and the group filters let a row through. The search text is not part of it: it ranks the
/// rows that remain.
fn matchesFilters(w: *const State, row: *const Row) bool {
    if (w.type_index != 0 and row.kind != @as(library.Kind, @enumFromInt(w.type_index - 1))) return false;
    const group = std.mem.sliceTo(&w.group, 0);
    if (!std.mem.eql(u8, group, all_groups) and !std.mem.eql(u8, groupOf(row), group)) return false;
    return true;
}

const Ranked = struct { index: u32, score: i32, len: u32 };

fn rankedBefore(_: void, a: Ranked, b: Ranked) bool {
    return fuzzy.rankedBefore(.{ .index = a.index, .score = a.score, .len = a.len }, .{ .index = b.index, .score = b.score, .len = b.len });
}

/// What the search is matched against: the name first, then the group, the number and the type.
fn searchText(buf: []u8, row: *const Row) []const u8 {
    return std.fmt.bufPrint(buf, "{s} {s} {s} {s}", .{ nameOf(row), groupOf(row), numberOf(row), typeOf(row) }) catch "";
}

const SortContext = struct { column: i32, rows: *const [rows_cap]Row };

/// The text that a row is ordered by when the table is sorted by a column. Because names and groups are
/// compared in lower case, capitals do not sort apart from small letters. The patch ID is not part of the
/// text; it only breaks ties.
fn sortText(row: *const Row, column: i32) []const u8 {
    return switch (column) {
        0 => typeOf(row),
        2 => nameOf(row),
        3 => groupOf(row),
        else => "",
    };
}

fn sortLess(context: SortContext, a: u32, b: u32) bool {
    const left = &context.rows[a];
    const right = &context.rows[b];
    const ta = sortText(left, context.column);
    const tb = sortText(right, context.column);
    if (!std.ascii.eqlIgnoreCase(ta, tb)) return std.ascii.lessThanIgnoreCase(ta, tb);
    return left.value < right.value;
}

/// The rows that the filters let through. A search ranks them by how well they match, best first.
fn buildShown(w: *State, lib: *const library.Library) void {
    w.shown_count = 0;
    for (lib.rows[0..lib.count], 0..) |*row, i| {
        if (matchesFilters(w, row)) {
            w.shown[w.shown_count] = @intCast(i);
            w.shown_count += 1;
        }
    }
    const query = std.mem.sliceTo(&w.search, 0);
    if (query.len == 0) return;
    var ranked: [rows_cap]Ranked = undefined;
    var count: usize = 0;
    var text_buf: [160]u8 = undefined;
    for (w.shown[0..w.shown_count]) |index| {
        const text = searchText(&text_buf, &lib.rows[index]);
        if (fuzzy.score(query, text)) |score| {
            ranked[count] = .{ .index = index, .score = score, .len = @intCast(text.len) };
            count += 1;
        }
    }
    std.mem.sort(Ranked, ranked[0..count], {}, rankedBefore);
    for (ranked[0..count], 0..) |entry, k| w.shown[k] = entry.index;
    w.shown_count = count;
}

// ---- the table ----

/// A small button, "Add" with an arrow pointing to the scenes. Because the font has no arrow, the arrow is
/// drawn as a triangle on the right of the button, in the room that trailing spaces leave.
fn addButton(ctx: imgui.ContextPtr, id: u64) bool {
    var label: [48:0]u8 = undefined;
    const clicked = imgui.api.SmallButton(ctx, std.fmt.bufPrintZ(&label, "Add    ##{x}", .{id}) catch "Add");
    var left: f64 = 0;
    var top: f64 = 0;
    imgui.api.GetItemRectMin(ctx, &left, &top);
    var right: f64 = 0;
    var bottom: f64 = 0;
    imgui.api.GetItemRectMax(ctx, &right, &bottom);
    const x = right - 10;
    const y = (top + bottom) / 2;
    imgui.api.DrawList_AddTriangleFilled(imgui.api.GetWindowDrawList(ctx), x - 3, y - 4, x - 3, y + 4, x + 3, y, theme.text);
    return clicked;
}

const sort_names = [_][]const u8{ "Type", "No.", "Name", "Group", "Patch ID" };

fn patchTable(p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.patches;
    var action: ?types.Action = null;
    // Because the theme's header color is nearly the table's own gray, the selected row takes the accent.
    imgui.api.PushStyleColor(ctx, imgui.Col_Header, widgets.faded(theme.amber, 0x70));
    // The table is drawn in the label font, which is bold, and it is pushed before the table begins so that
    // the rows take their height from it.
    const pushed = widgets.pushLabelFont(kit);
    var flags: c_int = imgui.TableFlags_RowBg | imgui.TableFlags_Borders | imgui.TableFlags_ScrollY | imgui.TableFlags_Sortable;
    var width: f64 = 700;
    var height: f64 = 360;
    if (imgui.api.BeginTable(ctx, "##patchtable", 6, &flags, &width, &height, null)) {
        imgui.api.TableSetupScrollFreeze(ctx, 0, 1);
        var fixed: c_int = imgui.TableColumnFlags_WidthFixed;
        var stretch: c_int = imgui.TableColumnFlags_WidthStretch;
        var fixed_no_sort: c_int = imgui.TableColumnFlags_WidthFixed | imgui.TableColumnFlags_NoSort;
        var w_type: f64 = 110;
        var w_number: f64 = 50;
        var w_group: f64 = 90;
        var w_id: f64 = 90;
        var w_scenes: f64 = 72;
        imgui.api.TableSetupColumn(ctx, "Type", &fixed, &w_type, null);
        imgui.api.TableSetupColumn(ctx, "No.", &fixed, &w_number, null);
        imgui.api.TableSetupColumn(ctx, "Name", &stretch, null, null);
        imgui.api.TableSetupColumn(ctx, "Group", &fixed, &w_group, null);
        imgui.api.TableSetupColumn(ctx, "Patch ID", &fixed, &w_id, null);
        imgui.api.TableSetupColumn(ctx, "Scenes", &fixed_no_sort, &w_scenes, null);
        imgui.api.TableHeadersRow(ctx);

        const rows = libraryOf(w) orelse {
            imgui.api.EndTable(ctx);
            imgui.api.TextColored(ctx, theme.red, "There is no memory for the table.");
            widgets.popFont(kit, pushed);
            var one: c_int = 1;
            imgui.api.PopStyleColor(ctx, &one);
            return null;
        };
        library.ensure(p, rows);
        buildShown(w, rows);
        // The first sort spec is the column the player clicked last. Because the table may report it only on
        // the frame of the click, and the rows are rebuilt each frame, the choice is kept in the state.
        var column: c_int = 0;
        var user_id: c_int = 0;
        var direction: c_int = 0;
        if (imgui.api.TableGetColumnSortSpecs(ctx, 0, &column, &user_id, &direction)) {
            w.sort_column = column;
            w.sort_descending = direction == imgui.SortDirection_Descending;
        }
        // While a search is typed, the rows stay in the order of their match.
        if (w.sort_column >= 0 and w.search[0] == 0) {
            std.mem.sort(u32, w.shown[0..w.shown_count], SortContext{ .column = w.sort_column, .rows = &rows.rows }, sortLess);
            if (w.sort_descending) std.mem.reverse(u32, w.shown[0..w.shown_count]);
        }
        for (w.shown[0..w.shown_count]) |index| {
            action = types.first(action, drawRow(p, ctx, &rows.rows[index]));
        }
        imgui.api.EndTable(ctx);
    }
    widgets.popFont(kit, pushed);
    var one: c_int = 1;
    imgui.api.PopStyleColor(ctx, &one);
    if (w.search[0] != 0) {
        imgui.api.TextColored(ctx, theme.grey, "Ranked by how well each patch matches the search. Clear the search to sort by a column.");
    } else if (w.sort_column >= 0) {
        var text: [96:0]u8 = undefined;
        imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&text, "Sorted by {s}, {s}.", .{ sort_names[@intCast(w.sort_column)], if (w.sort_descending) "descending" else "ascending" }) catch "");
    } else {
        imgui.api.TextColored(ctx, theme.grey, "In list order. Click a header to sort.");
    }
    return action;
}

fn drawRow(p: *Plugin, ctx: imgui.ContextPtr, row: *const Row) ?types.Action {
    const w = &p.ui.patches;
    var action: ?types.Action = null;
    imgui.api.TableNextRow(ctx, null, null);
    _ = imgui.api.TableNextColumn(ctx);
    // One click selects the row; a double click sends it to the keyboard.
    var label: [64:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(&label, "{s}##{x}", .{ typeOf(row), row.key }) catch "?";
    var selected = w.selected == row.key;
    var flags: c_int = imgui.SelectableFlags_SpanAllColumns | imgui.SelectableFlags_AllowOverlap | imgui.SelectableFlags_AllowDoubleClick;
    if (imgui.api.Selectable(ctx, text, &selected, &flags, null, null)) {
        w.selected = row.key;
        w.delete_armed = 0;
        if (imgui.api.IsMouseDoubleClicked(ctx, 0)) action = .{ .send_patch = library.patchOf(p, row) };
    }
    _ = imgui.api.TableNextColumn(ctx);
    imgui.api.Text(ctx, &row.number);
    _ = imgui.api.TableNextColumn(ctx);
    imgui.api.Text(ctx, &row.name);
    _ = imgui.api.TableNextColumn(ctx);
    imgui.api.TextColored(ctx, theme.grey, &row.group);
    _ = imgui.api.TableNextColumn(ctx);
    var value: [16:0]u8 = undefined;
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&value, "{d}", .{row.value}) catch "");
    _ = imgui.api.TableNextColumn(ctx);
    if (addButton(ctx, row.key)) action = .{ .add_scene = library.patchOf(p, row) };
    return action;
}

// ---- the library card ----

/// The groups of the table in the order that they first appear, after "All groups".
fn drawGroupCombo(ctx: imgui.ContextPtr, w: *State, lib: *const library.Library) void {
    var width: f64 = 140;
    imgui.api.SetNextItemWidth(ctx, width);
    width = 0;
    if (!imgui.api.BeginCombo(ctx, "##patchgroup", &w.group, null)) return;
    var seen: [32][group_cap:0]u8 = undefined;
    var seen_count: usize = 0;
    if (imgui.api.Selectable(ctx, all_groups, null, null, null, null)) w.group = initialGroup();
    for (lib.rows[0..lib.count]) |*row| {
        const group = groupOf(row);
        if (group.len == 0) continue;
        var known = false;
        for (seen[0..seen_count]) |*existing| {
            if (std.mem.eql(u8, std.mem.sliceTo(existing, 0), group)) known = true;
        }
        if (known or seen_count == seen.len) continue;
        copyName(&seen[seen_count], group);
        seen_count += 1;
        var selected = std.mem.eql(u8, std.mem.sliceTo(&w.group, 0), group);
        if (imgui.api.Selectable(ctx, &row.group, &selected, null, null, null)) copyName(&w.group, group);
    }
    imgui.api.EndCombo(ctx);
}

fn selectedPreset(p: *Plugin) ?[]u8 {
    const w = &p.ui.patches;
    const list = p.ui.preset_names orelse return null;
    for (list.items) |file_name| {
        if (std.hash.Wyhash.hash(0, file_name) == w.selected) return file_name;
    }
    return null;
}

fn saveRow(p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.patches;
    var action: ?types.Action = null;
    imgui.api.SetNextItemWidth(ctx, 280);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##savename", "name of the new patch", &p.ui.save_name, p.ui.save_name.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (p.ui.pending_save.phase != .idle) {
        imgui.api.TextColored(ctx, theme.amber, "Reading the keyboard...");
    } else if (widgets.pushButton(kit, "Save the keyboard as a patch", 0)) {
        action = .{ .save_keyboard = types.Text.of(std.mem.sliceTo(&p.ui.save_name, 0)) };
    }
    widgets.tooltip(kit, "Reads the keyboard, then saves what it holds as a preset under this name. The preset then appears in the table, where it can be sent to the keyboard or added to the scenes.");
    if (selectedPreset(p)) |file_name| {
        imgui.api.SameLine(ctx, null, null);
        const armed = w.delete_armed == w.selected;
        if (widgets.pushButton(kit, if (armed) "Click again to delete" else "Delete the selected preset", 0)) {
            if (armed) {
                action = .{ .delete_preset = types.Text.of(file_name) };
                w.selected = 0;
                w.delete_armed = 0;
            } else {
                w.delete_armed = w.selected;
            }
        }
    } else {
        w.delete_armed = 0;
    }
    return action;
}

/// The card of the library: the search, the filters, the table, and the row that saves the keyboard.
pub fn drawLibrary(p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.patches;
    if (!widgets.beginCard(kit, "Patches", null, null, null)) return null;
    defer widgets.endCard(kit);
    if (p.ui.reg_library == null) {
        imgui.api.TextColored(ctx, theme.grey, "No registrations folder: run build-install.sh vr09 to fill Data/Perken/vr09/registrations.");
    }
    imgui.api.SetNextItemWidth(ctx, 280);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##patchfilter", "search: name, group, number (letters in order)", &w.search, w.search.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    imgui.api.SetNextItemWidth(ctx, 140);
    if (imgui.api.BeginCombo(ctx, "##patchtype", type_names[w.type_index], null)) {
        for (type_names, 0..) |kind, i| {
            var selected = w.type_index == i;
            if (imgui.api.Selectable(ctx, kind, &selected, null, null, null)) w.type_index = i;
        }
        imgui.api.EndCombo(ctx);
    }
    imgui.api.SameLine(ctx, null, null);
    // The groups come from the rows of the last frame.
    if (w.library) |rows| drawGroupCombo(ctx, w, rows);
    const from_table = patchTable(p, ctx);
    return types.first(from_table, saveRow(p, ctx));
}

// ---- the Patches tab ----

/// The keyboard's read and write buttons, and the options.
pub fn drawPatches(p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const s = p.shared;
    var action: ?types.Action = null;
    if (widgets.beginCard(kit, "Keyboard", null, null, null)) {
        if (widgets.pushButton(kit, "Read the keyboard", 0)) action = .read_keyboard;
        if (widgets.pushButton(kit, "Send to the keyboard", 0)) action = .send_to_keyboard;
        widgets.tooltip(kit, "Only what differs is written: about 0.15 seconds when the keyboard has been read, a few seconds otherwise.");
        widgets.endCard(kit);
    }
    imgui.api.SameLine(ctx, null, null);
    if (widgets.beginCard(kit, "Options", null, null, null)) {
        var split_on = p.settings.split.load(.monotonic);
        if (widgets.toggle(kit, "This patch splits at middle C", &split_on)) action = .{ .set_split = split_on };
        widgets.tooltip(kit, "The keyboard cannot report its split. When this is on, the track's notes below middle C go to the Lower part (channel 3) and the others to the Upper part (channel 4); when off, every note goes to the Upper part. The setting is remembered for this patch.");
        var follow = s.follow_panel.load(.monotonic);
        if (widgets.toggle(kit, "Follow changes made on the keyboard's panel", &follow)) action = .{ .set_follow_panel = follow };
        var recall = s.recall_on_load.load(.monotonic);
        if (widgets.toggle(kit, "Send the patch to the keyboard when the project opens", &recall)) action = .{ .set_recall_on_load = recall };
        widgets.endCard(kit);
    }
    // The files card is the plugin's own: the lab has no import or export, but the plugin had them, and a
    // feature is not dropped without saying so.
    if (widgets.beginCard(kit, "Files", null, null, null)) {
        if (widgets.pushButton(kit, "Import a file", 0)) action = .import_file;
        widgets.tooltip(kit, "Loads a dump made by vr09.py, or a preset file from elsewhere.");
        imgui.api.SetNextItemWidth(ctx, 420);
        var input_flags: c_int = imgui.InputTextFlags_None;
        _ = imgui.api.InputTextWithHint(ctx, "##export", "path of the file to write (a dump, as vr09.py reads it)", &p.ui.export_path, p.ui.export_path.len, &input_flags, null);
        imgui.api.SameLine(ctx, null, null);
        if (widgets.pushButton(kit, "Export", 0)) action = .{ .export_file = types.Text.of(std.mem.sliceTo(&p.ui.export_path, 0)) };
        widgets.endCard(kit);
    }
    return action;
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
