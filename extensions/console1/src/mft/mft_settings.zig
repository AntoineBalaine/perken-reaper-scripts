const std = @import("std");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");
const fuzzy = @import("fuzzy");
const plugin_list = @import("mft_plugin_list.zig");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftPreferences = @import("mft_preferences.zig").MftPreferences;
const log = std.log.scoped(.mft_settings);
const MockImGui = @import("mock_imgui").MockImGui;

// Settings mode. Numeric settings (LED colors, sensitivity) are edited live with
// the encoders (see the SETTINGS branch in midi_events_mft); this module renders
// the panel form and the drop-downs that choose the default plugin of each slot
// among the installed ones. Save writes the preferences ini; Cancel reloads it,
// discarding edits.

const NAME_LEN = 256;
var buffers: [5][NAME_LEN:0]u8 = undefined;
var synced = false;

// The number of selectable rows: six colors, sensitivity, five plugin names.
pub const ITEM_COUNT: i16 = 12;

const SLOT_LABELS = [5][:0]const u8{ "Input", "Gate", "EQ", "Comp", "Output" };
const NAME_IDS = [5][:0]const u8{ "##in", "##gt", "##eq", "##cp", "##out" };

// The width of the screen of a drop-down, the height of its list, and the text typed in its filter. One filter
// serves all the drop-downs, because only one list is open at a time.
const PICK_W: f64 = 380.0;
const CHOICES_H: f64 = 260.0;
var filter: [64:0]u8 = [_:0]u8{0} ** 64;

fn copyInto(buf: *[NAME_LEN:0]u8, s: [:0]const u8) void {
    const n = @min(s.len, NAME_LEN - 1);
    @memcpy(buf[0..n], s[0..n]);
    buf[n] = 0;
}

fn bufSlice(i: usize) [:0]const u8 {
    return std.mem.sliceTo(&buffers[i], 0);
}

// Reset so the buffers re-sync from preferences next time settings is shown.
// Called when the panel is not in settings mode.
pub fn markUnsynced() void {
    synced = false;
    plugin_list.invalidate();
}

fn ensureSynced(globals: *MftGlobals) void {
    if (synced) return;
    const p = &globals.preferences;
    copyInto(&buffers[0], p.default_input);
    copyInto(&buffers[1], p.default_gate);
    copyInto(&buffers[2], p.default_eq);
    copyInto(&buffers[3], p.default_comp);
    copyInto(&buffers[4], p.default_output);
    synced = true;
}

fn save(globals: *MftGlobals) void {
    const p = &globals.preferences;
    // Point the preference strings at the (static) edit buffers, then persist.
    p.default_input = bufSlice(0);
    p.default_gate = bufSlice(1);
    p.default_eq = bufSlice(2);
    p.default_comp = bufSlice(3);
    p.default_output = bufSlice(4);
    p.saveToDisk(globals.resource_path) catch |err| {
        log.err("failed to save preferences: {s}", .{@errorName(err)});
    };
}

fn cancel(globals: *MftGlobals) void {
    // Reload from disk, discarding edits (numeric and text).
    if (MftPreferences.load(globals.arena.allocator(), globals.resource_path)) |reloaded| {
        globals.preferences = reloaded;
    } else |_| {}
    synced = false;
}

// The width of the screen of a row of the form.
const ROW_W: f64 = 240.0;

// Draws a row of the form on a recessed screen, lit with the card's accent when it is the selected row.
fn row(kit: *widgets.Panel, selected: bool, text: [:0]const u8) void {
    widgets.display(kit, text, if (selected) widgets.accent(kit) else theme.text_dim, ROW_W);
}

// The drop-down of one slot: the plugin chosen is on the screen, and a click opens the list of the installed plugins.
fn pluginPicker(kit: *widgets.Panel, slot: usize) !void {
    const current = bufSlice(slot);
    const preview: [:0]const u8 = if (current.len == 0) "(choose a plugin)" else current;
    if (!widgets.beginPickList(kit, NAME_IDS[slot], preview, PICK_W)) return;
    defer widgets.endPickList(kit);
    try pluginChoices(kit, slot);
}

// The inside of the list: a filter that keeps the plugins whose name holds its letters in order, and the plugins in a
// list that scrolls, because a machine has hundreds. A click on one makes it the slot's plugin.
fn pluginChoices(kit: *widgets.Panel, slot: usize) !void {
    const ctx = kit.ctx;
    _ = try imgui.InputText(.{ ctx, "##pluginfilter", @as([*]u8, @ptrCast(&filter)), filter.len, null, null });
    const query = std.mem.sliceTo(&filter, 0);
    var width: f64 = 0;
    var height: f64 = CHOICES_H;
    // Because ReaImGui expects EndChild only when BeginChild returned true, the list is closed inside the branch.
    if (imgui.api.BeginChild(ctx, "##pluginchoices", &width, &height, null, null)) {
        defer imgui.api.EndChild(ctx);
        for (plugin_list.all()) |name| {
            if (query.len > 0 and fuzzy.score(query, name) == null) continue;
            if (widgets.pickItem(kit, name, std.mem.eql(u8, name, bufSlice(slot)), true)) {
                copyInto(&buffers[slot], name);
                filter[0] = 0;
                break;
            }
        }
    }
}

// The form is a card with the accent of the settings module.
pub fn drawForm(kit: *widgets.Panel, globals: *MftGlobals, accent: c_int) !void {
    ensureSynced(globals);
    const ctx = kit.ctx;
    const p = &globals.preferences;
    const cursor = globals.mft.settings_cursor;
    var buf: [96:0]u8 = undefined;

    if (!widgets.beginCard(kit, "Settings", null, null, accent)) return;
    defer widgets.endCard(kit);

    imgui.api.TextColored(ctx, theme.grey, "Encoder 1 scrolls, encoder 2 adjusts");
    row(kit, cursor == 0, std.fmt.bufPrintZ(&buf, "IO color: {d}", .{p.color_io}) catch "IO color");
    row(kit, cursor == 1, std.fmt.bufPrintZ(&buf, "GATE color: {d}", .{p.color_gate}) catch "GATE color");
    row(kit, cursor == 2, std.fmt.bufPrintZ(&buf, "EQ color: {d}", .{p.color_eq}) catch "EQ color");
    row(kit, cursor == 3, std.fmt.bufPrintZ(&buf, "COMP color: {d}", .{p.color_comp}) catch "COMP color");
    row(kit, cursor == 4, std.fmt.bufPrintZ(&buf, "SETTINGS color: {d}", .{p.color_settings}) catch "SETTINGS color");
    row(kit, cursor == 5, std.fmt.bufPrintZ(&buf, "TRANSPORT color: {d}", .{p.color_transport}) catch "TRANSPORT color");
    row(kit, cursor == 6, std.fmt.bufPrintZ(&buf, "Sensitivity: {d:.2}", .{p.sensitivity}) catch "Sensitivity");

    imgui.api.Spacing(ctx);
    imgui.api.TextColored(ctx, theme.grey, "Default plugin per slot (keyboard):");
    for (0..5) |i| {
        row(kit, cursor == 7 + i, SLOT_LABELS[i]);
        imgui.api.SameLine(ctx, null, null);
        try pluginPicker(kit, i);
    }

    imgui.api.Spacing(ctx);
    if (widgets.pushButton(kit, "Save settings", 0)) save(globals);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(kit, "Cancel", 0)) cancel(globals);
}

const test_plugins = [_][:0]const u8{ "VST: ReaGate (Cockos)", "JS: Saturation", "VST: ReaEQ (Cockos)" };

fn testSource(index: usize) ?[:0]const u8 {
    if (index >= test_plugins.len) return null;
    return test_plugins[index];
}

fn chosenLabels(mock: *const MockImGui, out: *std.ArrayList([]const u8)) !void {
    for (mock.trace_list.items) |entry| {
        if (entry.kind == .selectable) try out.append(entry.label);
    }
}

test "a click on a plugin of the list makes it the slot's plugin, and the filter keeps the ones that match" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    plugin_list.source = testSource;
    defer {
        plugin_list.source = plugin_list.reaperSource;
        plugin_list.invalidate();
    }
    plugin_list.invalidate();

    var panel = widgets.Panel{};
    copyInto(&buffers[1], "VST: ReaGate (Cockos)");

    // Without a filter, every plugin is listed, sorted, and a click chooses one.
    mock.selectItem("JS: Saturation");
    try pluginChoices(&panel, 1);
    try std.testing.expectEqualStrings("JS: Saturation", bufSlice(1));
    try mock.assertBalanced();

    // With a filter, the plugins whose names do not hold its letters in order are left out of the list.
    mock.trace_list.clearRetainingCapacity();
    @memcpy(filter[0..4], "satu");
    filter[4] = 0;
    try pluginChoices(&panel, 1);
    var labels = std.ArrayList([]const u8).init(std.testing.allocator);
    defer labels.deinit();
    try chosenLabels(&mock, &labels);
    try std.testing.expectEqual(@as(usize, 1), labels.items.len);
    try std.testing.expectEqualStrings("JS: Saturation", labels.items[0]);
    filter[0] = 0;
}
