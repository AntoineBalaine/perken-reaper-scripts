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
const ui = @import("ui.zig");
const state_files = @import("state.zig");
const registrations = @import("registrations.zig");
const tones = @import("tones.zig");
const scenes = @import("scenes.zig");
const dump = @import("dump.zig");
const fuzzy = @import("fuzzy.zig");
const fileio = @import("fileio.zig");
const glue = @import("reaper_glue.zig");
const engine = @import("engine.zig");
const theme = @import("theme.zig");
const widgets = @import("widgets.zig");

const Plugin = plugin.Plugin;

const name_cap = 48;
const group_cap = 24;
const search_cap = 64;
const rows_cap = 1024;

const all_groups = "All groups";
const type_names = [_][:0]const u8{ "All", "Registration", "Tone", "Preset" };
const first_tone_value: u32 = 101;
const preset_id_first: u32 = 1000;
const preset_id_span: u32 = 60000;

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
    /// Where the "save the keyboard" button is: 0 when idle, 1 until the read starts, 2 until it ends.
    saving: u8 = 0,
    saving_since: u32 = 0,
};

fn initialGroup() [group_cap:0]u8 {
    var group = [_:0]u8{0} ** group_cap;
    @memcpy(group[0..all_groups.len], all_groups);
    return group;
}

// ---- the rows ----

const Kind = enum { registration, tone, preset };

const Row = struct {
    kind: Kind,
    key: u64,
    number: [8:0]u8,
    name: [name_cap:0]u8,
    group: [group_cap:0]u8,
    /// The value of the Patch parameter that selects the row.
    value: u32,
    /// The position of the row's source: in the registrations, in the tone list, or in the presets.
    source: usize,
    /// The tone list of a tone: 0 for the pianos, 1 for the synths, 2 for the drum kits.
    list: u8 = 0,
};

/// The rows are rebuilt each frame, in storage of their own because there are several hundred.
var rows: [rows_cap]Row = undefined;
var row_count: usize = 0;
/// The rows that the filters let through, in the order they are shown.
var shown: [rows_cap]u32 = undefined;
var shown_count: usize = 0;

fn copyZ(dest: anytype, text: []const u8) void {
    const n = @min(text.len, dest.len);
    @memcpy(dest[0..n], text[0..n]);
    dest[n] = 0;
}

fn hashOf(text: []const u8) u64 {
    return std.hash.Wyhash.hash(0, text);
}

/// The patch ID of a preset: a hash of its name (FNV-1a), brought into the range of the IDs. The same name
/// gives the same ID on every computer, so a template that holds it finds it again.
pub fn presetId(name: []const u8) u32 {
    var h: u32 = 2166136261;
    for (name) |byte| h = (h ^ byte) *% 16777619;
    return preset_id_first + h % preset_id_span;
}

fn addRow(row: Row) void {
    if (row_count == rows_cap) return;
    rows[row_count] = row;
    row_count += 1;
}

/// Every patch of the table: the registrations, the tones, and then the player's presets.
fn buildRows(p: *Plugin) void {
    row_count = 0;
    const w = &p.ui;
    if (w.reg_library) |lib| {
        for (lib.entries.items, 0..) |entry, i| {
            var row: Row = undefined;
            row.kind = .registration;
            row.source = i;
            row.list = 0;
            var display: [name_cap]u8 = undefined;
            copyZ(&row.name, registrations.displayName(&display, entry.name));
            var number: [8]u8 = undefined;
            copyZ(&row.number, std.fmt.bufPrint(&number, "{d}-{d}", .{ entry.bank, entry.slot }) catch "");
            copyZ(&row.group, "");
            row.value = (@as(u32, entry.bank) - 1) * 4 + entry.slot;
            var key: [24]u8 = undefined;
            row.key = hashOf(std.fmt.bufPrint(&key, "reg{d}", .{i}) catch "reg");
            addRow(row);
        }
    }
    var position: u32 = 0;
    const lists = [_][]const tones.Tone{ &tones.piano, &tones.synth, &tones.drum };
    for (lists, 0..) |list, list_index| {
        for (list, 0..) |tone, i| {
            var row: Row = undefined;
            row.kind = .tone;
            row.source = i;
            row.list = @intCast(list_index);
            copyZ(&row.name, tone.name);
            copyZ(&row.number, "");
            copyZ(&row.group, tone.group);
            row.value = first_tone_value + position;
            var key: [24]u8 = undefined;
            row.key = hashOf(std.fmt.bufPrint(&key, "tone{d}-{d}", .{ list_index, i }) catch "tone");
            addRow(row);
            position += 1;
        }
    }
    if (w.preset_names) |list| {
        for (list.items, 0..) |file_name, i| {
            var row: Row = undefined;
            row.kind = .preset;
            row.source = i;
            row.list = 0;
            const display = state_files.displayName(file_name);
            copyZ(&row.name, display);
            copyZ(&row.number, "");
            copyZ(&row.group, "USER");
            row.value = presetId(display);
            row.key = hashOf(file_name);
            addRow(row);
        }
    }
}

fn typeOf(row: *const Row) [:0]const u8 {
    return type_names[@as(usize, @intFromEnum(row.kind)) + 1];
}

fn nameOf(row: *const Row) []const u8 {
    return std.mem.sliceTo(&row.name, 0);
}

fn groupOf(row: *const Row) []const u8 {
    return std.mem.sliceTo(&row.group, 0);
}

fn numberOf(row: *const Row) []const u8 {
    return std.mem.sliceTo(&row.number, 0);
}

// ---- the filters, the search and the sort ----

/// Whether the type and the group filters let a row through. The search text is not part of it: it ranks the
/// rows that remain.
fn matchesFilters(w: *const State, row: *const Row) bool {
    if (w.type_index != 0 and row.kind != @as(Kind, @enumFromInt(w.type_index - 1))) return false;
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

const SortContext = struct { column: i32 };

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
    const left = &rows[a];
    const right = &rows[b];
    const ta = sortText(left, context.column);
    const tb = sortText(right, context.column);
    if (!std.ascii.eqlIgnoreCase(ta, tb)) return std.ascii.lessThanIgnoreCase(ta, tb);
    return left.value < right.value;
}

/// The rows that the filters let through. A search ranks them by how well they match, best first.
fn buildShown(w: *const State) void {
    shown_count = 0;
    for (rows[0..row_count], 0..) |*row, i| {
        if (matchesFilters(w, row)) {
            shown[shown_count] = @intCast(i);
            shown_count += 1;
        }
    }
    const query = std.mem.sliceTo(&w.search, 0);
    if (query.len == 0) return;
    var ranked: [rows_cap]Ranked = undefined;
    var count: usize = 0;
    var text_buf: [160]u8 = undefined;
    for (shown[0..shown_count]) |index| {
        const text = searchText(&text_buf, &rows[index]);
        if (fuzzy.score(query, text)) |score| {
            ranked[count] = .{ .index = index, .score = score, .len = @intCast(text.len) };
            count += 1;
        }
    }
    std.mem.sort(Ranked, ranked[0..count], {}, rankedBefore);
    for (ranked[0..count], 0..) |entry, k| shown[k] = entry.index;
    shown_count = count;
}

// ---- what a row does ----

fn partOfTone(row: *const Row) ?[]const u8 {
    return switch (row.list) {
        0 => "upper_piano",
        1 => "upper_synth",
        else => null,
    };
}

fn toneOf(row: *const Row) *const tones.Tone {
    return switch (row.list) {
        0 => &tones.piano[row.source],
        1 => &tones.synth[row.source],
        else => &tones.drum[row.source],
    };
}

/// Sends a patch to the keyboard: a registration or a preset is loaded from its file, and a tone is written
/// to the upper part.
fn sendPatch(p: *Plugin, row: *const Row) void {
    switch (row.kind) {
        .registration => {
            const lib = p.ui.reg_library orelse return;
            ui.loadRegistration(p, lib.entries.items[row.source]);
        },
        .preset => {
            const list = p.ui.preset_names orelse return;
            ui.loadPreset(p, list.items[row.source]);
        },
        .tone => {
            const part = partOfTone(row) orelse {
                ui.notice(&p.ui, "The panel does not send drum kits yet.", .{}, false);
                return;
            };
            const tone = toneOf(row);
            const patch = plugin.allocator.create(dump.Dump) catch return;
            defer plugin.allocator.destroy(patch);
            patch.* = .{};
            if (!scenes.toneDump(patch, part, tone.number, tone.msb, tone.lsb)) return;
            p.loadScene(patch, nameOf(row));
            ui.notice(&p.ui, "Sent \"{s}\" to the keyboard.", .{nameOf(row)}, false);
        },
    }
}

/// Reads a patch of a library file into `patch`. Returns false, with a notice, when it cannot.
fn readLibraryFile(p: *Plugin, folder_of: enum { registrations, presets }, file_name: []const u8, patch: *dump.Dump) bool {
    if (!glue.ready) {
        ui.notice(&p.ui, "REAPER's API is not available.", .{}, true);
        return false;
    }
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = (switch (folder_of) {
        .registrations => state_files.registrationFolder(&folder_buf, glue.resourcePath()),
        .presets => state_files.presetFolder(&folder_buf, glue.resourcePath()),
    }) catch {
        ui.notice(&p.ui, "The folder's path is too long.", .{}, true);
        return false;
    };
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ folder, std.fs.path.sep, file_name }) catch return false;
    state_files.loadPresetFile(plugin.allocator, path, patch) catch |err| {
        ui.notice(&p.ui, "Could not read {s}: {s}", .{ file_name, @errorName(err) }, true);
        return false;
    };
    return true;
}

/// Puts a library row at the end of the session's scenes, as a scene of its name.
fn addToScenes(p: *Plugin, row: *const Row) void {
    const patch = plugin.allocator.create(dump.Dump) catch return;
    defer plugin.allocator.destroy(patch);
    patch.* = .{};
    switch (row.kind) {
        .registration => {
            const lib = p.ui.reg_library orelse return;
            if (!readLibraryFile(p, .registrations, lib.entries.items[row.source].file_name, patch)) return;
        },
        .preset => {
            const list = p.ui.preset_names orelse return;
            if (!readLibraryFile(p, .presets, list.items[row.source], patch)) return;
        },
        .tone => {
            const part = partOfTone(row) orelse {
                ui.notice(&p.ui, "The panel does not make scenes of drum kits yet.", .{}, false);
                return;
            };
            const tone = toneOf(row);
            if (!scenes.toneDump(patch, part, tone.number, tone.msb, tone.lsb)) return;
        },
    }
    const position = p.scene_list.addFrom(nameOf(row), patch, @intCast(row.value), nameOf(row)) catch {
        ui.notice(&p.ui, "The scene list is full.", .{}, true);
        return;
    };
    ui.notice(&p.ui, "Added \"{s}\" as scene {d}.", .{ nameOf(row), position }, false);
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

fn patchTable(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui.patches;
    // Because the theme's header color is nearly the table's own gray, the selected row takes the accent.
    imgui.api.PushStyleColor(ctx, imgui.Col_Header, widgets.faded(theme.amber, 0x70));
    // The table is drawn in the label font, which is bold, and it is pushed before the table begins so that
    // the rows take their height from it.
    const pushed = widgets.pushLabelFont(ctx);
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

        buildRows(p);
        buildShown(w);
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
            std.mem.sort(u32, shown[0..shown_count], SortContext{ .column = w.sort_column }, sortLess);
            if (w.sort_descending) std.mem.reverse(u32, shown[0..shown_count]);
        }
        for (shown[0..shown_count]) |index| {
            drawRow(p, ctx, &rows[index]);
        }
        imgui.api.EndTable(ctx);
    }
    widgets.popFont(ctx, pushed);
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
}

fn drawRow(p: *Plugin, ctx: imgui.ContextPtr, row: *const Row) void {
    const w = &p.ui.patches;
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
        if (imgui.api.IsMouseDoubleClicked(ctx, 0)) sendPatch(p, row);
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
    if (addButton(ctx, row.key)) addToScenes(p, row);
}

// ---- the library card ----

/// The groups of the table in the order that they first appear, after "All groups".
fn drawGroupCombo(ctx: imgui.ContextPtr, w: *State) void {
    var width: f64 = 140;
    imgui.api.SetNextItemWidth(ctx, width);
    width = 0;
    if (!imgui.api.BeginCombo(ctx, "##patchgroup", &w.group, null)) return;
    var seen: [32][group_cap:0]u8 = undefined;
    var seen_count: usize = 0;
    if (imgui.api.Selectable(ctx, all_groups, null, null, null, null)) w.group = initialGroup();
    for (rows[0..row_count]) |*row| {
        const group = groupOf(row);
        if (group.len == 0) continue;
        var known = false;
        for (seen[0..seen_count]) |*existing| {
            if (std.mem.eql(u8, std.mem.sliceTo(existing, 0), group)) known = true;
        }
        if (known or seen_count == seen.len) continue;
        copyZ(&seen[seen_count], group);
        seen_count += 1;
        var selected = std.mem.eql(u8, std.mem.sliceTo(&w.group, 0), group);
        if (imgui.api.Selectable(ctx, &row.group, &selected, null, null, null)) copyZ(&w.group, group);
    }
    imgui.api.EndCombo(ctx);
}

/// Reads the keyboard, then saves what it holds as a preset under the typed name, when the read is over.
fn pollSave(p: *Plugin) void {
    const w = &p.ui.patches;
    if (w.saving == 0) return;
    const job: engine.JobKind = @enumFromInt(p.shared.job.load(.monotonic));
    if (w.saving == 1 and job != .idle) w.saving = 2;
    const waited = p.ui.frame -% w.saving_since;
    if ((w.saving == 2 and job == .idle) or waited > 600) {
        w.saving = 0;
        ui.savePreset(p);
    }
}

fn selectedPreset(p: *Plugin) ?[]u8 {
    const w = &p.ui.patches;
    const list = p.ui.preset_names orelse return null;
    for (list.items) |file_name| {
        if (hashOf(file_name) == w.selected) return file_name;
    }
    return null;
}

fn saveRow(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui.patches;
    pollSave(p);
    imgui.api.SetNextItemWidth(ctx, 280);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##savename", "name of the new patch", &p.ui.save_name, p.ui.save_name.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (w.saving != 0) {
        imgui.api.TextColored(ctx, theme.amber, "Reading the keyboard...");
    } else if (widgets.pushButton(ctx, "Save the keyboard as a patch", 0)) {
        _ = p.shared.sendCommand(.capture_keyboard);
        w.saving = 1;
        w.saving_since = p.ui.frame;
    }
    widgets.tooltip(ctx, "Reads the keyboard, then saves what it holds as a preset under this name. The preset then appears in the table, where it can be sent to the keyboard or added to the scenes.");
    if (selectedPreset(p)) |file_name| {
        imgui.api.SameLine(ctx, null, null);
        const armed = w.delete_armed == w.selected;
        if (widgets.pushButton(ctx, if (armed) "Click again to delete" else "Delete the selected preset", 0)) {
            if (armed) {
                ui.deletePreset(p, file_name);
                w.selected = 0;
                w.delete_armed = 0;
            } else {
                w.delete_armed = w.selected;
            }
        }
    } else {
        w.delete_armed = 0;
    }
}

fn patchList(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui.patches;
    if (!widgets.beginCard(ctx, "Patches", null, null, null)) return;
    defer widgets.endCard(ctx);
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
    drawGroupCombo(ctx, w);
    patchTable(p, ctx);
    saveRow(p, ctx);
}

// ---- the session's scenes ----

/// The list of the session's scenes: a row for each, with its name and the patch it came from. A click
/// selects the scene, which has the plugin recall its patch, and the button on its right removes it.
fn sceneList(p: *Plugin, ctx: imgui.ContextPtr) void {
    if (!widgets.beginCard(ctx, "Scenes of this session", null, null, null)) return;
    defer widgets.endCard(ctx);
    const list = p.scene_list;
    if (list.count == 0) {
        imgui.api.TextColored(ctx, theme.grey, "No scenes yet. Press Add on a patch.");
        return;
    }
    const current = p.scene.load(.monotonic);
    const pushed = widgets.pushLabelFont(ctx);
    defer widgets.popFont(ctx, pushed);
    var remove_at: ?u8 = null;
    var position: u8 = 1;
    while (position <= list.count) : (position += 1) {
        const scene = list.get(position) orelse break;
        var label: [160:0]u8 = undefined;
        const text = std.fmt.bufPrintZ(&label, "{d}  {s}  ({s})##scene{d}", .{ position, scene.name(), scene.label(), position }) catch "?";
        var selected = current == position;
        if (imgui.api.Selectable(ctx, text, &selected, null, null, null)) {
            p.selectScene(position) catch {};
        }
        imgui.api.SameLine(ctx, null, null);
        var button: [24:0]u8 = undefined;
        if (imgui.api.SmallButton(ctx, std.fmt.bufPrintZ(&button, "Remove##r{d}", .{position}) catch "Remove")) remove_at = position;
    }
    if (remove_at) |at| {
        var map: scenes.Mapping = undefined;
        _ = p.removeScene(at, &map);
    }
    imgui.api.Separator(ctx);
    var line: [96:0]u8 = undefined;
    const scene = list.get(current);
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&line, "Scene parameter: {d}  {s}", .{ current, if (scene) |s| s.name() else "(no scene)" }) catch "");
}

/// The Scenes tab: the library of patches, and beside it the session's scenes.
pub fn drawScenes(p: *Plugin, ctx: imgui.ContextPtr) void {
    patchList(p, ctx);
    imgui.api.SameLine(ctx, null, null);
    sceneList(p, ctx);
}

// ---- the Patches tab ----

/// The keyboard's read and write buttons, and the options.
pub fn drawPatches(p: *Plugin, ctx: imgui.ContextPtr) void {
    const s = p.shared;
    if (widgets.beginCard(ctx, "Keyboard", null, null, null)) {
        if (widgets.pushButton(ctx, "Read the keyboard", 0)) {
            _ = s.sendCommand(.capture_keyboard);
            ui.notice(&p.ui, "Reading the keyboard's state into this plugin.", .{}, false);
        }
        if (widgets.pushButton(ctx, "Send to the keyboard", 0)) {
            _ = s.sendCommand(.recall);
            ui.notice(&p.ui, "Writing this plugin's state to the keyboard.", .{}, false);
        }
        widgets.tooltip(ctx, "Only what differs is written: about 0.15 seconds when the keyboard has been read, a few seconds otherwise.");
        widgets.endCard(ctx);
    }
    imgui.api.SameLine(ctx, null, null);
    if (widgets.beginCard(ctx, "Options", null, null, null)) {
        var split_on = p.settings.split.load(.monotonic);
        if (widgets.toggle(ctx, "This patch splits at middle C", &split_on)) plugin.setPatchSplit(p, split_on);
        widgets.tooltip(ctx, "The keyboard cannot report its split. When this is on, the track's notes below middle C go to the Lower part (channel 3) and the others to the Upper part (channel 4); when off, every note goes to the Upper part. The setting is remembered for this patch.");
        var follow = s.follow_panel.load(.monotonic);
        if (widgets.toggle(ctx, "Follow changes made on the keyboard's panel", &follow)) s.follow_panel.store(follow, .monotonic);
        var recall = s.recall_on_load.load(.monotonic);
        if (widgets.toggle(ctx, "Send the patch to the keyboard when the project opens", &recall)) s.recall_on_load.store(recall, .monotonic);
        widgets.endCard(ctx);
    }
    // The files card is the plugin's own: the lab has no import or export, but the plugin had them, and a
    // feature is not dropped without saying so.
    if (widgets.beginCard(ctx, "Files", null, null, null)) {
        if (widgets.pushButton(ctx, "Import a file", 0)) ui.importFile(p);
        widgets.tooltip(ctx, "Loads a dump made by vr09.py, or a preset file from elsewhere.");
        imgui.api.SetNextItemWidth(ctx, 420);
        var input_flags: c_int = imgui.InputTextFlags_None;
        _ = imgui.api.InputTextWithHint(ctx, "##export", "path of the file to write (a dump, as vr09.py reads it)", &p.ui.export_path, p.ui.export_path.len, &input_flags, null);
        imgui.api.SameLine(ctx, null, null);
        if (widgets.pushButton(ctx, "Export", 0)) ui.exportFile(p);
        widgets.endCard(ctx);
    }
}

test "a preset's ID comes from its name and stays in range" {
    const a = presetId("Warm Pad");
    try std.testing.expectEqual(a, presetId("Warm Pad"));
    try std.testing.expect(a >= preset_id_first and a < preset_id_first + preset_id_span);
    try std.testing.expect(presetId("Warm Pad") != presetId("Warm Pad 2"));
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
