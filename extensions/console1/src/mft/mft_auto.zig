//! The AUTO page, which the user fills. Each of its sixteen knobs and eight pushes can have a REAPER action, or a parameter of an FX of the current track,
//! which is found by the name of the plugin. Its factory map has the automation modes on the first five pushes, as a suggestion.
//!
//! The map of the page is written as the maps of the modules are, with values of two kinds: `action:<command id>`, and `fx:<plugin name>|<parameter>`,
//! where the bar is used because the names of the plugins have colons in them. Because the logic does not call REAPER, it is here, where the unit tests
//! can reach it.
const std = @import("std");
const mappings = @import("mft_mappings.zig");

/// The room for the name of a plugin in a target.
pub const fx_name_len = 95;

/// A parameter of an FX of the current track: the plugin is found by its name, the first one of that name on the track.
pub const FxParam = struct {
    fx_name: [fx_name_len:0]u8 = @splat(0),
    param: u16 = 0,

    pub fn init(plugin: []const u8, param: u16) FxParam {
        var out = FxParam{ .param = param };
        const n = @min(plugin.len, fx_name_len);
        @memcpy(out.fx_name[0..n], plugin[0..n]);
        out.fx_name[n] = 0;
        return out;
    }

    pub fn name(self: *const FxParam) [:0]const u8 {
        return std.mem.sliceTo(&self.fx_name, 0);
    }
};

/// An action that a script or an extension adds to REAPER. Its command id changes from one session to the next, so it is kept by its name, which starts
/// with an underscore ("_SWS_ABOUT"), and REAPER is asked for the id when the action runs.
pub const NamedAction = struct {
    text: [fx_name_len:0]u8 = @splat(0),

    pub fn init(command_name: []const u8) NamedAction {
        var out = NamedAction{};
        const n = @min(command_name.len, fx_name_len);
        @memcpy(out.text[0..n], command_name[0..n]);
        out.text[n] = 0;
        return out;
    }

    pub fn name(self: *const NamedAction) [:0]const u8 {
        return std.mem.sliceTo(&self.text, 0);
    }
};

/// What a control of the AUTO page does.
pub const Target = union(enum) {
    /// A native REAPER action of the main section, by its command id, which does not change.
    action: c_int,
    /// An action of a script or an extension, by its name.
    named_action: NamedAction,
    fx_param: FxParam,

    pub fn eql(self: Target, other: Target) bool {
        return switch (self) {
            .action => |id| other == .action and other.action == id,
            .named_action => |named| other == .named_action and std.mem.eql(u8, named.name(), other.named_action.name()),
            .fx_param => |fx| other == .fx_param and other.fx_param.param == fx.param and std.mem.eql(u8, fx.name(), other.fx_param.name()),
        };
    }
};

/// The map of the AUTO page.
pub const AutoMap = struct {
    knobs: [mappings.knob_count]?Target = @splat(null),
    pushes: [mappings.push_count]?Target = @splat(null),

    /// The target of a control, the sixteen knobs first and then the eight pushes.
    pub fn control(self: *const AutoMap, index: usize) ?Target {
        return if (index < mappings.knob_count) self.knobs[index] else self.pushes[index - mappings.knob_count];
    }

    pub fn setControl(self: *AutoMap, index: usize, target: ?Target) void {
        if (index < mappings.knob_count) self.knobs[index] = target else self.pushes[index - mappings.knob_count] = target;
    }

    pub fn eql(self: *const AutoMap, other: *const AutoMap) bool {
        for (0..mappings.knob_count + mappings.push_count) |i| {
            const a = self.control(i);
            const b = other.control(i);
            if ((a == null) != (b == null)) return false;
            if (a) |ta| if (!ta.eql(b.?)) return false;
        }
        return true;
    }
};

/// The REAPER actions that the combos of the AUTO page offer, with their names. The ids were read from REAPER (kbd_getTextFromCmd).
pub const Action = struct { label: [:0]const u8, id: c_int };

pub const actions = [_]Action{
    .{ .label = "Auto: Trim", .id = 40400 },
    .{ .label = "Auto: Read", .id = 40401 },
    .{ .label = "Auto: Latch", .id = 40404 },
    .{ .label = "Auto: Preview", .id = 42023 },
    .{ .label = "Auto: Write", .id = 40403 },
    .{ .label = "Toggle metronome", .id = 40364 },
    .{ .label = "Cycle ripple editing", .id = 1155 },
    .{ .label = "Toggle auto-crossfade", .id = 40041 },
    .{ .label = "Go to project start", .id = 40042 },
    .{ .label = "Go to project end", .id = 40043 },
    .{ .label = "Set loop to time selection", .id = 40622 },
    .{ .label = "Toggle record arm of the selected tracks", .id = 9 },
    .{ .label = "Undo", .id = 40029 },
    .{ .label = "Redo", .id = 40030 },
    .{ .label = "Save project", .id = 40026 },
};

/// The name of an action of the list, or null for an action that is not in it.
pub fn actionLabel(id: c_int) ?[:0]const u8 {
    for (actions) |a| {
        if (a.id == id) return a.label;
    }
    return null;
}

/// Reads the value of a control in the map of the AUTO page, or null for a value that is not one.
pub fn parseTarget(text: []const u8) ?Target {
    const trimmed = std.mem.trim(u8, text, " \t\r");
    if (std.mem.startsWith(u8, trimmed, "action:")) {
        const rest = trimmed["action:".len..];
        if (std.fmt.parseInt(c_int, rest, 10)) |id| return .{ .action = id } else |_| {}
        // An action of a script or an extension is kept by its name, which starts with an underscore.
        if (rest.len > 1 and rest[0] == '_') return .{ .named_action = NamedAction.init(rest) };
        return null;
    }
    if (std.mem.startsWith(u8, trimmed, "fx:")) {
        const rest = trimmed["fx:".len..];
        const bar = std.mem.lastIndexOfScalar(u8, rest, '|') orelse return null;
        if (bar == 0) return null;
        const param = std.fmt.parseInt(u16, rest[bar + 1 ..], 10) catch return null;
        return .{ .fx_param = FxParam.init(rest[0..bar], param) };
    }
    return null;
}

fn writeTarget(w: *std.Io.Writer, target: Target) std.Io.Writer.Error!void {
    switch (target) {
        .action => |id| try w.print("action:{d}", .{id}),
        .named_action => |named| try w.print("action:{s}", .{named.name()}),
        .fx_param => |fx| try w.print("fx:{s}|{d}", .{ fx.name(), fx.param }),
    }
}

/// Writes the map of the AUTO page.
pub fn write(map: *const AutoMap, w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.print("version = {d}\nmodule = AUTO\n", .{mappings.MFT_MAPPING_FORMAT_VERSION});
    for (map.knobs, 0..) |maybe, i| {
        const target = maybe orelse continue;
        try w.print("knob_{d} = ", .{i + 1});
        try writeTarget(w, target);
        try w.writeByte('\n');
    }
    for (map.pushes, 0..) |maybe, i| {
        const target = maybe orelse continue;
        try w.print("push_{d} = ", .{i + 1});
        try writeTarget(w, target);
        try w.writeByte('\n');
    }
}

/// Matches a key made of `prefix` and a number from 1 to `count`, and returns the zero-based position.
fn positionKey(key: []const u8, prefix: []const u8, count: usize) ?usize {
    if (!std.mem.startsWith(u8, key, prefix)) return null;
    const n = std.fmt.parseInt(usize, key[prefix.len..], 10) catch return null;
    if (n < 1 or n > count) return null;
    return n - 1;
}

/// Reads the map of the AUTO page from its lines (`knob_N = ...`, `push_N = ...`). A line that is not a control, or whose value is not a target, is left out.
pub fn parse(text: []const u8) AutoMap {
    var map = AutoMap{};
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, if (std.mem.indexOfScalar(u8, raw, ';')) |at| raw[0..at] else raw, " \t\r");
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const target = parseTarget(line[eq + 1 ..]) orelse continue;
        if (positionKey(key, "knob_", mappings.knob_count)) |i| map.knobs[i] = target else if (positionKey(key, "push_", mappings.push_count)) |i| map.pushes[i] = target;
    }
    return map;
}

test "parseTarget: an action by its id, a parameter of a plugin whose name has colons, and what is not a target" {
    const t = std.testing;
    try t.expectEqual(@as(c_int, 40364), parseTarget("action:40364").?.action);
    const fx = parseTarget(" fx:VST: ReaEQ (Cockos)|3 ").?.fx_param;
    try t.expectEqualStrings("VST: ReaEQ (Cockos)", fx.name());
    try t.expectEqual(@as(u16, 3), fx.param);
    try t.expectEqual(@as(?Target, null), parseTarget("fx:|3"));
    try t.expectEqual(@as(?Target, null), parseTarget("fx:ReaEQ"));
    try t.expectEqual(@as(?Target, null), parseTarget("12"));
    // An action of a script or an extension is kept by its name.
    try t.expectEqualStrings("_SWS_ABOUT", parseTarget("action:_SWS_ABOUT").?.named_action.name());
    try t.expectEqual(@as(?Target, null), parseTarget("action:SWS_ABOUT"));
    try t.expectEqual(@as(?Target, null), parseTarget("action:"));
}

test "write and parse: the map of the AUTO page reads back the same" {
    const t = std.testing;
    var map = AutoMap{};
    map.setControl(0, .{ .fx_param = FxParam.init("JS: Saturation", 1) });
    map.setControl(mappings.knob_count + 2, .{ .action = 40026 });
    map.setControl(7, .{ .named_action = NamedAction.init("_RS1234abcd") });
    var aw: std.Io.Writer.Allocating = .init(t.allocator);
    defer aw.deinit();
    try write(&map, &aw.writer);
    const read = parse(aw.written());
    try t.expect(read.eql(&map));
    try t.expectEqualStrings("Save project", actionLabel(read.control(mappings.knob_count + 2).?.action).?);
    // A map that differs in one control is not the same.
    var other = read;
    other.setControl(0, .{ .fx_param = FxParam.init("JS: Saturation", 2) });
    try t.expect(!other.eql(&map));
}

test "the shipped map of the AUTO page has the automation modes on the first five pushes" {
    const t = std.testing;
    const map = parse(@embedFile("resources/maps/factory/AUTO/default.ini"));
    try t.expectEqualStrings("Auto: Trim", actionLabel(map.pushes[0].?.action).?);
    try t.expectEqualStrings("Auto: Write", actionLabel(map.pushes[4].?.action).?);
    try t.expectEqual(@as(?Target, null), map.pushes[5]);
    try t.expectEqual(@as(?Target, null), map.knobs[0]);
}
