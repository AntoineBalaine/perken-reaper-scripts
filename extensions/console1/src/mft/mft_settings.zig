const std = @import("std");
const imgui = @import("reaper_imgui");
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

pub fn drawForm(ctx: imgui.ContextPtr, globals: *MftGlobals) !void {
    ensureSynced(globals);
    const p = &globals.preferences;
    var buf: [96:0]u8 = undefined;

    try imgui.Text(.{ ctx, "Settings — colors/sensitivity edit via encoders 1-5" });
    try imgui.Text(.{ ctx, std.fmt.bufPrintZ(&buf, "IO color: {d}", .{p.color_io}) catch "IO color" });
    try imgui.Text(.{ ctx, std.fmt.bufPrintZ(&buf, "GATE color: {d}", .{p.color_gate}) catch "GATE color" });
    try imgui.Text(.{ ctx, std.fmt.bufPrintZ(&buf, "EQ color: {d}", .{p.color_eq}) catch "EQ color" });
    try imgui.Text(.{ ctx, std.fmt.bufPrintZ(&buf, "COMP color: {d}", .{p.color_comp}) catch "COMP color" });
    try imgui.Text(.{ ctx, std.fmt.bufPrintZ(&buf, "Sensitivity: {d:.2}", .{p.sensitivity}) catch "Sensitivity" });

    try imgui.Separator(.{ctx});
    try imgui.Text(.{ ctx, "Default plugin per slot (keyboard):" });
    for (0..5) |i| {
        try imgui.Text(.{ ctx, SLOT_LABELS[i] });
        try imgui.SameLine(.{ctx});
        _ = try imgui.InputText(.{ ctx, NAME_IDS[i], @as([*]u8, @ptrCast(&buffers[i])), NAME_LEN, null, null });
    }

    try imgui.Separator(.{ctx});
    if (try imgui.Button(.{ ctx, "Save settings" })) save(globals);
    try imgui.SameLine(.{ctx});
    if (try imgui.Button(.{ ctx, "Cancel" })) cancel(globals);
}
