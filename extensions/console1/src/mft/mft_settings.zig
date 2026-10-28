const std = @import("std");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");
const fuzzy = @import("fuzzy");
const plugin_list = @import("mft_plugin_list.zig");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftPreferences = @import("mft_preferences.zig").MftPreferences;
const MftActiveModule = @import("mft_state.zig").MftActiveModule;
const colors = @import("mft_colors.zig");
const rgba = @import("ui_palette").rgba;
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

/// Sends the hue of a module to the controller's LEDs. Because the sending needs the MIDI output, which the unit tests
/// cannot link, the control surface installs it when it starts, and the tests leave it empty.
pub var send_hue: ?*const fn (globals: *MftGlobals, hue: u8) void = null;

/// The highest hue of the controller's wheel, and the range of the sensitivity.
pub const HUE_MAX: u8 = 127;
pub const SENSITIVITY_MIN: f32 = 0.1;
pub const SENSITIVITY_MAX: f32 = 4.0;
/// The step of the sensitivity, which one click of the encoder moves it by.
pub const SENSITIVITY_STEP: f32 = 0.05;

/// Sets the hue of a module. Because the LED color of the controller follows the hue, the encoders and the mouse both
/// come here: the stored preference is updated and the color is sent to the controller, so the two stay in sync.
pub fn setHue(globals: *MftGlobals, module: MftActiveModule, hue: u8) void {
    globals.preferences.setColorForModule(module, hue);
    if (send_hue) |send| send(globals, hue);
}

/// Sets the sensitivity, held to its range.
pub fn setSensitivity(globals: *MftGlobals, value: f32) void {
    globals.preferences.sensitivity = std.math.clamp(value, SENSITIVITY_MIN, SENSITIVITY_MAX);
}

/// The hue that a position on a bar (0 to 1) stands for.
pub fn hueAtFraction(fraction: f64) u8 {
    return @intFromFloat(@round(std.math.clamp(fraction, 0.0, 1.0) * HUE_MAX));
}

/// The sensitivity that a position on a bar (0 to 1) stands for, in steps of `SENSITIVITY_STEP`.
pub fn sensitivityAtFraction(fraction: f64) f32 {
    const span: f64 = SENSITIVITY_MAX - SENSITIVITY_MIN;
    const raw = SENSITIVITY_MIN + std.math.clamp(fraction, 0.0, 1.0) * span;
    const steps = @round(raw / SENSITIVITY_STEP);
    return @floatCast(steps * SENSITIVITY_STEP);
}

// The width of the screen of a drop-down, the size of its list, and the text typed in its filter. One filter serves
// all the drop-downs, because only one list is open at a time. Because a pop-up grows to fit what it holds, a child
// that asks for the rest of the width of one gets none, and the list would stay empty: the list has a width of its own.
const PICK_W: f64 = 400.0;
const CHOICES_W: f64 = 440.0;
const CHOICES_H: f64 = 220.0;
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

// The width of the screen that names a row of the form, and the size of the bar that shows its value.
const ROW_W: f64 = 150.0;
const BAR_W: f64 = 280.0;
const BAR_H: f64 = 22.0;
// How many segments the bar of a hue is cut into, to show the wheel of the controller's LEDs.
const WHEEL_SEGMENTS: usize = 64;

// Draws a row of the form on a recessed screen, lit with the card's accent when it is the selected row.
fn row(kit: *widgets.Panel, selected: bool, text: [:0]const u8) void {
    widgets.display(kit, text, if (selected) widgets.accent(kit) else theme.text_dim, ROW_W);
}

// A bar that shows a position from 0 to 1 with a thumb, and that a click or a drag with the mouse moves. Returns the
// position after the mouse, or null when the mouse does not hold the bar. A bar with a `fill` fills up to the thumb in
// that color, and a bar without one shows the wheel of the controller's LEDs.
fn bar(kit: *widgets.Panel, id: [:0]const u8, fraction: f64, fill: ?c_int) ?f64 {
    const ctx = kit.ctx;
    const at = widgets.cursorScreenPos(kit);
    var button_id: [64:0]u8 = undefined;
    _ = imgui.api.InvisibleButton(ctx, std.fmt.bufPrintZ(&button_id, "##bar{s}", .{id}) catch "##bar", BAR_W, BAR_H, null);
    var moved: ?f64 = null;
    if (imgui.api.IsItemActive(ctx)) {
        var mouse_x: f64 = 0;
        var mouse_y: f64 = 0;
        imgui.api.GetMousePos(ctx, &mouse_x, &mouse_y);
        moved = std.math.clamp((mouse_x - at.x) / BAR_W, 0.0, 1.0);
    }
    const hot = imgui.api.IsItemHovered(ctx, null);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const shown = moved orelse std.math.clamp(fraction, 0.0, 1.0);
    widgets.rectFilled(dl, at.x, at.y + 6, at.x + BAR_W, at.y + BAR_H - 6, theme.slot_bg, 3);
    if (fill) |color| {
        widgets.rectFilled(dl, at.x, at.y + 6, at.x + BAR_W * shown, at.y + BAR_H - 6, widgets.faded(color, 0xCC), 3);
    } else {
        for (0..WHEEL_SEGMENTS) |i| {
            const segments: f64 = WHEEL_SEGMENTS;
            const x1 = at.x + BAR_W * @as(f64, @floatFromInt(i)) / segments;
            const x2 = at.x + BAR_W * @as(f64, @floatFromInt(i + 1)) / segments;
            const middle: f32 = (@as(f32, @floatFromInt(i)) + 0.5) / WHEEL_SEGMENTS;
            widgets.rectFilled(dl, x1, at.y + 7, x2 + 0.5, at.y + BAR_H - 7, colors.hueToRgbAt(middle * @as(f32, HUE_MAX)), 0);
        }
    }
    widgets.rect(dl, at.x, at.y + 6, at.x + BAR_W, at.y + BAR_H - 6, theme.slot_edge, 3, 1);
    const thumb = at.x + BAR_W * shown;
    widgets.rectFilled(dl, thumb - 3, at.y + 2, thumb + 3, at.y + BAR_H - 2, theme.knob_top, 2);
    widgets.rect(dl, thumb - 3, at.y + 2, thumb + 3, at.y + BAR_H - 2, if (hot) rgba(0xFFFFFFFF) else theme.knob_edge, 2, 1);
    return moved;
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
    var width: f64 = CHOICES_W;
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

    imgui.api.TextColored(ctx, theme.grey, "Click or drag a bar, or scroll with encoder 1 and adjust with encoder 2");
    // A hue is shown on a bar that has the wheel of the controller's LEDs, and the number after it is in that color.
    inline for (@typeInfo(MftActiveModule).@"enum".fields, 0..) |field, i| {
        const module: MftActiveModule = @enumFromInt(field.value);
        const hue = p.colorForModule(module);
        row(kit, cursor == i, std.fmt.bufPrintZ(&buf, "{s} color", .{field.name}) catch "color");
        imgui.api.SameLine(ctx, null, null);
        if (bar(kit, field.name, @as(f64, @floatFromInt(hue)) / @as(f64, HUE_MAX), null)) |moved| {
            const next = hueAtFraction(moved);
            if (next != hue) setHue(globals, module, next);
        }
        imgui.api.SameLine(ctx, null, null);
        imgui.api.TextColored(ctx, colors.hueToRgb(p.colorForModule(module)), std.fmt.bufPrintZ(&buf, "{d:>3}", .{p.colorForModule(module)}) catch "");
    }
    row(kit, cursor == 6, "Sensitivity");
    imgui.api.SameLine(ctx, null, null);
    if (bar(kit, "sensitivity", (p.sensitivity - SENSITIVITY_MIN) / (SENSITIVITY_MAX - SENSITIVITY_MIN), accent)) |moved| {
        const next = sensitivityAtFraction(moved);
        if (next != p.sensitivity) setSensitivity(globals, next);
    }
    imgui.api.SameLine(ctx, null, null);
    imgui.api.TextColored(ctx, accent, std.fmt.bufPrintZ(&buf, "{d:.2}", .{p.sensitivity}) catch "");

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

test "a hue set by the mouse is stored and sent to the controller, as the encoders do" {
    const Sent = struct {
        var hue: ?u8 = null;
        fn send(_: *MftGlobals, h: u8) void {
            hue = h;
        }
    };
    send_hue = &Sent.send;
    defer send_hue = null;
    var globals: MftGlobals = .{};
    setHue(&globals, .EQ, 42);
    try std.testing.expectEqual(@as(u8, 42), globals.preferences.color_eq);
    try std.testing.expectEqual(@as(?u8, 42), Sent.hue);
    setSensitivity(&globals, 9.0);
    try std.testing.expectEqual(SENSITIVITY_MAX, globals.preferences.sensitivity);
}

test "the ends and the middle of a bar stand for the ends and the middle of the range" {
    try std.testing.expectEqual(@as(u8, 0), hueAtFraction(-1));
    try std.testing.expectEqual(@as(u8, 127), hueAtFraction(2));
    try std.testing.expectEqual(@as(u8, 64), hueAtFraction(0.5));
    try std.testing.expectEqual(@as(f32, 0.1), sensitivityAtFraction(0));
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), sensitivityAtFraction(1), 0.001);
}
