const std = @import("std");
const mft_globals = @import("mft_globals.zig");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");
const fuzzy = @import("fuzzy");
const plugin_list = @import("mft_plugin_list.zig");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftPreferences = @import("mft_preferences.zig").MftPreferences;
const MftActiveModule = @import("mft_state.zig").MftActiveModule;
const colors = @import("mft_colors.zig");
const rows_mod = @import("mft_settings_rows.zig");
const rgba = @import("ui_palette").rgba;
const log = std.log.scoped(.mft_settings);
const MockImGui = @import("mock_imgui").MockImGui;

// Settings mode. Numeric settings (LED colors, sensitivity) are edited live with
// the encoders (see the SETTINGS branch in midi_events_mft); this module renders
// the panel form and the drop-downs that choose the default plugin of each slot
// among the installed ones. Save writes the preferences ini; Cancel reloads it,
// discarding edits.

const NAME_LEN = 256;
/// The edit buffers of the default plugins: the five modules, then the channel strip.
var buffers: [6][NAME_LEN:0]u8 = undefined;
var synced = false;
const strip_slot = 5;

const NAME_IDS = [6][:0]const u8{ "##in", "##gt", "##eq", "##cp", "##out", "##strip" };

/// The row of the knobs whose number is being typed, which a double click on its value starts, the text that is typed, and whether the field has to take
/// the keyboard on the next frame.
var edit_row: ?usize = null;
var edit_buf: [16:0]u8 = @splat(0);
var edit_focus = false;

/// What the last key of the panel did, which the panel says under its plates.
var status: [96:0]u8 = @splat(0);

/// What the panel says under its plates, which the tests read.
pub fn statusText() [:0]const u8 {
    return std.mem.sliceTo(&status, 0);
}

/// Starts the typing of the value of a row, as a double click on the value does. The tests use it, since the mock does not double click.
pub fn startTyping(index: usize) void {
    edit_row = index;
    edit_focus = true;
}

fn setStatus(text: []const u8) void {
    const n = @min(text.len, status.len);
    @memcpy(status[0..n], text[0..n]);
    status[n] = 0;
}

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
const CHOICES_W: f64 = 440.0;
const CHOICES_H: f64 = 220.0;
var filter: [64:0]u8 = @splat(0);

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
    copyInto(&buffers[strip_slot], p.default_strip);
    synced = true;
}

/// Writes the settings to preferences.ini, the default plugins being the ones chosen in the panel. The key of the panel and the push of the encoder 7 of
/// the SETTINGS page do it.
pub fn save(globals: *MftGlobals) void {
    ensureSynced(globals);
    const io = mft_globals.hostIo();
    const p = &globals.preferences;
    // Point the preference strings at the (static) edit buffers, then persist.
    p.default_input = bufSlice(0);
    p.default_gate = bufSlice(1);
    p.default_eq = bufSlice(2);
    p.default_comp = bufSlice(3);
    p.default_output = bufSlice(4);
    p.default_strip = bufSlice(strip_slot);
    p.saveToDisk(io, globals.resource_path) catch |err| {
        // The panel says it to the player, so the log only keeps a warning.
        log.warn("failed to save preferences: {s}", .{@errorName(err)});
        // The page stays, so that the player sees that the settings were not saved.
        setStatus("The settings could not be saved to preferences.ini.");
        return;
    };
    setStatus("Saved to preferences.ini.");
    globals.mft.settings_leave = true;
}

/// Reads preferences.ini again, which drops the edits. The key of the panel and the push of the encoder 8 of the SETTINGS page do it.
pub fn cancel(globals: *MftGlobals) void {
    const io = mft_globals.hostIo();
    // Reload from disk, discarding edits (numeric and text).
    if (MftPreferences.load(globals.arena.allocator(), io, globals.resource_path)) |reloaded| {
        globals.preferences = reloaded;
    } else |_| {}
    synced = false;
    if (send_hue) |send| send(globals, 0);
    setStatus("Back to the saved values.");
    globals.mft.settings_leave = true;
}

// The width of the screen that names a row of the form, and the size of the bar that shows its value.
const ROW_W: f64 = 150.0;
const BAR_W: f64 = 280.0;
const BAR_H: f64 = 22.0;
// How many segments the bar of a hue is cut into, to show the wheel of the controller's LEDs.
const WHEEL_SEGMENTS: usize = 64;

// A bar that shows a position from 0 to 1 with a thumb, and that a click or a drag with the mouse moves. Returns the
// position after the mouse, or null when the mouse does not hold the bar. A bar with a `fill` fills up to the thumb in
// that color, and a bar without one shows the wheel of the controller's LEDs.
fn bar(kit: *widgets.Panel, id: [:0]const u8, fraction: f64, fill: ?c_int) ?f64 {
    const ctx = kit.ctx;
    const at = widgets.cursorScreenPos(kit);
    var button_id: [64:0]u8 = undefined;
    _ = imgui.api.InvisibleButton(ctx, std.mem.printSentinel(&button_id, "##bar{s}", .{id}, 0) catch "##bar", BAR_W, BAR_H, null);
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
fn pluginPicker(kit: *widgets.Panel, slot: usize, width: f64) !void {
    const current = bufSlice(slot);
    const preview: [:0]const u8 = if (current.len == 0) "(choose a plugin)" else current;
    if (!widgets.beginPickList(kit, NAME_IDS[slot], preview, width)) return;
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

// ---- the panel ----
//
// The window of the SETTINGS page, as the mock of the design has it: a bar of round keys at the left (save, cancel, and the install of the factory presets),
// and a plate for each group of rows. The row that the first encoder is on is lit, a click on a row puts it there, and its value is changed with the second
// encoder or with the mouse.

const label_w: f64 = 170;
const plate_w: f64 = label_w + BAR_W + 90;

/// The round keys of the bar.
const Key = enum { save, cancel, install };

fn drawKey(kit: *widgets.Panel, key: Key, enabled: bool, tip: [:0]const u8) bool {
    const ctx = kit.ctx;
    const dl = imgui.api.GetWindowDrawList(ctx);
    const at = widgets.cursorScreenPos(kit);
    const size: f64 = 32;
    const id: [:0]const u8 = switch (key) {
        .save => "##stsave",
        .cancel => "##stcancel",
        .install => "##stinstall",
    };
    const clicked = imgui.api.InvisibleButton(ctx, id, size, size, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    const cx = at.x + size / 2;
    const cy = at.y + size / 2;
    widgets.circleFilled(dl, cx, cy + 2, size / 2, rgba(0x00000099));
    widgets.circleFilled(dl, cx, cy, size / 2, theme.knob_top);
    widgets.circle(dl, cx, cy, size / 2, if (hovered and enabled) theme.amber else theme.knob_edge, 1);
    const tone = if (!enabled) theme.text_dim else if (hovered) theme.amber else theme.label;
    switch (key) {
        .save => {
            widgets.line(dl, cx - 6, cy + 0.5, cx - 2, cy + 4.5, tone, 1.9);
            widgets.line(dl, cx - 2, cy + 4.5, cx + 6, cy - 4, tone, 1.9);
        },
        .cancel => {
            widgets.line(dl, cx - 5, cy - 5, cx + 5, cy + 5, tone, 1.9);
            widgets.line(dl, cx - 5, cy + 5, cx + 5, cy - 5, tone, 1.9);
        },
        .install => {
            widgets.line(dl, cx, cy - 6, cx, cy + 3, tone, 1.9);
            widgets.line(dl, cx - 4, cy - 1, cx, cy + 3, tone, 1.9);
            widgets.line(dl, cx + 4, cy - 1, cx, cy + 3, tone, 1.9);
            widgets.line(dl, cx - 6, cy + 6, cx + 6, cy + 6, tone, 1.9);
        },
    }
    if (hovered) widgets.tooltip(kit, tip);
    return clicked and enabled;
}

/// The two choices of the default mode, side by side, the one that is chosen being lit. It returns the choice that was clicked, or null.
fn rocker(kit: *widgets.Panel, single: bool) ?bool {
    const ctx = kit.ctx;
    const dl = imgui.api.GetWindowDrawList(ctx);
    const choices = [2][:0]const u8{ "Multi FX", "Single FX" };
    var picked: ?bool = null;
    const pushed = widgets.pushLabelFont(kit);
    defer widgets.popFont(kit, pushed);
    const height = imgui.api.GetTextLineHeight(ctx) + 8;
    const width: f64 = 96;
    const at = widgets.cursorScreenPos(kit);
    for (choices, 0..) |choice, i| {
        const x = at.x + @as(f64, @floatFromInt(i)) * width;
        imgui.api.SetCursorScreenPos(ctx, x, at.y);
        const chosen = (i == 1) == single;
        if (imgui.api.InvisibleButton(ctx, if (i == 0) "##stmulti" else "##stsingle", width, height, null)) picked = i == 1;
        const hovered = imgui.api.IsItemHovered(ctx, null);
        widgets.rectFilled(dl, x, at.y, x + width, at.y + height, if (chosen) widgets.faded(widgets.accent(kit), 0x55) else theme.slot_bg, 4);
        widgets.rect(dl, x, at.y, x + width, at.y + height, if (hovered) widgets.accent(kit) else theme.slot_edge, 4, 1);
        const size = widgets.textSize(kit, choice);
        imgui.api.DrawList_AddText(dl, x + (width - size.w) / 2, at.y + (height - size.h) / 2, if (chosen) theme.text else theme.text_dim, choice);
    }
    return picked;
}

/// One row: its name, lit when the first encoder is on it, and its value. A click on the name puts the encoder there.
fn drawRow(kit: *widgets.Panel, globals: *MftGlobals, index: usize) !void {
    const ctx = kit.ctx;
    const p = &globals.preferences;
    const r = rows_mod.rows[index];
    const selected = globals.mft.settings_cursor == index;
    var name_buf: [64:0]u8 = undefined;
    const name = std.mem.printSentinel(&name_buf, "{s}##strow{d}", .{ r.label, index }, 0) catch "?";
    var lit = selected;
    var w: f64 = label_w;
    var h: f64 = 0;
    imgui.api.PushStyleColor(ctx, imgui.Col_Text, if (r.kind == .not_done) theme.text_dim else theme.text);
    if (imgui.api.Selectable(ctx, name, &lit, null, &w, &h)) globals.mft.settings_cursor = @intCast(index);
    var popped: c_int = 1;
    imgui.api.PopStyleColor(ctx, &popped);
    imgui.api.SameLine(ctx, null, null);
    var buf: [32:0]u8 = undefined;
    switch (r.kind) {
        .hue => {
            const hue = rows_mod.hue(p, r.setting);
            if (bar(kit, r.label, @as(f64, @floatFromInt(hue)) / @as(f64, HUE_MAX), null)) |moved| {
                globals.mft.settings_cursor = @intCast(index);
                const next = hueAtFraction(moved);
                if (next != hue) {
                    rows_mod.setHue(p, r.setting, next);
                    if (send_hue) |send| send(globals, next);
                }
            }
            imgui.api.SameLine(ctx, null, null);
            imgui.api.TextColored(ctx, colors.hueToRgb(hue), std.mem.printSentinel(&buf, "{d:>3}", .{hue}, 0) catch "");
        },
        .number => {
            const fraction = rows_mod.fraction(p, r);
            if (bar(kit, r.label, fraction, widgets.accent(kit))) |moved| {
                globals.mft.settings_cursor = @intCast(index);
                switch (r.setting) {
                    .sensitivity => p.sensitivity = sensitivityAtFraction(moved),
                    .fine => p.fine = std.math.clamp(@as(f32, @floatCast(@round((rows_mod.fine_min + moved * (rows_mod.fine_max - rows_mod.fine_min)) / rows_mod.fine_step) * rows_mod.fine_step)), rows_mod.fine_min, rows_mod.fine_max),
                    else => unreachable,
                }
            }
            imgui.api.SameLine(ctx, null, null);
            const value: f32 = if (r.setting == .sensitivity) p.sensitivity else p.fine;
            if (edit_row == index) {
                // The value is typed in a field over it: Enter sets it, and Escape or a click elsewhere leaves it as it was.
                if (edit_focus) {
                    try imgui.SetKeyboardFocusHere(.{ctx});
                    edit_focus = false;
                }
                try imgui.SetNextItemWidth(.{ ctx, 70 });
                var flags: c_int = imgui.InputTextFlags_EnterReturnsTrue | imgui.InputTextFlags_AutoSelectAll | imgui.InputTextFlags_CharsDecimal;
                if (imgui.api.InputText(ctx, "##stedit", &edit_buf, edit_buf.len, &flags, null)) {
                    if (rows_mod.parseTyped(std.mem.sliceTo(&edit_buf, 0))) |typed| rows_mod.setNumber(p, r.setting, typed);
                    edit_row = null;
                } else if (imgui.api.IsItemDeactivated(ctx)) {
                    edit_row = null;
                }
            } else {
                imgui.api.TextColored(ctx, widgets.accent(kit), std.mem.printSentinel(&buf, "{d:.2}", .{value}, 0) catch "");
                if (imgui.api.IsItemHovered(ctx, null)) {
                    widgets.tooltip(kit, "Double-click to type the value");
                    if (imgui.api.IsMouseDoubleClicked(ctx, 0)) {
                        globals.mft.settings_cursor = @intCast(index);
                        edit_row = index;
                        _ = std.mem.printSentinel(&edit_buf, "{d:.2}", .{value}, 0) catch {};
                        edit_focus = true;
                    }
                }
            }
        },
        .toggle => {
            var value = rows_mod.toggleValue(p, r.setting);
            // The switch writes its label as it is, so the label has no id in it: the row has a scope of ids of its own instead, so that the switches of
            // two rows that both say On are told apart.
            var scope_buf: [24:0]u8 = undefined;
            imgui.api.PushID(ctx, std.mem.printSentinel(&scope_buf, "sttoggle{d}", .{index}, 0) catch "sttoggle");
            defer imgui.api.PopID(ctx);
            if (widgets.toggle(kit, if (value) "On" else "Off", &value)) {
                globals.mft.settings_cursor = @intCast(index);
                rows_mod.setToggle(p, r.setting, value);
            }
        },
        .plugin => {
            // The drop-down takes the room that is left in the card after the name of the row, so that it does not go past the edge of the card.
            var room_w: f64 = 0;
            var room_h: f64 = 0;
            imgui.api.GetContentRegionAvail(ctx, &room_w, &room_h);
            try pluginPicker(kit, rows_mod.pluginSlot(r.setting) orelse strip_slot, @max(room_w - 4, 80));
        },
        .mode => if (rocker(kit, p.single_fx_mode)) |single| {
            globals.mft.settings_cursor = @intCast(index);
            p.single_fx_mode = single;
        },
        .not_done => {
            imgui.api.PushStyleColor(ctx, imgui.Col_Text, theme.text_dim);
            imgui.api.Text(ctx, "not done yet");
            imgui.api.PopStyleColor(ctx, &popped);
        },
    }
}

/// Draws the panel of the settings inside a window that the caller began: the bar of keys, and a plate for each group of rows, as many to a row as
/// the window has room for.
pub fn drawPanel(kit: *widgets.Panel, globals: *MftGlobals, accent: c_int) !void {
    ensureSynced(globals);
    const ctx = kit.ctx;
    imgui.api.BeginGroup(ctx);
    imgui.api.Spacing(ctx);
    imgui.api.Spacing(ctx);
    if (drawKey(kit, .save, true, "Save the settings, and go back to the page")) save(globals);
    if (drawKey(kit, .cancel, true, "Cancel: back to the saved values, and to the page")) cancel(globals);
    _ = drawKey(kit, .install, false, "Install the factory presets (not done yet: the maps are installed by build-install.sh)");
    imgui.api.EndGroup(ctx);
    imgui.api.SameLine(ctx, null, null);

    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    var available_w: f64 = 0;
    var available_h: f64 = 0;
    imgui.api.GetContentRegionAvail(ctx, &available_w, &available_h);
    const per_row: usize = @max(1, @as(usize, @intFromFloat(@max((available_w + 14) / (plate_w + 14), 1))));
    var placed: usize = 0;
    inline for (@typeInfo(rows_mod.Group).@"enum".field_names) |field_name| {
        const group = @field(rows_mod.Group, field_name);
        var gap: f64 = 14;
        if (placed % per_row != 0) imgui.api.SameLine(ctx, null, &gap);
        placed += 1;
        if (widgets.beginCard(kit, group.title(), plate_w, null, accent)) {
            defer widgets.endCard(kit);
            for (rows_mod.rows, 0..) |r, i| {
                if (r.group == group) try drawRow(kit, globals, i);
            }
        }
    }
    const text = std.mem.sliceTo(&status, 0);
    if (text.len > 0) imgui.api.TextColored(ctx, theme.amber, text);
}

const test_plugins = [_][:0]const u8{ "VST: ReaGate (Cockos)", "JS: Saturation", "VST: ReaEQ (Cockos)" };

fn testSource(index: usize) ?[:0]const u8 {
    if (index >= test_plugins.len) return null;
    return test_plugins[index];
}

fn chosenLabels(mock: *const MockImGui, out: *std.ArrayList([]const u8)) !void {
    for (mock.trace_list.items) |entry| {
        if (entry.kind == .selectable) try out.append(std.testing.allocator, entry.label);
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
    var labels: std.ArrayList([]const u8) = .empty;
    defer labels.deinit(std.testing.allocator);
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
