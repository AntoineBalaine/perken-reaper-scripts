const std = @import("std");
const ini = @import("ini");
const mappings_mod = @import("internals/mappings.zig");
const FxMap = mappings_mod.FxMap;
const ModulesList = @import("internals/config.zig").ModulesList; // Changed from mappings_mod.FxMap
const UserSettings = @import("internals/userPrefs.zig").UserSettings;
const logger = @import("logger.zig");

// Hard-coded fallback defaults as EnumMap
const fallback_defaults = std.EnumMap(ModulesList, [:0]const u8).init(.{
    .INPUT = "JS: Volume/Pan Smoother",
    .GATE = "VST: ReaGate (Cockos)",
    .EQ = "VST: ReaEQ (Cockos)",
    .COMP = "VST: ReaComp (Cockos)",
    .OUTPT = "JS: Saturation",
});

pub const DefaultFx = std.EnumArray(ModulesList, [:0]const u8);
const Preferences = @This();

// Data
show_startup_message: bool = false,
show_feedback_window: bool = false,
show_plugin_ui: bool = false,
manual_routing: bool = false,
default_fx: DefaultFx,

// Resource management
allocator: std.mem.Allocator,
resource_path: []const u8,

pub fn init(allocator: std.mem.Allocator, resource_path: []const u8) !Preferences {
    var self = Preferences{
        .allocator = allocator,
        .resource_path = try allocator.dupe(u8, resource_path),
        .default_fx = DefaultFx.initUndefined(),
    };

    // Always start by copying fallback defaults
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const fallback = fallback_defaults.get(module).?;
        const owned_copy = try allocator.dupeZ(u8, fallback);
        self.default_fx.set(module, owned_copy);
    }

    // Try to load preferences from disk
    self.load() catch |err| {
        logger.log(.warning, "Failed to load preferences: {s}, using copied defaults", .{@errorName(err)}, null, allocator);
    };

    return self;
}

pub fn deinit(self: *Preferences) void {
    // Free all strings in default_fx - they're all allocated copies
    for (std.enums.values(ModulesList)) |module| {
        self.allocator.free(self.default_fx.get(module));
    }
    self.allocator.free(self.resource_path);
}

fn load(self: *Preferences) !void {
    const path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.resource_path, "preferences.ini" });
    defer self.allocator.free(path);

    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    var parser = ini.parse(self.allocator, file.reader());
    defer parser.deinit();
    try self.parsePreferences(&parser);
}

pub fn save(self: *Preferences) !void {
    const path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.resource_path, "preferences.ini" });
    defer self.allocator.free(path);

    const file = try std.fs.createFileAbsolute(path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    var writer = file.writer();

    // Write top-level preferences first
    try writer.writeAll("; Console1 Preferences\n");

    // Use comptime field iteration to write boolean settings
    inline for (std.meta.fields(Preferences)) |field| {
        switch (field.type) {
            bool => {
                // Skip resource management fields
                if (!(std.mem.eql(u8, field.name, "allocator") or
                    std.mem.eql(u8, field.name, "resource_path") or
                    std.mem.eql(u8, field.name, "default_fx")))
                {
                    try writer.print(
                        "{s} = {s}\n",
                        .{
                            field.name,
                            if (@field(self, field.name)) "true" else "false",
                        },
                    );
                }
            },
            else => {},
        }
    }

    try writer.writeAll("\n");

    // Write module defaults
    inline for (comptime std.enums.values(ModulesList)) |module| {
        try writer.print("[{s}]\n{s}\n\n", .{
            @tagName(module),
            self.default_fx.get(module),
        });
    }
}

pub fn parsePreferences(prefs: *Preferences, parser: anytype) !void {
    var cur_section: ?ModulesList = null;

    while (try parser.*.next()) |record| {
        switch (record) {
            .section => |heading| {
                // Handle module sections (INPUT, GATE, etc.)
                cur_section = std.meta.stringToEnum(ModulesList, heading) orelse {
                    logger.log(
                        .warning,
                        "Invalid section in preferences: {s}",
                        .{heading},
                        null,
                        prefs.allocator,
                    );
                    continue;
                };
            },
            .property => |prop| {
                // Handle top-level properties when not in a module section
                if (cur_section == null) {
                    // Use @hasField to check if property exists in Preferences
                    // if (!@hasField(Preferences, prop.key)) {
                    //     logger.log(
                    //         .warning,
                    //         "Unknown preference: {s}",
                    //         .{prop.key},
                    //         null,
                    //         prefs.allocator,
                    //     );
                    //     continue;
                    // }

                    // Set the preference value based on its type
                    inline for (std.meta.fields(Preferences)) |field| {
                        if (std.mem.eql(u8, field.name, prop.key)) {
                            switch (field.type) {
                                bool => {
                                    @field(prefs, field.name) =
                                        std.mem.eql(u8, prop.value, "true");
                                },
                                // Add other types as needed
                                else => {},
                            }
                        }
                    }
                }
            },
            .enumeration => |value| {
                // Handle FX assignments in module sections
                if (cur_section) |module| {
                    prefs.allocator.free(prefs.default_fx.get(module));
                    // Allocate and store new value
                    const value_copy = try prefs.allocator.dupeZ(u8, value);
                    prefs.default_fx.set(module, value_copy);
                }
            },
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}

test "preferences - fallback defaults when file not found" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    // Initialize with non-existent path
    var prefs = try Preferences.init(allocator, "/path/that/does/not/exist");
    defer prefs.deinit();

    // Test that fallback values are used
    try expect(prefs.show_startup_message == false);
    try expect(prefs.show_feedback_window == false);
    try expect(prefs.show_plugin_ui == false);
    try expect(prefs.manual_routing == false);

    // Test that fallback defaults were copied
    try expect(std.mem.eql(u8, prefs.default_fx.get(.INPUT), "JS: Volume/Pan Smoother"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.GATE), "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.EQ), "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.COMP), "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.OUTPT), "JS: Saturation"));
}

test "preferences - load from current directory" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    // Get current directory path
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    defer allocator.free(path);

    // Initialize preferences with current directory
    var prefs = try Preferences.init(allocator, path);
    defer prefs.deinit();

    // Test loaded values
    // Note: These values should match what's in your preferences.ini
    try expect(std.mem.eql(u8, prefs.default_fx.get(.INPUT), "JS: Volume/Pan Smoother"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.GATE), "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.EQ), "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.COMP), "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(u8, prefs.default_fx.get(.OUTPT), "JS: Saturation"));

    // Test boolean preferences
    // These should match your preferences.ini values
    try expect(prefs.show_startup_message == true);
    try expect(prefs.show_feedback_window == true);
    try expect(prefs.show_plugin_ui == true);
    try expect(prefs.manual_routing == true);
}

test "preferences - save and restore" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    // Get current directory path
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    defer allocator.free(path);

    // First load current preferences to save them
    var original_prefs = try Preferences.init(allocator, path);
    defer original_prefs.deinit();

    // Create new preferences with different values
    var test_prefs = try Preferences.init(allocator, path);
    defer test_prefs.deinit();

    // Modify all boolean values to their opposite
    test_prefs.show_startup_message = !original_prefs.show_startup_message;
    test_prefs.show_feedback_window = !original_prefs.show_feedback_window;
    test_prefs.show_plugin_ui = !original_prefs.show_plugin_ui;
    test_prefs.manual_routing = !original_prefs.manual_routing;

    // Save modified preferences
    try test_prefs.save();

    // Load preferences again to verify changes
    var verify_prefs = try Preferences.init(allocator, path);
    defer verify_prefs.deinit();

    // Verify that values were changed
    try expect(verify_prefs.show_startup_message == !original_prefs.show_startup_message);
    try expect(verify_prefs.show_feedback_window == !original_prefs.show_feedback_window);
    try expect(verify_prefs.show_plugin_ui == !original_prefs.show_plugin_ui);
    try expect(verify_prefs.manual_routing == !original_prefs.manual_routing);

    // Verify that module defaults remained unchanged
    inline for (comptime std.enums.values(ModulesList)) |module| {
        try expect(std.mem.eql(u8, verify_prefs.default_fx.get(module), original_prefs.default_fx.get(module)));
    }

    // Restore original preferences
    try original_prefs.save();

    // Verify restoration
    var final_verify = try Preferences.init(allocator, path);
    defer final_verify.deinit();

    try expect(final_verify.show_startup_message == original_prefs.show_startup_message);
    try expect(final_verify.show_feedback_window == original_prefs.show_feedback_window);
    try expect(final_verify.show_plugin_ui == original_prefs.show_plugin_ui);
    try expect(final_verify.manual_routing == original_prefs.manual_routing);
}
