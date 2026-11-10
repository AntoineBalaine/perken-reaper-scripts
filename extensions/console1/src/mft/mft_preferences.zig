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
    /// The channel strip mode: a track that has none of the plugins of the modules gets the default channel strip instead of them, when the strip
    /// is named. Because a strip needs a map that says which parameter each control moves, the name has to be of a plugin that has one.
    single_fx_mode: bool = false,
    default_strip: [:0]const u8 = "",
    // Multiplier on the base per-click step, 0.1 to 4.0.
    sensitivity: f32 = 1.0,
    /// How much smaller the step of a knob is while its push is held, which is the fine adjustment: from 0.01 to 1.
    fine: f32 = 0.1,
    /// Whether a message says in REAPER's console that the controller is ready, when the surface starts.
    startup_message: bool = false,
    /// Whether the window of a plugin opens when the controller inserts it.
    show_plugin_ui: bool = false,
    /// Whether a module button inserts the default plugin of the module on a track that has none, and whether that plugin is inserted bypassed.
    auto_insert: bool = true,
    auto_insert_bypassed: bool = false,
    // Hue positions on the MFT color wheel (channel 2).
    color_input: u8 = 0x0F,
    // Pinker than the comp's red, which 0x5A (90) and 0x5E (94) were too close to.
    color_gate: u8 = 0x62,
    color_eq: u8 = 0x3C,
    color_comp: u8 = 0x56,
    color_settings: u8 = 0x49,
    color_transport: u8 = 0x6B,
    color_auto: u8 = 0x19,
    // The hue 3, which is far enough from the hue of the input on the wheel to tell the two pages apart.
    color_output: u8 = 3,
    /// The color of the LEDs and of the panel in the FX Selection mode.
    color_fxsel: u8 = 0x2B,

    pub fn colorForModule(self: *const MftPreferences, module: MftActiveModule) u8 {
        return switch (module) {
            .INPUT => self.color_input,
            .GATE => self.color_gate,
            .EQ => self.color_eq,
            .COMP => self.color_comp,
            .SETTINGS => self.color_settings,
            .TRANSPORT => self.color_transport,
            .AUTO => self.color_auto,
            .OUTPUT => self.color_output,
        };
    }

    /// The hue of each of the sixteen color LEDs: the eight of the top rows take the color of the page in use, and each encoder of the bottom
    /// row, which selects a page, takes the color of its own page, so that the pages can be told apart.
    pub fn pageHues(self: *const MftPreferences, active: MftActiveModule) [16]u8 {
        // (The FX SEL mode has its own frame, `fxsel_hues`.)
        var hues: [16]u8 = undefined;
        for (0..8) |i| hues[i] = self.colorForModule(active);
        for (0..8) |i| hues[8 + i] = self.colorForModule(@fromBackingInt(@intCast(i)));
        return hues;
    }

    /// The hue of each LED while the FX SEL mode is open: the buttons that choose a module (the input, the gate, the EQ, the compressor and the
    /// output) keep the color of their module, so that they can be told apart, and the others have the color of the mode.
    pub fn fxselHues(self: *const MftPreferences) [16]u8 {
        const fxsel = @import("mft_fxsel.zig");
        var hues: [16]u8 = @splat(self.color_fxsel);
        for (8..16) |encoder| {
            if (fxsel.moduleForEncoder(encoder) != null) hues[encoder] = self.colorForModule(@fromBackingInt(@intCast(encoder - 8)));
        }
        return hues;
    }

    pub fn setColorForModule(self: *MftPreferences, module: MftActiveModule, hue: u8) void {
        switch (module) {
            .INPUT => self.color_input = hue,
            .GATE => self.color_gate = hue,
            .EQ => self.color_eq = hue,
            .COMP => self.color_comp = hue,
            .SETTINGS => self.color_settings = hue,
            .TRANSPORT => self.color_transport = hue,
            .AUTO => self.color_auto = hue,
            .OUTPUT => self.color_output = hue,
        }
    }

    // Load preferences from <dir>/preferences.ini. Returns an error if the file
    // is absent so the caller can write the defaults. Plugin-name strings are
    // duped into the allocator.
    pub fn load(allocator: std.mem.Allocator, io: std.Io, dir: [:0]const u8) !MftPreferences {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{ dir, std.fs.path.sep_str, "preferences.ini" });

        const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
        defer file.close(io);

        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var file_buffer: [4096]u8 = undefined;
        var file_reader = file.reader(io, &file_buffer);
        var parser = ini.parse(temp_arena.allocator(), &file_reader.interface, ";#");
        defer parser.deinit();

        var self = MftPreferences{};
        try parse(&self, &parser, allocator);
        return self;
    }

    pub fn saveToDisk(self: *const MftPreferences, io: std.Io, dir: [:0]const u8) !void {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{ dir, std.fs.path.sep_str, "preferences.ini" });

        const file = try std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true });
        defer file.close(io);
        // Because file writers are buffered since Zig 0.15, the writer is flushed before the file closes.
        var w_buffer: [4096]u8 = undefined;
        var w_file_writer = file.writer(io, &w_buffer);
        const w = &w_file_writer.interface;

        try w.writeAll("; MFT preferences\n");
        try w.print("sensitivity = {d:.2}\n", .{self.sensitivity});
        try w.print("fine = {d:.2}\n", .{self.fine});
        try w.print("single_fx_mode = {s}\n", .{boolText(self.single_fx_mode)});
        try w.print("startup_message = {s}\n", .{boolText(self.startup_message)});
        try w.print("show_plugin_ui = {s}\n", .{boolText(self.show_plugin_ui)});
        try w.print("auto_insert = {s}\n", .{boolText(self.auto_insert)});
        try w.print("auto_insert_bypassed = {s}\n", .{boolText(self.auto_insert_bypassed)});
        try w.print("color_fxsel = {d}\n", .{self.color_fxsel});
        try w.print("color_input = {d}\n", .{self.color_input});
        try w.print("color_gate = {d}\n", .{self.color_gate});
        try w.print("color_eq = {d}\n", .{self.color_eq});
        try w.print("color_comp = {d}\n", .{self.color_comp});
        try w.print("color_settings = {d}\n", .{self.color_settings});
        try w.print("color_transport = {d}\n", .{self.color_transport});
        try w.print("color_auto = {d}\n", .{self.color_auto});
        try w.print("color_output = {d}\n\n", .{self.color_output});
        try w.print("[input]\n{s}\n\n", .{self.default_input});
        try w.print("[gate]\n{s}\n\n", .{self.default_gate});
        try w.print("[eq]\n{s}\n\n", .{self.default_eq});
        try w.print("[comp]\n{s}\n\n", .{self.default_comp});
        try w.print("[output]\n{s}\n\n", .{self.default_output});
        try w.print("[strip]\n{s}\n\n", .{self.default_strip});
        try w.flush();
    }
};

fn boolText(value: bool) []const u8 {
    return if (value) "true" else "false";
}

const Section = enum { none, input, gate, eq, comp, output, strip };

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
                } else if (std.mem.eql(u8, kv.key, "single_fx_mode")) {
                    self.single_fx_mode = std.mem.eql(u8, kv.value, "true");
                } else if (std.mem.eql(u8, kv.key, "fine")) {
                    self.fine = std.math.clamp(std.fmt.parseFloat(f32, kv.value) catch self.fine, 0.01, 1.0);
                } else if (std.mem.eql(u8, kv.key, "startup_message")) {
                    self.startup_message = std.mem.eql(u8, kv.value, "true");
                } else if (std.mem.eql(u8, kv.key, "show_plugin_ui")) {
                    self.show_plugin_ui = std.mem.eql(u8, kv.value, "true");
                } else if (std.mem.eql(u8, kv.key, "auto_insert")) {
                    self.auto_insert = std.mem.eql(u8, kv.value, "true");
                } else if (std.mem.eql(u8, kv.key, "auto_insert_bypassed")) {
                    self.auto_insert_bypassed = std.mem.eql(u8, kv.value, "true");
                } else if (std.mem.eql(u8, kv.key, "color_fxsel")) {
                    self.color_fxsel = std.fmt.parseInt(u8, kv.value, 10) catch self.color_fxsel;
                } else if (std.mem.eql(u8, kv.key, "color_io")) {
                    // Because the input and the output were one page in the older files, their color is the color of both.
                    self.color_input = std.fmt.parseInt(u8, kv.value, 10) catch self.color_input;
                    self.color_output = self.color_input;
                } else if (std.mem.eql(u8, kv.key, "color_input")) {
                    self.color_input = std.fmt.parseInt(u8, kv.value, 10) catch self.color_input;
                } else if (std.mem.eql(u8, kv.key, "color_output")) {
                    self.color_output = std.fmt.parseInt(u8, kv.value, 10) catch self.color_output;
                } else if (std.mem.eql(u8, kv.key, "color_auto")) {
                    self.color_auto = std.fmt.parseInt(u8, kv.value, 10) catch self.color_auto;
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
                const owned = allocator.dupeSentinel(u8, value, 0) catch continue;
                switch (section) {
                    .strip => self.default_strip = owned,
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
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();

    var prefs = MftPreferences{};
    try parse(&prefs, &parser, t.allocator);
    defer {
        t.allocator.free(prefs.default_input);
        t.allocator.free(prefs.default_eq);
    }

    try t.expectApproxEqAbs(@as(f32, 2.5), prefs.sensitivity, 0.001);
    // The color of the one page of the older files is the color of the input and of the output.
    try t.expectEqual(@as(u8, 20), prefs.color_input);
    try t.expectEqual(@as(u8, 20), prefs.color_output);
    try t.expectEqual(@as(u8, 60), prefs.color_eq);
    try t.expectEqualStrings("JS: My Input", prefs.default_input);
    try t.expectEqualStrings("VST: My EQ", prefs.default_eq);
    // Unspecified fields keep their defaults.
    try t.expectEqual(@as(u8, 0x62), prefs.color_gate);
}

test "pageHues: the top rows have the color of the active page and the bottom row the color of each page" {
    const t = std.testing;
    var prefs = MftPreferences{};
    prefs.color_eq = 11;
    prefs.color_output = 22;
    const hues = prefs.pageHues(.EQ);
    try t.expectEqual(@as(u8, 11), hues[0]);
    try t.expectEqual(@as(u8, 11), hues[7]);
    try t.expectEqual(prefs.color_input, hues[8]);
    try t.expectEqual(@as(u8, 11), hues[10]);
    try t.expectEqual(@as(u8, 22), hues[15]);
}

test "MftPreferences: the channel strip mode and its plugin are read" {
    const t = std.testing;
    const example =
        \\single_fx_mode = true
        \\
        \\[strip]
        \\JS: Lumina Channel Strip
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();
    var prefs = MftPreferences{};
    try parse(&prefs, &parser, t.allocator);
    defer t.allocator.free(prefs.default_strip);
    try t.expect(prefs.single_fx_mode);
    try t.expectEqualStrings("JS: Lumina Channel Strip", prefs.default_strip);
    // Without the lines, the mode is off and no strip is named.
    try t.expect(!(MftPreferences{}).single_fx_mode);
}

test "fxselHues: the module buttons keep their colors, and the other encoders have the color of the mode" {
    const t = std.testing;
    var prefs = MftPreferences{};
    prefs.color_gate = 33;
    prefs.color_output = 44;
    const hues = prefs.fxselHues();
    const mode_hue = @import("mft_fxsel.zig").hue;
    try t.expectEqual(mode_hue, hues[0]);
    try t.expectEqual(mode_hue, hues[7]);
    try t.expectEqual(prefs.color_input, hues[8]);
    try t.expectEqual(@as(u8, 33), hues[9]);
    try t.expectEqual(prefs.color_eq, hues[10]);
    try t.expectEqual(prefs.color_comp, hues[11]);
    // The settings, transport and AUTO encoders have no module to choose.
    try t.expectEqual(mode_hue, hues[12]);
    try t.expectEqual(mode_hue, hues[13]);
    try t.expectEqual(mode_hue, hues[14]);
    try t.expectEqual(@as(u8, 44), hues[15]);
}

test "MftPreferences: the options of the settings panel are read, and kept in their ranges" {
    const t = std.testing;
    const example =
        \\fine = 5
        \\startup_message = true
        \\show_plugin_ui = true
        \\auto_insert = false
        \\auto_insert_bypassed = true
        \\color_fxsel = 77
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();
    var prefs = MftPreferences{};
    try parse(&prefs, &parser, t.allocator);
    try t.expectEqual(@as(f32, 1.0), prefs.fine);
    try t.expect(prefs.startup_message and prefs.show_plugin_ui and !prefs.auto_insert and prefs.auto_insert_bypassed);
    try t.expectEqual(@as(u8, 77), prefs.color_fxsel);
    try t.expectEqual(@as(u8, 77), prefs.fxselHues()[0]);
    // Without the lines, the controller inserts plugins, not bypassed, and the fine step is a tenth.
    const defaults = MftPreferences{};
    try t.expect(defaults.auto_insert and !defaults.auto_insert_bypassed);
    try t.expectEqual(@as(f32, 0.1), defaults.fine);
}
