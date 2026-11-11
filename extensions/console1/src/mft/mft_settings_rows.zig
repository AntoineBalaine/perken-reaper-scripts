//! The rows of the settings panel, as the mock of the design has them: the colors of the pages, the knobs, the general options, the options of the
//! tracks, and the default FX. The first encoder of the SETTINGS page scrolls them, and the second one adjusts the highlighted one: a turn changes a color,
//! a number or the choice of a list, and moves a switch, and a click flips a switch or goes to the next choice.
//!
//! The language row has nothing behind it in the controller yet: it is drawn and marked as not done, and the encoders leave it as it is. The feedback
//! window, the log file and the manual routing of the design are left out, because the controller has no use for them. Because the logic does not call REAPER, it is
//! here, where the unit tests can reach it.
const std = @import("std");
const MftPreferences = @import("mft_preferences.zig").MftPreferences;
const MftActiveModule = @import("mft_state.zig").MftActiveModule;

pub const Group = enum {
    colors,
    knobs,
    general,
    tracks,
    default_fx,

    pub fn title(self: Group) [:0]const u8 {
        return switch (self) {
            .colors => "Colors",
            .knobs => "Knobs",
            .general => "General",
            .tracks => "Tracks",
            .default_fx => "Default FX",
        };
    }
};

/// What a row holds, which says how it is drawn and how the encoder changes it.
pub const Kind = enum { hue, number, toggle, order, plugin, mode, not_done };

/// The settings, in the order of the rows.
pub const Setting = enum {
    hue_input,
    hue_gate,
    hue_eq,
    hue_comp,
    hue_output,
    hue_settings,
    hue_transport,
    hue_auto,
    hue_fxsel,
    sensitivity,
    fine,
    startup_message,
    plugin_ui,
    language,
    auto_insert,
    auto_insert_bypassed,
    auto_reorder,
    preferred_order,
    default_input,
    default_gate,
    default_eq,
    default_comp,
    default_output,
    default_strip,
    default_mode,
};

pub const Row = struct {
    setting: Setting,
    group: Group,
    kind: Kind,
    label: [:0]const u8,
};

pub const rows = [_]Row{
    .{ .setting = .hue_input, .group = .colors, .kind = .hue, .label = "Input" },
    .{ .setting = .hue_gate, .group = .colors, .kind = .hue, .label = "Shape" },
    .{ .setting = .hue_eq, .group = .colors, .kind = .hue, .label = "EQ" },
    .{ .setting = .hue_comp, .group = .colors, .kind = .hue, .label = "Comp" },
    .{ .setting = .hue_output, .group = .colors, .kind = .hue, .label = "Output" },
    .{ .setting = .hue_settings, .group = .colors, .kind = .hue, .label = "Settings" },
    .{ .setting = .hue_transport, .group = .colors, .kind = .hue, .label = "Transport" },
    .{ .setting = .hue_auto, .group = .colors, .kind = .hue, .label = "Auto" },
    .{ .setting = .hue_fxsel, .group = .colors, .kind = .hue, .label = "FX Selection" },
    .{ .setting = .sensitivity, .group = .knobs, .kind = .number, .label = "Sensitivity" },
    .{ .setting = .fine, .group = .knobs, .kind = .number, .label = "Fine multiplier" },
    .{ .setting = .startup_message, .group = .general, .kind = .toggle, .label = "Show startup message" },
    .{ .setting = .plugin_ui, .group = .general, .kind = .toggle, .label = "Show plugin UI" },
    .{ .setting = .language, .group = .general, .kind = .not_done, .label = "Language" },
    .{ .setting = .auto_insert, .group = .tracks, .kind = .toggle, .label = "Auto insert modules" },
    .{ .setting = .auto_insert_bypassed, .group = .tracks, .kind = .toggle, .label = "Auto insert bypassed" },
    .{ .setting = .auto_reorder, .group = .tracks, .kind = .toggle, .label = "Auto reorder modules" },
    .{ .setting = .preferred_order, .group = .tracks, .kind = .order, .label = "Preferred order" },
    .{ .setting = .default_input, .group = .default_fx, .kind = .plugin, .label = "Input" },
    .{ .setting = .default_gate, .group = .default_fx, .kind = .plugin, .label = "Shape" },
    .{ .setting = .default_eq, .group = .default_fx, .kind = .plugin, .label = "EQ" },
    .{ .setting = .default_comp, .group = .default_fx, .kind = .plugin, .label = "Comp" },
    .{ .setting = .default_output, .group = .default_fx, .kind = .plugin, .label = "Output" },
    .{ .setting = .default_strip, .group = .default_fx, .kind = .plugin, .label = "Channel strip" },
    .{ .setting = .default_mode, .group = .default_fx, .kind = .mode, .label = "Default mode" },
};

pub const row_count = rows.len;

/// The page whose color a row of the colors is, or null for the color of the FX Selection mode and for the other rows.
pub fn pageOf(setting: Setting) ?MftActiveModule {
    return switch (setting) {
        .hue_input => .INPUT,
        .hue_gate => .GATE,
        .hue_eq => .EQ,
        .hue_comp => .COMP,
        .hue_output => .OUTPUT,
        .hue_settings => .SETTINGS,
        .hue_transport => .TRANSPORT,
        .hue_auto => .AUTO,
        else => null,
    };
}

/// The index of the default plugin of a row of the default FX among the five slots of the settings (input, gate, EQ, comp, output), or null for the
/// channel strip and for the other rows.
pub fn pluginSlot(setting: Setting) ?usize {
    return switch (setting) {
        .default_input => 0,
        .default_gate => 1,
        .default_eq => 2,
        .default_comp => 3,
        .default_output => 4,
        else => null,
    };
}

pub const sensitivity_min: f32 = 0.1;
pub const sensitivity_max: f32 = 4.0;
pub const sensitivity_step: f32 = 0.05;
pub const fine_min: f32 = 0.01;
pub const fine_max: f32 = 1.0;
pub const fine_step: f32 = 0.01;

/// The hue of a row of the colors.
pub fn hue(prefs: *const MftPreferences, setting: Setting) u8 {
    if (pageOf(setting)) |page| return prefs.colorForModule(page);
    std.debug.assert(setting == .hue_fxsel);
    return prefs.color_fxsel;
}

pub fn setHue(prefs: *MftPreferences, setting: Setting, value: u8) void {
    if (pageOf(setting)) |page| return prefs.setColorForModule(page, value);
    std.debug.assert(setting == .hue_fxsel);
    prefs.color_fxsel = value;
}

/// The value of a switch.
pub fn toggleValue(prefs: *const MftPreferences, setting: Setting) bool {
    return switch (setting) {
        .startup_message => prefs.startup_message,
        .plugin_ui => prefs.show_plugin_ui,
        .auto_insert => prefs.auto_insert,
        .auto_insert_bypassed => prefs.auto_insert_bypassed,
        .auto_reorder => prefs.auto_reorder,
        else => unreachable,
    };
}

pub fn setToggle(prefs: *MftPreferences, setting: Setting, value: bool) void {
    switch (setting) {
        .startup_message => prefs.startup_message = value,
        .plugin_ui => prefs.show_plugin_ui = value,
        .auto_insert => prefs.auto_insert = value,
        .auto_insert_bypassed => prefs.auto_insert_bypassed = value,
        .auto_reorder => prefs.auto_reorder = value,
        else => unreachable,
    }
}

fn stepNumber(value: f32, delta: i8, step: f32, min: f32, max: f32) f32 {
    const next = value + @as(f32, @floatFromInt(delta)) * step;
    // The steps are counted, so that a value that was moved many times is still a whole number of steps.
    return std.math.clamp(@round(next / step) * step, min, max);
}

/// Sets a number to a value that was typed, held to its range and rounded to its step, as a turn of the encoder keeps it.
pub fn setNumber(prefs: *MftPreferences, setting: Setting, value: f32) void {
    switch (setting) {
        .sensitivity => prefs.sensitivity = stepNumber(value, 0, sensitivity_step, sensitivity_min, sensitivity_max),
        .fine => prefs.fine = stepNumber(value, 0, fine_step, fine_min, fine_max),
        else => unreachable,
    }
}

/// The number that a text typed for a row stands for, or null when the text is not a number. A comma is taken as the decimal point too.
pub fn parseTyped(text: []const u8) ?f32 {
    var buf: [32]u8 = undefined;
    const trimmed = std.mem.trim(u8, text, " \t");
    if (trimmed.len == 0 or trimmed.len > buf.len) return null;
    for (trimmed, 0..) |c, i| buf[i] = if (c == ',') '.' else c;
    const value = std.fmt.parseFloat(f32, buf[0..trimmed.len]) catch return null;
    if (std.math.isNan(value) or std.math.isInf(value)) return null;
    return value;
}

/// A turn of the second encoder on a row: a color goes round the wheel, a number goes up or down by its step, a switch goes on for a turn to the right
/// and off for a turn to the left, and the mode goes to the choice on that side. A plugin is chosen with the keyboard, and a row that is not done stays.
pub fn adjust(prefs: *MftPreferences, row: Row, delta: i8) void {
    if (delta == 0) return;
    switch (row.kind) {
        .hue => setHue(prefs, row.setting, @intCast(@mod(@as(i16, hue(prefs, row.setting)) + delta, 128))),
        .number => switch (row.setting) {
            .sensitivity => prefs.sensitivity = stepNumber(prefs.sensitivity, delta, sensitivity_step, sensitivity_min, sensitivity_max),
            .fine => prefs.fine = stepNumber(prefs.fine, delta, fine_step, fine_min, fine_max),
            else => unreachable,
        },
        .toggle => setToggle(prefs, row.setting, delta > 0),
        .order => prefs.module_order = prefs.module_order.step(if (delta > 0) 1 else -1),
        .mode => prefs.single_fx_mode = delta > 0,
        .plugin, .not_done => {},
    }
}

/// A click of the second encoder on a row: a switch flips, and the mode goes to the other choice.
pub fn flip(prefs: *MftPreferences, row: Row) void {
    switch (row.kind) {
        .toggle => setToggle(prefs, row.setting, !toggleValue(prefs, row.setting)),
        .order => prefs.module_order = prefs.module_order.step(1),
        .mode => prefs.single_fx_mode = !prefs.single_fx_mode,
        .hue, .number, .plugin, .not_done => {},
    }
}

/// Where the value of a row is, from 0 to 1, which the ring of the second encoder shows.
pub fn fraction(prefs: *const MftPreferences, row: Row) f64 {
    return switch (row.kind) {
        .hue => @as(f64, @floatFromInt(hue(prefs, row.setting))) / 127.0,
        .number => switch (row.setting) {
            .sensitivity => (prefs.sensitivity - sensitivity_min) / (sensitivity_max - sensitivity_min),
            .fine => (prefs.fine - fine_min) / (fine_max - fine_min),
            else => unreachable,
        },
        .toggle => if (toggleValue(prefs, row.setting)) 1.0 else 0.0,
        .order => @as(f64, @floatFromInt(@backingInt(prefs.module_order))) / 2.0,
        .mode => if (prefs.single_fx_mode) 1.0 else 0.0,
        .plugin, .not_done => 0.0,
    };
}

test "the rows are in the groups of the design, in order, and every color has its page or is the FX Selection" {
    const t = std.testing;
    var last: usize = 0;
    for (rows) |row| {
        const group = @backingInt(row.group);
        try t.expect(group >= last);
        last = group;
        if (row.kind == .hue) try t.expect(pageOf(row.setting) != null or row.setting == .hue_fxsel);
    }
    try t.expectEqual(@as(usize, 25), row_count);
}

test "a turn changes a color round the wheel, a number by its steps within its range, and a switch and the mode by its side" {
    const t = std.testing;
    var prefs = MftPreferences{};
    prefs.color_eq = 126;
    adjust(&prefs, rows[2], 3);
    try t.expectEqual(@as(u8, 1), prefs.color_eq);
    adjust(&prefs, rows[8], -1);
    try t.expectEqual(@as(u8, 0x2A), prefs.color_fxsel);
    adjust(&prefs, rows[9], 2);
    try t.expectApproxEqAbs(@as(f32, 1.1), prefs.sensitivity, 1e-5);
    adjust(&prefs, rows[10], -50);
    try t.expectEqual(fine_min, prefs.fine);
    adjust(&prefs, rows[14], -1);
    try t.expect(!prefs.auto_insert);
    flip(&prefs, rows[14]);
    try t.expect(prefs.auto_insert);
    try t.expectEqual(@as(f64, 1.0), fraction(&prefs, rows[14]));
    adjust(&prefs, rows[24], 1);
    try t.expect(prefs.single_fx_mode);
    flip(&prefs, rows[24]);
    try t.expect(!prefs.single_fx_mode);
}

test "a row that is not done, and a plugin, stay as they are under the encoder" {
    const t = std.testing;
    var prefs = MftPreferences{};
    const before = prefs;
    adjust(&prefs, rows[11], 5);
    flip(&prefs, rows[11]);
    adjust(&prefs, rows[18], 5);
    try t.expect(std.meta.eql(before.single_fx_mode, prefs.single_fx_mode));
    try t.expectEqual(before.auto_insert, prefs.auto_insert);
    try t.expectEqual(@as(?usize, 2), pluginSlot(.default_eq));
    try t.expectEqual(@as(?usize, null), pluginSlot(.default_strip));
}

test "a typed number is read with a point or a comma, held to the range of its row, and rounded to its step" {
    const t = std.testing;
    try t.expectEqual(@as(?f32, 1.5), parseTyped(" 1.5 "));
    try t.expectEqual(@as(?f32, 0.25), parseTyped("0,25"));
    try t.expectEqual(@as(?f32, null), parseTyped("fast"));
    try t.expectEqual(@as(?f32, null), parseTyped(""));
    var prefs = MftPreferences{};
    setNumber(&prefs, .sensitivity, 9);
    try t.expectEqual(sensitivity_max, prefs.sensitivity);
    setNumber(&prefs, .sensitivity, 1.23);
    try t.expectApproxEqAbs(@as(f32, 1.25), prefs.sensitivity, 1e-5);
    setNumber(&prefs, .fine, 0.001);
    try t.expectEqual(fine_min, prefs.fine);
}

test "the order of the modules goes round with a turn and a click, and the auto reorder is a switch" {
    const t = std.testing;
    var prefs = MftPreferences{};
    try t.expectEqual(@import("mft_order.zig").Order.s_eq_c, prefs.module_order);
    adjust(&prefs, rows[17], 1);
    try t.expectEqualStrings("EQ-S-C", prefs.module_order.label());
    flip(&prefs, rows[17]);
    try t.expectEqualStrings("S-C-EQ", prefs.module_order.label());
    adjust(&prefs, rows[16], -1);
    try t.expect(!prefs.auto_reorder);
}
