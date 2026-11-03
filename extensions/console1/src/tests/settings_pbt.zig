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
const reaper = @import("reaper").reaper;
const getTestConfigPath = @import("track_validation_pbt.zig").getTestConfigPath;

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
        // Because calculateNewScrollPosition has complex encoder wrapping logic, we do not
        // replicate it in the model. Instead, onPair synchronizes the model from the system
        // after the scroll executes.
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute scroll action
        settingsActions(sut.globals, .{ .scroll = self.new_pos });

        // Verify the panel is still open and the absolute position was updated
        if (sut.globals.settings_panel) |panel| {
            if (panel.scroll_position_abs != self.new_pos) {
                return false;
            }
            // Because we cannot replicate the scroll wrapping logic in the model, we
            // synchronize the model's scroll positions from the system after verification.
            // This way, subsequent commands (like Toggle) use the correct field index.
            model.scroll_position_abs = panel.scroll_position_abs;
            model.scroll_position_rel = panel.scroll_position_rel;
            return true;
        }
        return false;
    }
};

const ToggleCmd = struct {
    pub const name = "Toggle";

    pub fn checkPrecondition(self: *@This(), model: *Model) bool {
        _ = self;
        // We can only toggle if the panel is open and the current field is not a default_XXX
        // field, because toggling a default_XXX field triggers a mode change to default_fx_sel
        // which we cannot model in this test (we have no "return from default_fx_sel" command).
        if (!model.panel_open) return false;
        if (Preferences.SettingsFields.fromIndex(model.scroll_position_rel)) |field| {
            return switch (field) {
                .default_INPUT, .default_GATE, .default_COMP, .default_EQ, .default_OUTPT => false,
                else => true,
            };
        }
        return false;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        // Toggle the field at current scroll position in temp_settings.
        // Only the 6 boolean fields handled by Preferences.toggleField() are actually
        // toggleable. The remaining fields (auto_insert_*, auto_reorder_*, language,
        // preferred_module_order) are routed through toggleField() but it returns false
        // for them, so the system does not toggle them and does not set dirty.
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
                else => {},
            }
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Save initial mode
        const initial_mode = sut.globals.state.current_mode;

        // Execute toggle action
        settingsActions(sut.globals, .toggle);

        // Update model
        self.onModelOnly(model);

        // Verify panel is still open and state is correct
        if (sut.globals.settings_panel) |panel| {
            if (Preferences.SettingsFields.fromIndex(model.scroll_position_rel)) |field| {
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

    // ScrollCmd instances with randomized encoder positions. Because FinitePrng
    // can run out of entropy (e.g., when called via std.testing.fuzz with empty input),
    // we return early if we cannot generate the command parameters.
    var scroll_a = ScrollCmd{ .new_pos = random.int(u8) catch return };
    var scroll_b = ScrollCmd{ .new_pos = random.int(u8) catch return };
    var scroll_c = ScrollCmd{ .new_pos = random.int(u8) catch return };

    // UpdateValCmd instances for boolean fields with randomized values
    var update_show_startup = UpdateValCmd{ .field = .show_startup_message, .value = .{ .bool_val = random.boolean() catch return } };
    var update_show_startup_2 = UpdateValCmd{ .field = .show_startup_message, .value = .{ .bool_val = random.boolean() catch return } };
    var update_show_feedback = UpdateValCmd{ .field = .show_feedback_window, .value = .{ .bool_val = random.boolean() catch return } };
    var update_show_plugin = UpdateValCmd{ .field = .show_plugin_ui, .value = .{ .bool_val = random.boolean() catch return } };
    var update_manual_routing = UpdateValCmd{ .field = .manual_routing, .value = .{ .bool_val = random.boolean() catch return } };
    var update_log_to_file = UpdateValCmd{ .field = .log_to_file, .value = .{ .bool_val = random.boolean() catch return } };
    var update_start_suspended = UpdateValCmd{ .field = .start_suspended, .value = .{ .bool_val = random.boolean() catch return } };
    var update_auto_insert = UpdateValCmd{ .field = .auto_insert_modules, .value = .{ .bool_val = random.boolean() catch return } };
    var update_auto_insert_bp = UpdateValCmd{ .field = .auto_insert_bypassed, .value = .{ .bool_val = random.boolean() catch return } };
    var update_auto_reorder = UpdateValCmd{ .field = .auto_reorder_modules, .value = .{ .bool_val = random.boolean() catch return } };

    // UpdateValCmd instance for enum field with randomized value
    var update_module_order = UpdateValCmd{ .field = .preferred_module_order, .value = .{ .enum_val = random.enumValue(ModulesOrder) catch return } };

    // Create commands array
    const commands = [_]Command(Model, System){
        Command(Model, System).init(&openCmd),
        Command(Model, System).init(&saveCmd),
        Command(Model, System).init(&cancelCmd),
        Command(Model, System).init(&toggleCmd),
        Command(Model, System).init(&scroll_a),
        Command(Model, System).init(&scroll_b),
        Command(Model, System).init(&scroll_c),
        Command(Model, System).init(&update_show_startup),
        Command(Model, System).init(&update_show_startup_2),
        Command(Model, System).init(&update_show_feedback),
        Command(Model, System).init(&update_show_plugin),
        Command(Model, System).init(&update_manual_routing),
        Command(Model, System).init(&update_log_to_file),
        Command(Model, System).init(&update_start_suspended),
        Command(Model, System).init(&update_auto_insert),
        Command(Model, System).init(&update_auto_insert_bp),
        Command(Model, System).init(&update_auto_reorder),
        Command(Model, System).init(&update_module_order),
    };

    // Create command sequence
    var cmd_seq = CommandList(Model, System).init(
        &commands,
        &random,
        500,
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
    // We use multiple seeds to increase coverage. Because the command set is larger now
    // (17 commands vs the original 4), a single seed may not exercise all interactions.
    const seeds = [_]u64{ 0xDEADBEEF12345678, 0xCAFE0000BABE0001, 0x1234567890ABCDEF };
    for (seeds) |seed| {
        var seed_prng = std.Random.DefaultPrng.init(seed);
        var random_bytes: [4096]u8 = undefined;
        seed_prng.random().bytes(&random_bytes);
        try settingsStatefulTest({}, &random_bytes);
    }
}
