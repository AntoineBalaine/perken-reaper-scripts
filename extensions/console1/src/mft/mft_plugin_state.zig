//! The state of a plugin that a map can keep, so that loading the plugin with the map restores it: the preset that the plugin had selected, and the value
//! of each of its parameters. Because REAPER does not give the chunk of every plugin (a JS plugin has none, and ReaComp gave none on the debug bridge),
//! the state is the values of the parameters, which every plugin has; the preset is selected first, and the values are set after it, so that what the
//! user changed after selecting the preset is kept.
//!
//! The state of a map is in a file of its own, next to the map (`<map>.state`), which the lists of the maps leave out. It has the line `preset = <name>`
//! when a preset was selected, and a line `param_N = <value>` for each parameter, N being counted from 0 and the value normalized. Because the format is
//! read and written without REAPER, it is here, where the unit tests reach it.
const std = @import("std");

/// How many parameters a state keeps. A plugin with more keeps the first ones.
pub const max_params = 1024;
pub const preset_len = 127;

pub const PluginState = struct {
    preset: [preset_len:0]u8 = @splat(0),
    count: u16 = 0,
    values: [max_params]f32 = @splat(0),

    pub fn presetName(self: *const PluginState) [:0]const u8 {
        return std.mem.sliceTo(&self.preset, 0);
    }

    pub fn setPreset(self: *PluginState, name: []const u8) void {
        const n = @min(name.len, preset_len);
        @memset(&self.preset, 0);
        @memcpy(self.preset[0..n], name[0..n]);
    }

    pub fn write(self: *const PluginState, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.writeAll("; The state of the plugin, which the map restores when it loads the plugin.\n");
        if (self.presetName().len > 0) try w.print("preset = {s}\n", .{self.presetName()});
        for (self.values[0..self.count], 0..) |value, i| try w.print("param_{d} = {d:.6}\n", .{ i, value });
    }

    /// Reads a state from its lines. A line that is not `preset` or a parameter is skipped, and the count is one past the highest parameter that is read.
    pub fn parse(text: []const u8) PluginState {
        var state = PluginState{};
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0 or line[0] == ';' or line[0] == '#') continue;
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const key = std.mem.trim(u8, line[0..eq], " \t");
            const value = std.mem.trim(u8, line[eq + 1 ..], " \t");
            if (std.mem.eql(u8, key, "preset")) {
                state.setPreset(value);
                continue;
            }
            if (!std.mem.startsWith(u8, key, "param_")) continue;
            const index = std.fmt.parseInt(u16, key["param_".len..], 10) catch continue;
            if (index >= max_params) continue;
            const number = std.fmt.parseFloat(f32, value) catch continue;
            state.values[index] = std.math.clamp(number, 0.0, 1.0);
            state.count = @max(state.count, index + 1);
        }
        return state;
    }
};

test "a state is written and read back: its preset and the values of its parameters, and the lines that are not one are skipped" {
    const t = std.testing;
    var state = PluginState{};
    state.setPreset("stock - Rock Snare");
    state.count = 3;
    state.values[0] = 0.25;
    state.values[2] = 1.0;
    var aw: std.Io.Writer.Allocating = .init(t.allocator);
    defer aw.deinit();
    try state.write(&aw.writer);
    const read = PluginState.parse(aw.written());
    try t.expectEqualStrings("stock - Rock Snare", read.presetName());
    try t.expectEqual(@as(u16, 3), read.count);
    try t.expectApproxEqAbs(@as(f32, 0.25), read.values[0], 1e-6);
    try t.expectEqual(@as(f32, 1.0), read.values[2]);
    const other = PluginState.parse("param_x = 1\nparam_1 = 7\nnothing\nparam_5000 = 0.5\n");
    try t.expectEqual(@as(u16, 2), other.count);
    try t.expectEqual(@as(f32, 1.0), other.values[1]);
    try t.expectEqualStrings("", other.presetName());
}
