const std = @import("std");
const zlowcheck = @import("zlowcheck");
const Globals = @import("../../globals.zig");
const actions = @import("../../actions.zig");

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
        actions.dispatch(.{ .settings = .open });

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
        actions.dispatch(.{ .settings = .save });

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
        actions.dispatch(.{ .settings = .close });

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
        const new_pos = try self.random.int(u7);
        model.scroll_position = new_pos;
    }
    pub fn onPair(self: *@This(), model: *PrefsModel, sut: *Globals) !bool {
        const new_pos = try self.random.int(u7);
        model.scroll_position = new_pos;
        actions.dispatch(sut, .{ .settings = .{ .scroll = new_pos } });
        sut.settings_panel.?.scroll_position_abs == model.scroll_position;
    }
};

const ToggleCmd = struct {
    pub const name = "settingsToggle";

    pub fn checkPrecondition(self: *@This(), model: *PrefsModel) bool {
        _ = self;
        // scroll pos must be pointing to one fo the togglable options from the model
        return model.panel_open and std.meta.intToEnum(SettingsToggles, model.scroll_position) != null;
    }
    pub fn onModelOnly(self: *@This(), model: *PrefsModel) void {
        _ = self;
        const variant = std.meta.intToEnum(SettingsToggles, model.scroll_position) catch unreachable;
        @field(model, @tagName(variant)) = !@field(model, @tagName(variant));
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

        const toggle_idx = try self.random.intRangeLessThan(u8, 0, @intCast(std.enums.values(SettingsToggles).len));
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

                const act: @import("../../settings_panel.zig").SettingsValUpdate = .{
                    .string_val = .{
                        .field = @field(@import("../../settings.zig").SettingsFields, @tagName(variant)),
                        .val = !@field(sut.settings_panel.?.temp_settings, @tagName(variant)),
                    },
                };

                actions.dispatch(sut, .{ .settings = .{ .toggle = act } });
                return @field(sut.settings_panel.?.temp_settings, @tagName(variant)) == @field(model, @tagName(variant));
            },
        }
    }
};
