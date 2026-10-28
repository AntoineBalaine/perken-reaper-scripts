//! The Scenes and Patches tabs, ported from the design lab's `panel.lua`.
//!
//! The Scenes tab has the library of patches: one table that holds the keyboard's registrations, its single
//! tones and the player's own presets, with a search, a type and a group filter, and sorting by a column. A
//! double click on a row sends it to the keyboard, and the Add button puts it at the end of the session's
//! scenes. Beside it is the list of the session's scenes. The Patches tab has the keyboard's read and write
//! buttons and the options.
//!
//! The rows are in `library.zig` and hold string IDs, not text: the table reads each name, group and number from
//! the plugin's strings when it draws the row. Because a patch is carried out after the frame, the actions that
//! the table returns carry the IDs of what they need.
const std = @import("std");
const imgui = @import("reaper_imgui");
const plugin = @import("plugin.zig");
const library = @import("library.zig");
const types = @import("action_types.zig");
const strings = @import("strings.zig");
const fuzzy = @import("fuzzy");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");

const Plugin = plugin.Plugin;
const Row = library.Row;
const Strings = strings.Strings;

const group_cap = 24;
const search_cap = 64;

const all_groups = "All groups";
const type_names = [_][:0]const u8{ "All", "Registration", "Tone", "Preset" };

const Ranked = struct { index: u32, score: i32, len: u32 };

/// What the library keeps between frames.
pub const State = struct {
    search: [search_cap:0]u8 = @splat(0),
    /// The chosen entry of `type_names`.
    type_index: usize = 0,
    group: [group_cap:0]u8 = initialGroup(),
    /// The value of the selected row, or 0.
    selected: u32 = 0,
    /// The column the player clicked last, counted from 0, or -1 for the table's own order.
    sort_column: i32 = -1,
    sort_descending: bool = false,
    /// The value of the preset whose deletion is armed, or 0.
    delete_armed: u32 = 0,
    /// The rows of the library that the filters let through, in the order they are shown, as positions in the
    /// library's rows. The list keeps its room from one frame to the next.
    shown: std.ArrayListUnmanaged(u32) = .empty,
    /// The scores of the rows that match a search.
    ranked: std.ArrayListUnmanaged(Ranked) = .empty,
};

/// Frees what the panel holds. The window calls it when it closes.
pub fn free(w: *State) void {
    w.shown.deinit(plugin.allocator);
    w.shown = .empty;
    w.ranked.deinit(plugin.allocator);
    w.ranked = .empty;
}

fn copyName(dest: *[group_cap:0]u8, text: []const u8) void {
    const n = @min(text.len, group_cap);
    @memcpy(dest[0..n], text[0..n]);
    dest[n] = 0;
}

fn initialGroup() [group_cap:0]u8 {
    var group: [group_cap:0]u8 = @splat(0);
    @memcpy(group[0..all_groups.len], all_groups);
    return group;
}

// ---- the filters, the search and the sort ----

/// Whether the type and the group filters let a row through. The search text is not part of it: it ranks the
/// rows that remain.
fn matchesFilters(w: *const State, pool: *const Strings, row: Row) bool {
    if (w.type_index != 0 and row.kind != @as(library.Kind, @fromBackingInt(@intCast(w.type_index - 1)))) return false;
    const group = std.mem.sliceTo(&w.group, 0);
    if (!std.mem.eql(u8, group, all_groups) and !std.mem.eql(u8, pool.get(row.group), group)) return false;
    return true;
}

fn rankedBefore(_: void, a: Ranked, b: Ranked) bool {
    return fuzzy.rankedBefore(.{ .index = a.index, .score = a.score, .len = a.len }, .{ .index = b.index, .score = b.score, .len = b.len });
}

/// What the search is matched against: the name first, then the group, the number and the type.
fn searchText(buf: []u8, pool: *const Strings, row: Row) []const u8 {
    return std.fmt.bufPrint(buf, "{s} {s} {s} {s}", .{ pool.get(row.name), pool.get(row.group), pool.get(row.number), library.typeName(row) }) catch "";
}

const SortContext = struct { column: i32, rows: []const Row, pool: *const Strings };

/// The text that a row is ordered by when the table is sorted by a column. Because names and groups are
/// compared in lower case, capitals do not sort apart from small letters. The patch ID is not part of the text;
/// it only breaks ties.
fn sortText(context: SortContext, row: Row) []const u8 {
    return switch (context.column) {
        0 => library.typeName(row),
        2 => context.pool.get(row.name),
        3 => context.pool.get(row.group),
        else => "",
    };
}

fn sortLess(context: SortContext, a: u32, b: u32) bool {
    const left = context.rows[a];
    const right = context.rows[b];
    const ta = sortText(context, left);
    const tb = sortText(context, right);
    if (!std.ascii.eqlIgnoreCase(ta, tb)) return std.ascii.lessThanIgnoreCase(ta, tb);
    return left.value < right.value;
}

/// The rows that the filters let through. A search ranks them by how well they match, best first.
fn buildShown(w: *State, pool: *const Strings, rows: []const Row) void {
    const allocator = plugin.allocator;
    w.shown.clearRetainingCapacity();
    for (rows, 0..) |row, i| {
        if (matchesFilters(w, pool, row)) w.shown.append(allocator, @intCast(i)) catch return;
    }
    const query = std.mem.sliceTo(&w.search, 0);
    if (query.len == 0) return;
    w.ranked.clearRetainingCapacity();
    var text_buf: [160]u8 = undefined;
    for (w.shown.items) |index| {
        const text = searchText(&text_buf, pool, rows[index]);
        if (fuzzy.score(query, text)) |score| {
            w.ranked.append(allocator, .{ .index = index, .score = score, .len = @intCast(text.len) }) catch return;
        }
    }
    std.mem.sort(Ranked, w.ranked.items, {}, rankedBefore);
    w.shown.clearRetainingCapacity();
    for (w.ranked.items) |entry| w.shown.append(allocator, entry.index) catch return;
}

// ---- the table ----

/// A small button, "Add" with an arrow pointing to the scenes. Because the font has no arrow, the arrow is
/// drawn as a triangle on the right of the button, in the room that trailing spaces leave.
fn addButton(ctx: imgui.ContextPtr, id: u32) bool {
    var label: [48:0]u8 = undefined;
    const clicked = imgui.api.SmallButton(ctx, std.mem.printSentinel(&label, "Add    ##{x}", .{id}, 0) catch "Add");
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

fn patchTable(io: std.Io, p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
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

        const rows = library.rows(io, p);
        buildShown(w, &p.strings, rows);
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
            const context = SortContext{ .column = w.sort_column, .rows = rows, .pool = &p.strings };
            std.mem.sort(u32, w.shown.items, context, sortLess);
            if (w.sort_descending) std.mem.reverse(u32, w.shown.items);
        }
        for (w.shown.items) |index| {
            action = types.first(action, drawRow(p, ctx, rows[index]));
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
        imgui.api.TextColored(ctx, theme.grey, std.mem.printSentinel(&text, "Sorted by {s}, {s}.", .{ sort_names[@intCast(w.sort_column)], if (w.sort_descending) "descending" else "ascending" }, 0) catch "");
    } else {
        imgui.api.TextColored(ctx, theme.grey, "In list order. Click a header to sort.");
    }
    return action;
}

fn drawRow(p: *Plugin, ctx: imgui.ContextPtr, row: Row) ?types.Action {
    const w = &p.ui.patches;
    var action: ?types.Action = null;
    imgui.api.TableNextRow(ctx, null, null);
    _ = imgui.api.TableNextColumn(ctx);
    // One click selects the row; a double click sends it to the keyboard.
    var label: [64:0]u8 = undefined;
    const text = std.mem.printSentinel(&label, "{s}##{x}", .{ library.typeName(row), row.value }, 0) catch "?";
    var selected = w.selected == row.value;
    var flags: c_int = imgui.SelectableFlags_SpanAllColumns | imgui.SelectableFlags_AllowOverlap | imgui.SelectableFlags_AllowDoubleClick;
    if (imgui.api.Selectable(ctx, text, &selected, &flags, null, null)) {
        w.selected = row.value;
        w.delete_armed = 0;
        if (imgui.api.IsMouseDoubleClicked(ctx, 0)) action = .{ .send_patch = library.patchOf(p, row) };
    }
    _ = imgui.api.TableNextColumn(ctx);
    imgui.api.Text(ctx, p.strings.get(row.number));
    _ = imgui.api.TableNextColumn(ctx);
    imgui.api.Text(ctx, p.strings.get(row.name));
    _ = imgui.api.TableNextColumn(ctx);
    imgui.api.TextColored(ctx, theme.grey, p.strings.get(row.group));
    _ = imgui.api.TableNextColumn(ctx);
    var value: [16:0]u8 = undefined;
    imgui.api.Text(ctx, std.mem.printSentinel(&value, "{d}", .{row.value}, 0) catch "");
    _ = imgui.api.TableNextColumn(ctx);
    if (addButton(ctx, row.value)) action = .{ .add_scene = library.patchOf(p, row) };
    return action;
}

// ---- the library card ----

/// The groups of the table in the order that they first appear, after "All groups". Because a text is stored
/// once in the strings, two rows of the same group have the same ID, and the groups are told apart by it.
fn drawGroupCombo(ctx: imgui.ContextPtr, w: *State, pool: *const Strings, rows: []const Row) void {
    var width: f64 = 140;
    imgui.api.SetNextItemWidth(ctx, width);
    width = 0;
    if (!imgui.api.BeginCombo(ctx, "##patchgroup", &w.group, null)) return;
    var seen: [32]strings.Ref = undefined;
    var seen_count: usize = 0;
    if (imgui.api.Selectable(ctx, all_groups, null, null, null, null)) w.group = initialGroup();
    for (rows) |row| {
        if (row.group == strings.empty) continue;
        var known = false;
        for (seen[0..seen_count]) |existing| {
            if (existing == row.group) known = true;
        }
        if (known or seen_count == seen.len) continue;
        seen[seen_count] = row.group;
        seen_count += 1;
        const group = pool.get(row.group);
        var selected = std.mem.eql(u8, std.mem.sliceTo(&w.group, 0), group);
        if (imgui.api.Selectable(ctx, group, &selected, null, null, null)) copyName(&w.group, group);
    }
    imgui.api.EndCombo(ctx);
}

/// The file name of the selected row, when it is a preset.
fn selectedPreset(io: std.Io, p: *Plugin) ?strings.Ref {
    const w = &p.ui.patches;
    if (w.selected == 0) return null;
    for (library.rows(io, p)) |row| {
        if (row.kind == .preset and row.value == w.selected) return row.file;
    }
    return null;
}

fn saveRow(io: std.Io, p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.patches;
    var action: ?types.Action = null;
    imgui.api.SetNextItemWidth(ctx, 280);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##savename", "name of the new patch", &p.ui.save_name, p.ui.save_name.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (p.save.state == .reading) {
        imgui.api.TextColored(ctx, theme.amber, "Reading the keyboard...");
    } else if (widgets.pushButton(kit, "Save the keyboard as a patch", 0)) {
        action = .{ .save_keyboard = p.strings.intern(std.mem.sliceTo(&p.ui.save_name, 0)) };
    }
    widgets.tooltip(kit, "Reads the keyboard, then saves what it holds as a preset under this name. The preset then appears in the table, where it can be sent to the keyboard or added to the scenes.");
    if (selectedPreset(io, p)) |file| {
        imgui.api.SameLine(ctx, null, null);
        const armed = w.delete_armed == w.selected;
        if (widgets.pushButton(kit, if (armed) "Click again to delete" else "Delete the selected preset", 0)) {
            if (armed) {
                action = .{ .delete_preset = file };
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
pub fn drawLibrary(io: std.Io, p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.patches;
    if (!widgets.beginCard(kit, "Patches", null, null, null)) return null;
    defer widgets.endCard(kit);
    const rows = library.rows(io, p);
    if (p.library.registration_count == 0) {
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
    drawGroupCombo(ctx, w, &p.strings, rows);
    imgui.api.SameLine(ctx, null, null);
    var refresh = false;
    if (widgets.pushButton(kit, "Refresh", 0)) refresh = true;
    widgets.tooltip(kit, "Reads the registrations and the presets folders again, after files were added or removed by hand. Saving or deleting a preset here needs no refresh.");
    const from_table = patchTable(io, p, ctx);
    const from_save = saveRow(io, p, ctx);
    if (refresh) return .refresh_library;
    return types.first(from_table, from_save);
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
        if (widgets.pushButton(kit, "Export", 0)) action = .{ .export_file = p.strings.intern(std.mem.sliceTo(&p.ui.export_path, 0)) };
        widgets.endCard(kit);
    }
    return action;
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
