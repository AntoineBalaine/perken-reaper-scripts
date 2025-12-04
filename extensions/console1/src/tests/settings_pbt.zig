const std = @import("std");
const testing = std.testing;
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const StatefulConfig = zlowcheck.StatefulConfig;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

const Preferences = @import("../settings.zig");
const SettingsPanel = @import("../settings_panel.zig");
const SettingsActions = @import("../settings_actions.zig").SettingsActions;
const settingsActions = @import("../settings_actions.zig").settingsActions;
const Globals = @import("../globals.zig").Globals;
const Mode = @import("../statemachine.zig").Mode;
const ModulesList = @import("../statemachine.zig").ModulesList;
const ModulesOrder = @import("../fx_ctrl_state.zig").ModulesOrder;
const test_setup = @import("mode_switch_tests.zig").test_setup;
const reaper = @import("../reaper.zig").reaper;

fn getTestConfigPath(allocator: std.mem.Allocator) ![*:0]const u8 {
    var path_mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &path_mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    return try allocator.dupeZ(u8, config_path);
}

// Model tracks the expected state of settings
const Model = struct {
    default_prefs: Preferences,
    preferences: Preferences,
    temp_settings: Preferences,
    panel_open: bool,
    panel_dirty: bool,
    scroll_position_rel: u8,
    scroll_position_abs: u8,

    pub fn init(globals: *Globals) !@This() {
        // Copy the defaults from globals (which has fallback_defaults already populated)
        const defaults = globals.preferences;
        return .{
            .default_prefs = defaults,
            .preferences = defaults,
            .temp_settings = defaults,
            .panel_open = false,
            .panel_dirty = false,
            .scroll_position_rel = 0,
            .scroll_position_abs = 0,
        };
    }

    pub fn reset(self: *@This()) void {
        // Reset to default state - just struct copy
        self.preferences = self.default_prefs;
        self.temp_settings = self.default_prefs;
        self.panel_open = false;
        self.panel_dirty = false;
        self.scroll_position_rel = 0;
        self.scroll_position_abs = 0;
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

// System wraps the actual Globals implementation
const System = struct {
    globals: *Globals,
    resource_path: [:0]const u8,
    default_prefs: Preferences,

    pub fn init(globals: *Globals, resource_path: [:0]const u8) !@This() {
        const defaults = globals.preferences;
        return .{
            .globals = globals,
            .resource_path = resource_path,
            .default_prefs = defaults,
        };
    }

    pub fn reset(self: *@This()) void {
        self.globals.settings_panel = null;
        self.globals.preferences = self.default_prefs;
        self.globals.state.current_mode = .fx_ctrl;
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

// Commands

const OpenCmd = struct {
    pub const name = "Open";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can only open if not already open
        return !model.panel_open;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.panel_open = true;
        model.panel_dirty = false;
        model.scroll_position_rel = 0;
        model.scroll_position_abs = 0;
        // Copy preferences to temp_settings
        model.temp_settings = model.preferences;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute open action
        settingsActions(sut.globals, .open);

        // Update model
        self.onModelOnly(model);

        // Verify panel is open
        return sut.globals.settings_panel != null and
            sut.globals.state.current_mode == .settings;
    }
};

const ScrollCmd = struct {
    new_pos: u8,

    pub const name = "Scroll";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can only scroll if panel is open
        return model.panel_open;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Scroll doesn't affect persistent state, just UI state
        // Because calculateNewScrollPosition has complex encoder wrapping logic with max_increment,
        // we don't track scroll positions in the model
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute scroll action
        settingsActions(sut.globals, .{ .scroll = self.new_pos });

        // Update model (no-op)
        self.onModelOnly(model);

        // Verify scroll absolute position was updated
        if (sut.globals.settings_panel) |panel| {
            return panel.scroll_position_abs == self.new_pos;
        }
        return false;
    }
};

const ToggleCmd = struct {
    pub const name = "Toggle";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can only toggle if panel is open
        return model.panel_open;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        // Toggle the field at current scroll position in temp_settings
        if (Preferences.SettingsFields.fromIndex(model.scroll_position_rel)) |field| {
            switch (field) {
                .show_startup_message => {
                    model.temp_settings.show_startup_message = !model.temp_settings.show_startup_message;
                    model.panel_dirty = true;
                },
                .show_feedback_window => {
                    model.temp_settings.show_feedback_window = !model.temp_settings.show_feedback_window;
                    model.panel_dirty = true;
                },
                .show_plugin_ui => {
                    model.temp_settings.show_plugin_ui = !model.temp_settings.show_plugin_ui;
                    model.panel_dirty = true;
                },
                .manual_routing => {
                    model.temp_settings.manual_routing = !model.temp_settings.manual_routing;
                    model.panel_dirty = true;
                },
                .log_to_file => {
                    model.temp_settings.log_to_file = !model.temp_settings.log_to_file;
                    model.panel_dirty = true;
                },
                .start_suspended => {
                    model.temp_settings.start_suspended = !model.temp_settings.start_suspended;
                    model.panel_dirty = true;
                },
                .auto_insert_modules => {
                    model.temp_settings.auto_insert_modules = !model.temp_settings.auto_insert_modules;
                    model.panel_dirty = true;
                },
                .auto_insert_bypassed => {
                    model.temp_settings.auto_insert_bypassed = !model.temp_settings.auto_insert_bypassed;
                    model.panel_dirty = true;
                },
                .auto_reorder_modules => {
                    model.temp_settings.auto_reorder_modules = !model.temp_settings.auto_reorder_modules;
                    model.panel_dirty = true;
                },
                // default_XXX fields trigger mode change, don't toggle in model
                .default_INPUT, .default_GATE, .default_COMP, .default_EQ, .default_OUTPT => {},
                // language and preferred_module_order are not toggleable
                else => {},
            }
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Save initial mode
        const initial_mode = sut.globals.state.current_mode;

        // Execute toggle action
        settingsActions(sut.globals, .toggle);

        // Check if we're toggling a default FX field
        if (Preferences.SettingsFields.fromIndex(model.scroll_position_rel)) |field| {
            switch (field) {
                .default_INPUT, .default_GATE, .default_COMP, .default_EQ, .default_OUTPT => {
                    // Because default FX toggle changes mode to default_fx_sel, verify mode changed
                    // but don't update model (mode change is tested separately)
                    return sut.globals.state.current_mode == .default_fx_sel;
                },
                else => {
                    // Update model
                    self.onModelOnly(model);

                    // Verify panel is still open and state is correct
                    if (sut.globals.settings_panel) |panel| {
                        // Check that the specific field was toggled correctly
                        const field_matches = switch (field) {
                            .show_startup_message => panel.temp_settings.show_startup_message == model.temp_settings.show_startup_message,
                            .show_feedback_window => panel.temp_settings.show_feedback_window == model.temp_settings.show_feedback_window,
                            .show_plugin_ui => panel.temp_settings.show_plugin_ui == model.temp_settings.show_plugin_ui,
                            .manual_routing => panel.temp_settings.manual_routing == model.temp_settings.manual_routing,
                            .log_to_file => panel.temp_settings.log_to_file == model.temp_settings.log_to_file,
                            .start_suspended => panel.temp_settings.start_suspended == model.temp_settings.start_suspended,
                            .auto_insert_modules => panel.temp_settings.auto_insert_modules == model.temp_settings.auto_insert_modules,
                            .auto_insert_bypassed => panel.temp_settings.auto_insert_bypassed == model.temp_settings.auto_insert_bypassed,
                            .auto_reorder_modules => panel.temp_settings.auto_reorder_modules == model.temp_settings.auto_reorder_modules,
                            // Non-toggleable fields (language, preferred_module_order)
                            else => true,
                        };

                        return sut.globals.state.current_mode == initial_mode and
                            panel.dirty == model.panel_dirty and
                            field_matches;
                    }
                    return false;
                },
            }
        }
        return false;
    }
};

const UpdateValCmd = struct {
    field: Preferences.SettingsFields,
    value: union(enum) {
        bool_val: bool,
        string_val: [:0]const u8,
        enum_val: ModulesOrder,
    },

    pub const name = "UpdateVal";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can only update if panel is open
        return model.panel_open;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // UpdateVal modifies temp_settings
        switch (self.value) {
            .bool_val => |val| {
                switch (self.field) {
                    .show_startup_message => model.temp_settings.show_startup_message = val,
                    .show_feedback_window => model.temp_settings.show_feedback_window = val,
                    .show_plugin_ui => model.temp_settings.show_plugin_ui = val,
                    .manual_routing => model.temp_settings.manual_routing = val,
                    .log_to_file => model.temp_settings.log_to_file = val,
                    .start_suspended => model.temp_settings.start_suspended = val,
                    .auto_insert_modules => model.temp_settings.auto_insert_modules = val,
                    .auto_insert_bypassed => model.temp_settings.auto_insert_bypassed = val,
                    .auto_reorder_modules => model.temp_settings.auto_reorder_modules = val,
                    else => {},
                }
            },
            .string_val => |val| {
                if (self.field == .language) {
                    model.temp_settings.language = val;
                }
            },
            .enum_val => |val| {
                if (self.field == .preferred_module_order) {
                    model.temp_settings.preferred_module_order = val;
                }
            },
        }
        model.panel_dirty = true;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Build SettingsValUpdate
        const val_update = switch (self.value) {
            .bool_val => |val| SettingsPanel.SettingsValUpdate{ .bool_val = .{ .field = self.field, .val = val } },
            .string_val => |val| SettingsPanel.SettingsValUpdate{ .string_val = .{ .field = self.field, .val = val } },
            .enum_val => |val| SettingsPanel.SettingsValUpdate{ .enum_val = .{ .field = self.field, .val = val } },
        };

        // Execute update action
        settingsActions(sut.globals, .{ .update_val = val_update });

        // Update model
        self.onModelOnly(model);

        // Verify the value was updated in temp_settings
        if (sut.globals.settings_panel) |panel| {
            const matches = switch (self.value) {
                .bool_val => |val| blk: {
                    const actual = switch (self.field) {
                        .show_startup_message => panel.temp_settings.show_startup_message,
                        .show_feedback_window => panel.temp_settings.show_feedback_window,
                        .show_plugin_ui => panel.temp_settings.show_plugin_ui,
                        .manual_routing => panel.temp_settings.manual_routing,
                        .log_to_file => panel.temp_settings.log_to_file,
                        .start_suspended => panel.temp_settings.start_suspended,
                        .auto_insert_modules => panel.temp_settings.auto_insert_modules,
                        .auto_insert_bypassed => panel.temp_settings.auto_insert_bypassed,
                        .auto_reorder_modules => panel.temp_settings.auto_reorder_modules,
                        else => return false,
                    };
                    break :blk actual == val;
                },
                .string_val => |val| blk: {
                    if (self.field == .language) {
                        break :blk std.mem.eql(u8, panel.temp_settings.language, val);
                    }
                    break :blk false;
                },
                .enum_val => |val| blk: {
                    if (self.field == .preferred_module_order) {
                        break :blk panel.temp_settings.preferred_module_order == val;
                    }
                    break :blk false;
                },
            };
            return matches and panel.dirty;
        }
        return false;
    }
};

const SaveCmd = struct {
    pub const name = "Save";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can only save if panel is open
        return model.panel_open;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        // Save closes the panel and commits changes to preferences
        model.preferences = model.temp_settings;
        model.panel_open = false;
        model.panel_dirty = false;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute save action
        settingsActions(sut.globals, .save);

        // Update model
        self.onModelOnly(model);

        // Verify panel is closed, mode returned to fx_ctrl, and preferences were saved
        if (sut.globals.settings_panel != null) return false;
        if (sut.globals.state.current_mode != .fx_ctrl) return false;

        // Verify that preferences match what we expect from the model
        const rv = std.meta.eql(sut.globals.preferences, model.preferences);
        return rv;
    }
};

const CancelCmd = struct {
    pub const name = "Cancel";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // Can only cancel if panel is open
        return model.panel_open;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        // Cancel closes the panel without committing changes
        model.panel_open = false;
        model.panel_dirty = false;
        // Note: preferences in model remain at last saved state
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Save old preferences to verify they weren't changed
        const old_prefs = sut.globals.preferences;

        // Execute cancel action
        settingsActions(sut.globals, .cancel);

        // Update model
        self.onModelOnly(model);

        // Verify panel is closed, mode returned to fx_ctrl, and preferences unchanged
        return sut.globals.settings_panel == null and
            sut.globals.state.current_mode == .fx_ctrl and
            std.meta.eql(sut.globals.preferences, old_prefs);
    }
};

fn settingsStatefulTest(_: void, input: []const u8) !void {
    var g_teardown = try test_setup(testing.allocator);
    defer g_teardown.teardown();

    const globals = g_teardown.globals;

    // Initialize MIDI output for the test
    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);

    // Initialize control surface
    _ = @import("../csurf/control_surface.zig").init(0, 0, null);

    // Set initial mode to fx_ctrl
    globals.state.current_mode = .fx_ctrl;

    // Get resource path for system initialization
    // const resource_path = try getTestConfigPath(testing.allocator);
    // defer testing.allocator.free(resource_path);

    // Allocate and copy fuzz data
    const fuzz_data = testing.allocator.alloc(u8, input.len) catch return error.SkipZigTest;
    defer testing.allocator.free(fuzz_data);
    @memcpy(fuzz_data, input);

    // Initialize PRNG with fuzz data
    var prng = FinitePrng.init(fuzz_data);
    var random = prng.random();

    // Create command instances
    var openCmd = OpenCmd{};
    var saveCmd = SaveCmd{};
    var cancelCmd = CancelCmd{};
    var toggleCmd = ToggleCmd{};

    // Create commands array
    const commands = [_]Command(Model, System){
        Command(Model, System).init(&openCmd),
        Command(Model, System).init(&saveCmd),
        Command(Model, System).init(&cancelCmd),
        Command(Model, System).init(&toggleCmd),
    };

    // Create command sequence
    var cmd_seq = CommandList(Model, System).init(
        &commands,
        &random,
        50,
        testing.allocator,
    ) catch |err| {
        if (err == FinitePrng.FinitePrngErr.OutOfEntropy) {
            std.debug.print("OutOfEntropy during CommandList.init\n", .{});
            return;
        }
        return err;
    };
    defer cmd_seq.deinit(testing.allocator);

    // Initialize model and system
    var model = try Model.init(globals);
    defer model.deinit();

    var system = try System.init(globals, "");

    // Run stateful test
    const rv = assertStateful(
        Model,
        System,
        &cmd_seq,
        &model,
        &system,
        .{ .verbose = true },
    ) catch |err| {
        if (err == FinitePrng.FinitePrngErr.OutOfEntropy) {
            // Note: We can't access the internal command count directly from CommandList
            // The verbose flag in assertStateful will print details during execution
            return;
        }
        return err;
    };

    if (rv) |failure| {
        std.debug.print("\nFailure details: {any}\n", .{failure});
        return error.TestFailed;
    }

    try testing.expect(rv == null);
}

test "settings stateful - with random bytes" {
    var seed_prng = std.Random.DefaultPrng.init(0x8BBE022C870AF654);
    var random_bytes: [4096]u8 = undefined;
    seed_prng.random().bytes(&random_bytes);

    try settingsStatefulTest({}, &random_bytes);
}

test settingsStatefulTest {
    try std.testing.fuzz({}, settingsStatefulTest, .{});
}
