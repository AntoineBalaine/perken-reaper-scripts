const std = @import("std");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftPreferences = @import("mft_preferences.zig").MftPreferences;
const log = std.log.scoped(.mft_settings);

// Settings mode. Numeric settings (LED colors, sensitivity) are edited live with
// the encoders (see the SETTINGS branch in midi_events_mft); this module renders
// the panel form and handles the plugin-name text fields, which need the
// keyboard. Save writes the preferences ini; Cancel reloads it, discarding edits.

const NAME_LEN = 256;
var buffers: [5][NAME_LEN:0]u8 = undefined;
var synced = false;

// The number of selectable rows: six colors, sensitivity, five plugin names.
pub const ITEM_COUNT: i16 = 12;

const SLOT_LABELS = [5][:0]const u8{ "Input", "Gate", "EQ", "Comp", "Output" };
const NAME_IDS = [5][:0]const u8{ "##in", "##gt", "##eq", "##cp", "##out" };

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

// The form is a card with the accent of the settings module. The kit has no text input, so the plugin names are the
// raw ReaImGui inputs, which take their colors from the panel's theme.
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
        _ = try imgui.InputText(.{ ctx, NAME_IDS[i], @as([*]u8, @ptrCast(&buffers[i])), NAME_LEN, null, null });
    }

    imgui.api.Spacing(ctx);
    if (widgets.pushButton(kit, "Save settings", 0)) save(globals);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(kit, "Cancel", 0)) cancel(globals);
}
