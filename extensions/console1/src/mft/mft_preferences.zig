const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers");
const MftActiveModule = @import("mft_state.zig").MftActiveModule;
const log = std.log.scoped(.mft_prefs);

// User-editable settings, persisted to Data/Perken/MFT/preferences.ini. Modeled
// on the Console One preferences: the default plugin per module slot, plus the
// MFT-specific encoder sensitivity and per-module LED colors.
pub const MftPreferences = struct {
    default_input: [:0]const u8 = "JS: Volume/Pan Smoother v5",
    default_gate: [:0]const u8 = "VST: ReaGate (Cockos)",
    default_eq: [:0]const u8 = "VST: ReaEQ (Cockos)",
    default_comp: [:0]const u8 = "VST: ReaComp (Cockos)",
    default_output: [:0]const u8 = "JS: Saturation",
    // Multiplier on the base per-click step, 0.1 to 4.0.
    sensitivity: f32 = 1.0,
    // Hue positions on the MFT color wheel (channel 2).
    color_io: u8 = 0x0F,
    // Pinker than the comp's red, which 0x5A (90) was too close to.
    color_gate: u8 = 0x5E,
    color_eq: u8 = 0x3C,
    color_comp: u8 = 0x56,
    color_settings: u8 = 0x49,
    color_transport: u8 = 0x6B,

    pub fn colorForModule(self: *const MftPreferences, module: MftActiveModule) u8 {
        return switch (module) {
            .IO => self.color_io,
            .GATE => self.color_gate,
            .EQ => self.color_eq,
            .COMP => self.color_comp,
            .SETTINGS => self.color_settings,
            .TRANSPORT => self.color_transport,
        };
    }

    // Load preferences from <dir>/preferences.ini. Returns an error if the file
    // is absent so the caller can write the defaults. Plugin-name strings are
    // duped into the allocator.
    pub fn load(allocator: std.mem.Allocator, dir: [:0]const u8) !MftPreferences {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{ dir, std.fs.path.sep_str, "preferences.ini" });

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var parser = ini.parse(temp_arena.allocator(), file.reader());
        defer parser.deinit();

        var self = MftPreferences{};
        try parse(&self, &parser, allocator);
        return self;
    }

    pub fn saveToDisk(self: *const MftPreferences, dir: [:0]const u8) !void {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{ dir, std.fs.path.sep_str, "preferences.ini" });

        const file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
        defer file.close();
        var w = file.writer();

        try w.writeAll("; MFT preferences\n");
        try w.print("sensitivity = {d:.2}\n", .{self.sensitivity});
        try w.print("color_io = {d}\n", .{self.color_io});
        try w.print("color_gate = {d}\n", .{self.color_gate});
        try w.print("color_eq = {d}\n", .{self.color_eq});
        try w.print("color_comp = {d}\n", .{self.color_comp});
        try w.print("color_settings = {d}\n", .{self.color_settings});
        try w.print("color_transport = {d}\n\n", .{self.color_transport});
        try w.print("[input]\n{s}\n\n", .{self.default_input});
        try w.print("[gate]\n{s}\n\n", .{self.default_gate});
        try w.print("[eq]\n{s}\n\n", .{self.default_eq});
        try w.print("[comp]\n{s}\n\n", .{self.default_comp});
        try w.print("[output]\n{s}\n\n", .{self.default_output});
    }
};

const Section = enum { none, input, gate, eq, comp, output };

fn parse(self: *MftPreferences, parser: anytype, allocator: std.mem.Allocator) !void {
    var section: Section = .none;
    while (try parser.next()) |record| {
        switch (record) {
            .section => |heading| {
                section = std.meta.stringToEnum(Section, heading) orelse .none;
            },
            .property => |kv| {
                if (std.mem.eql(u8, kv.key, "sensitivity")) {
                    self.sensitivity = std.fmt.parseFloat(f32, kv.value) catch self.sensitivity;
                } else if (std.mem.eql(u8, kv.key, "color_io")) {
                    self.color_io = std.fmt.parseInt(u8, kv.value, 10) catch self.color_io;
                } else if (std.mem.eql(u8, kv.key, "color_gate")) {
                    self.color_gate = std.fmt.parseInt(u8, kv.value, 10) catch self.color_gate;
                } else if (std.mem.eql(u8, kv.key, "color_eq")) {
                    self.color_eq = std.fmt.parseInt(u8, kv.value, 10) catch self.color_eq;
                } else if (std.mem.eql(u8, kv.key, "color_comp")) {
                    self.color_comp = std.fmt.parseInt(u8, kv.value, 10) catch self.color_comp;
                } else if (std.mem.eql(u8, kv.key, "color_settings")) {
                    self.color_settings = std.fmt.parseInt(u8, kv.value, 10) catch self.color_settings;
                } else if (std.mem.eql(u8, kv.key, "color_transport")) {
                    self.color_transport = std.fmt.parseInt(u8, kv.value, 10) catch self.color_transport;
                }
            },
            // Plugin names appear as bare lines under a module section.
            .enumeration => |value| {
                if (value.len == 0) continue;
                const owned = allocator.dupeZ(u8, value) catch continue;
                switch (section) {
                    .input => self.default_input = owned,
                    .gate => self.default_gate = owned,
                    .eq => self.default_eq = owned,
                    .comp => self.default_comp = owned,
                    .output => self.default_output = owned,
                    .none => {},
                }
            },
        }
    }
}

test "MftPreferences: parse round-trip fields" {
    const t = std.testing;
    const example =
        \\sensitivity = 2.50
        \\color_io = 20
        \\color_eq = 60
        \\
        \\[input]
        \\JS: My Input
        \\
        \\[eq]
        \\VST: My EQ
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(t.allocator, fbs.reader());
    defer parser.deinit();

    var prefs = MftPreferences{};
    try parse(&prefs, &parser, t.allocator);
    defer {
        t.allocator.free(prefs.default_input);
        t.allocator.free(prefs.default_eq);
    }

    try t.expectApproxEqAbs(@as(f32, 2.5), prefs.sensitivity, 0.001);
    try t.expectEqual(@as(u8, 20), prefs.color_io);
    try t.expectEqual(@as(u8, 60), prefs.color_eq);
    try t.expectEqualStrings("JS: My Input", prefs.default_input);
    try t.expectEqualStrings("VST: My EQ", prefs.default_eq);
    // Unspecified fields keep their defaults.
    try t.expectEqual(@as(u8, 0x5E), prefs.color_gate);
}
