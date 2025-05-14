const std = @import("std");
const zlowcheck = @import("zlowcheck");
const Globals = @import("../globals.zig");
const actions = @import("../actions.zig");

const PrefsModel = struct {
    language: []const u8 = "en",
    log_to_file: bool = false,
    manual_routing: bool = false,
    panel_open: bool = false,
    scroll_position: u7 = 0,
    show_feedback_window: bool = true,
    show_plugin_ui: bool = true,
    show_startup_message: bool = true,
    start_suspended: bool = false,
    pub fn reset(self: *@This()) void {
        self.language = "en";
        self.log_to_file = false;
        self.manual_routing = false;
        self.panel_open = false;
        self.scroll_position = 0;
        self.show_feedback_window = true;
        self.show_plugin_ui = true;
        self.show_startup_message = true;
        self.start_suspended = false;
    }
};
pub const SettingsToggles = enum {
    log_to_file,
    manual_routing,
    show_feedback_window,
    show_plugin_ui,
    show_startup_message,
    start_suspended,
};

const PrefsCmd = zlowcheck.Command(PrefsModel, Globals);

const OpenCmd = struct {
    pub const name = "SettingsOpen";
    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        return model.panel_open == false;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        _ = self;
        model.panel_open = true;
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        _ = self;

        model.panel_open = true;
        actions.dispatch(sut, .{ .settings = .open });

        const cond =
            sut.settings_panel != null and
            sut.state.current_mode == .settings and
            model.panel_open;
        return cond;
    }
};

const SaveCmd = struct {
    pub const name = "SettingsSave";

    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        return model.panel_open == true;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        _ = self;
        model.panel_open = false;
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        _ = self;

        model.panel_open = false;
        actions.dispatch(sut, .{ .settings = .save });

        const cond =
            sut.settings_panel == null and
            sut.state.current_mode == .fx_ctrl and
            !model.panel_open;
        return cond;
    }
};
const CancelCmd = struct {
    pub const name = "settings_cancel";

    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        return model.panel_open == true;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        _ = self;
        model.panel_open = false;
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        _ = self;

        model.panel_open = false;
        actions.dispatch(sut, .{ .settings = .cancel });

        const cond =
            sut.settings_panel == null and
            sut.state.current_mode == .fx_ctrl and
            !model.panel_open;
        return cond;
    }
};
const ScrollCmd = struct {
    pub const name = "settings_scroll";
    random: *zlowcheck.FinitePrng.FiniteRandom,

    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        return model.panel_open;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        const new_pos = self.random.int(u7) catch unreachable;
        model.scroll_position = new_pos;
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        const new_pos = try self.random.int(u7);
        model.scroll_position = new_pos;
        actions.dispatch(sut, .{ .settings = .{ .scroll = new_pos } });
        return sut.settings_panel.?.scroll_position_abs == model.scroll_position;
    }
};

const ToggleCmd = struct {
    pub const name = "settingsToggle";

    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        // scroll pos must be pointing to one fo the togglable options from the model
        return model.panel_open and std.meta.intToEnum(SettingsToggles, model.scroll_position) catch null != null;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        _ = self;
        const @"enum" = std.meta.intToEnum(SettingsToggles, model.scroll_position) catch unreachable;
        switch (@"enum") {
            inline else => |variant| @field(model, @tagName(variant)) = !@field(model, @tagName(variant)),
        }
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        _ = self;
        const @"enum" = std.meta.intToEnum(SettingsToggles, model.scroll_position) catch unreachable;
        switch (@"enum") {
            inline else => |variant| {
                @field(model, @tagName(variant)) = !@field(model, @tagName(variant));
                actions.dispatch(sut, .{ .settings = .toggle });
                return @field(model, @tagName(variant)) == @field(sut.settings_panel.?.temp_settings, @tagName(variant));
            },
        }
    }
};
const UpdateCmd = struct {
    random: *zlowcheck.FinitePrng.FiniteRandom,
    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        // scroll pos must be pointing to one fo the togglable options from the model
        return model.panel_open;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        // for now, always use a bool_val
        // const str_val = try self.random.chance(.{ .denominator = 9, .numerator = 1 });

        const toggle_idx = self.random.intRangeLessThan(u8, 0, @intCast(std.enums.values(SettingsToggles).len)) catch unreachable;
        const toggle: SettingsToggles = @enumFromInt(toggle_idx);
        switch (toggle) {
            inline else => |variant| @field(model, @tagName(variant)) = !@field(model, @tagName(variant)),
        }
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        const toggle_idx = try self.random.intRangeLessThan(u8, 0, @intCast(std.enums.values(SettingsToggles).len));
        const toggle: SettingsToggles = @enumFromInt(toggle_idx);
        switch (toggle) {
            inline else => |variant| {
                @field(model, @tagName(variant)) = !@field(model, @tagName(variant));

                const act: @import("../settings_panel.zig").SettingsValUpdate = .{
                    .bool_val = .{
                        .field = @field(@import("../settings.zig").SettingsFields, @tagName(variant)),
                        .val = !@field(sut.settings_panel.?.temp_settings, @tagName(variant)),
                    },
                };

                actions.dispatch(sut, .{ .settings = .{ .update_val = act } });
                return @field(sut.settings_panel.?.temp_settings, @tagName(variant)) == @field(model, @tagName(variant));
            },
        }
    }
};

fn prefsStatefulTest(_: void, input: []const u8) !void {
    const g_teardown = try @import("mode_switch_tests.zig").test_setup(std.testing.allocator);
    defer g_teardown.teardown();
    _ = @import("../csurf/control_surface.zig").init(0, 0, null);

    const fuzz_data = std.testing.allocator.alloc(u8, input.len) catch return error.SkipZigTest;
    defer std.testing.allocator.free(fuzz_data);
    @memcpy(fuzz_data, input);
    var prng: zlowcheck.FinitePrng = .init(fuzz_data);
    var random = prng.random();

    var openCmd: OpenCmd = .{};
    var saveCmd: SaveCmd = .{};
    var cancelCmd: CancelCmd = .{};
    var scrollCmd: ScrollCmd = .{ .random = &random };
    var toggleCmd: ToggleCmd = .{};
    var updateCmd: UpdateCmd = .{ .random = &random };

    const commands = [_]PrefsCmd{
        PrefsCmd.init(&openCmd),
        PrefsCmd.init(&saveCmd),
        PrefsCmd.init(&cancelCmd),
        PrefsCmd.init(&scrollCmd),
        PrefsCmd.init(&toggleCmd),
        PrefsCmd.init(&updateCmd),
    };
    var cmd_seq = try zlowcheck.CommandList(PrefsModel, Globals).init(
        &commands,
        &random,
        50,
        std.testing.allocator,
    );
    defer cmd_seq.deinit(std.testing.allocator);

    // Initialize model and system
    var model: PrefsModel = .{};
    var sut = Globals.instance;

    const rv = zlowcheck.assertStateful(
        PrefsModel,
        Globals,
        &cmd_seq,
        &model,
        &sut,
        .{ .verbose = true },
    ) catch |err| {
        // We expect some errors due to OutOfEntropy, which is fine
        if (err == zlowcheck.FinitePrng.FinitePrngErr.OutOfEntropy) return;
        return err;
    };
    if (rv) |_| {
        std.debug.print("FAILURE with bytes:\n{s}\n", .{fuzz_data});
    }
    try std.testing.expect(rv == null);
}

test "bytes" {
    const random_bytes = [_]u8{
        0x8B, 0xBE, 0x02, 0x2C, 0x87, 0x0A, 0xF6, 0x54, 0x4A, 0x59, 0x73, 0xA8, 0x12, 0xF7, 0x2B, 0x85,
        //
        0xAD, 0x95, 0x90, 0x8A, 0x21, 0xF1, 0xAC, 0x64, 0x42, 0x32, 0xA5, 0x0D, 0x10, 0x1F, 0xBA, 0xE7,
        //
        0x0F, 0xEE, 0xF9, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62, 0x62,
    };
    try prefsStatefulTest({}, &random_bytes);
}

test prefsStatefulTest {
    try std.testing.fuzz({}, prefsStatefulTest, .{});
}
