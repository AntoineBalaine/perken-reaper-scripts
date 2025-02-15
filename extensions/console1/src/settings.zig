const std = @import("std");
const ini = @import("ini");
const mappings_mod = @import("mappings.zig");
const FxMap = mappings_mod.FxMap;
const ModulesList = @import("statemachine.zig").ModulesList; // Changed from mappings_mod.FxMap
const log = std.log.scoped(.preferences);
const fs_helpers = @import("fs_helpers.zig");

// Hard-coded fallback defaults as EnumMap
const fallback_defaults = std.EnumMap(ModulesList, [:0]const u8).init(.{
    .INPUT = "JS: Volume/Pan Smoother v5",
    .GATE = "VST: ReaGate (Cockos)",
    .EQ = "VST: ReaEQ (Cockos)",
    .COMP = "VST: ReaComp (Cockos)",
    .OUTPT = "JS: Saturation",
});

pub const DefaultFx = std.EnumArray(ModulesList, ?[:0]const u8);
pub const Preferences = @This();

pub const SettingsFields = enum {
    show_startup_message,
    show_feedback_window,
    show_plugin_ui,
    manual_routing,
    log_to_file,
    start_suspended,
    // Module combos start at 7
    default_INPUT,
    default_GATE,
    default_COMP,
    default_EQ,
    default_OUTPT,
    // ... other fields

    pub fn fromIndex(index: u8) ?SettingsFields {
        return std.meta.intToEnum(SettingsFields, index) catch null;
    }
};

// Data
show_startup_message: bool = false,
show_feedback_window: bool = false,
show_plugin_ui: bool = false,
manual_routing: bool = false,
default_fx: DefaultFx,
log_to_file: bool = false,
start_suspended: bool = false,
show_track_list: bool = true,
focus_page_tracks: bool = false,

pub fn init(arena: std.mem.Allocator, resource_path: [:0]const u8) !Preferences {
    var self = Preferences{
        .default_fx = DefaultFx.initUndefined(),
    };

    // Always start by copying fallback defaults
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const fallback = fallback_defaults.get(module).?;
        const owned_copy = try arena.dupeZ(u8, fallback);
        self.default_fx.set(module, owned_copy);
    }

    // Try to load preferences from disk
    self.load(resource_path, arena) catch |err| {
        log.warn("Failed to load preferences: {s} at {s}, using copied defaults", .{ @errorName(err), resource_path });
    };

    return self;
}

fn load(self: *Preferences, resource_path: [:0]const u8, arena: std.mem.Allocator) !void {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = fs_helpers.joinStrings(&path_buffer, &.{
        resource_path,
        std.fs.path.sep_str,
        "preferences.ini",
    });

    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();
    var parser = ini.parse(temp_arena.allocator(), file.reader());
    try self.parsePreferences(&parser, arena);
}

pub fn saveToDisk(self: *Preferences, resource_path: [:0]const u8) !void {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = fs_helpers.joinStrings(&path_buffer, &.{
        resource_path,
        std.fs.path.sep_str,
        "preferences.ini",
    });

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
                if (!(std.mem.eql(u8, field.name, "default_fx"))) {
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
            if (self.default_fx.get(module)) |module_fx| module_fx else "",
        });
    }
}

pub fn parsePreferences(self: *Preferences, parser: anytype, arena: std.mem.Allocator) !void {
    var cur_section: ?ModulesList = null;

    while (try parser.*.next()) |record| {
        switch (record) {
            .section => |heading| {
                // Handle module sections (INPUT, GATE, etc.)
                cur_section = std.meta.stringToEnum(ModulesList, heading) orelse {
                    log.warn("Invalid section in preferences: {s}", .{heading});
                    continue;
                };
            },
            .property => |prop| {
                // Handle top-level properties when not in a module section
                if (cur_section == null) {

                    // Set the preference value based on its type
                    inline for (std.meta.fields(Preferences)) |field| {
                        if (std.mem.eql(u8, field.name, prop.key)) {
                            switch (field.type) {
                                bool => {
                                    @field(self, field.name) =
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
                    // Allocate and store new value
                    if (std.mem.eql(u8, value, "")) {
                        self.default_fx.set(module, null);
                        // log.warn("Empty value in preferences for {s}", .{@tagName(module)});
                    } else {
                        const value_copy = try arena.dupeZ(u8, value);
                        self.default_fx.set(module, value_copy);
                    }
                }
            },
        }
    }
}

pub fn toggleField(self: *@This(), field: SettingsFields) void {
    switch (field) {
        .show_startup_message => self.show_startup_message = !self.show_startup_message,
        .show_feedback_window => self.show_feedback_window = !self.show_feedback_window,
        .show_plugin_ui => self.show_plugin_ui = !self.show_plugin_ui,
        .manual_routing => self.manual_routing = !self.manual_routing,
        .log_to_file => self.log_to_file = !self.log_to_file,
        .start_suspended => self.start_suspended = !self.start_suspended,
        // Handle combo boxes differently
        else => {},
    }
}

test {
    std.testing.refAllDecls(@This());
}

test "preferences - fallback defaults when file not found" {
    const testing = std.testing;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize with non-existent path
    var prefs = try Preferences.init(allocator, "/path/that/does/not/exist");

    // Test that fallback values are used
    try testing.expect(prefs.show_startup_message == false);
    try testing.expect(prefs.show_feedback_window == false);
    try testing.expect(prefs.show_plugin_ui == false);
    try testing.expect(prefs.manual_routing == false);

    // Test that fallback defaults were copied
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.INPUT).?, "JS: Volume/Pan Smoother v5"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.GATE).?, "VST: ReaGate (Cockos)"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.EQ).?, "VST: ReaEQ (Cockos)"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.COMP).?, "VST: ReaComp (Cockos)"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.OUTPT).?, "JS: Saturation"));
}

test "preferences - load from current directory" {
    const testing = std.testing;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get current directory path
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpathZ(".", &mem);

    const path_z = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const path = try allocator.dupeZ(u8, path_z);

    // Initialize preferences with current directory
    var prefs = try Preferences.init(allocator, path);

    // Test loaded values
    // Note: These values should match what's in your preferences.ini
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.INPUT).?, "JS: Volume/Pan Smoother v5"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.GATE).?, "VST: ReaGate (Cockos)"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.EQ).?, "VST: ReaEQ (Cockos)"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.COMP).?, "VST: ReaComp (Cockos)"));
    try testing.expect(std.mem.eql(u8, prefs.default_fx.get(.OUTPT).?, "JS: Saturation"));

    // Test boolean preferences
    // These should match your preferences.ini values
    try testing.expect(prefs.show_startup_message == true);
    try testing.expect(prefs.show_feedback_window == true);
    try testing.expect(prefs.show_plugin_ui == true);
    try testing.expect(prefs.manual_routing == true);
}

test "preferences - save and restore" {
    const testing = std.testing;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get current directory path
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const path_z = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const path = try allocator.dupeZ(u8, path_z);

    // First load current preferences to save them
    var original_prefs = try Preferences.init(allocator, path);

    // Create new preferences with different values
    var test_prefs = try Preferences.init(allocator, path);

    // Modify all boolean values to their opposite
    test_prefs.show_startup_message = !original_prefs.show_startup_message;
    test_prefs.show_feedback_window = !original_prefs.show_feedback_window;
    test_prefs.show_plugin_ui = !original_prefs.show_plugin_ui;
    test_prefs.manual_routing = !original_prefs.manual_routing;

    // Save modified preferences
    try test_prefs.saveToDisk(path);

    // Load preferences again to verify changes
    var verify_prefs = try Preferences.init(allocator, path);

    // Verify that values were changed
    try testing.expect(verify_prefs.show_startup_message == !original_prefs.show_startup_message);
    try testing.expect(verify_prefs.show_feedback_window == !original_prefs.show_feedback_window);
    try testing.expect(verify_prefs.show_plugin_ui == !original_prefs.show_plugin_ui);
    try testing.expect(verify_prefs.manual_routing == !original_prefs.manual_routing);

    // Verify that module defaults remained unchanged
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const verify_default = verify_prefs.default_fx.get(module);
        const original_default = original_prefs.default_fx.get(module);
        if (verify_default == null) {
            try testing.expect(original_default == null);
        } else {
            try testing.expect(std.mem.eql(u8, verify_default.?, original_default.?));
        }
    }

    // Restore original preferences
    try original_prefs.saveToDisk(path);

    // Verify restoration
    const final_verify = try Preferences.init(allocator, path);

    try testing.expect(final_verify.show_startup_message == original_prefs.show_startup_message);
    try testing.expect(final_verify.show_feedback_window == original_prefs.show_feedback_window);
    try testing.expect(final_verify.show_plugin_ui == original_prefs.show_plugin_ui);
    try testing.expect(final_verify.manual_routing == original_prefs.manual_routing);
}
