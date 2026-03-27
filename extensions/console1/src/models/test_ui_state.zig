const std = @import("std");
const imgui = @import("reaper_imgui");
const statemachine = @import("../statemachine.zig");
const UiState = @import("../ui_state.zig").UiState;
const TranslationStore = @import("../translations.zig").TranslationStore;
const FxMaps = @import("../mappings_list.zig");
const Preferences = @import("../settings.zig").Preferences;
const fx_types = @import("../fx_parser_types.zig");
const styles = @import("../styles.zig");
const FxControlState = @import("../fx_ctrl_state.zig").FxControlState;

pub const TestUiStateBuilder = struct {
    allocator: std.mem.Allocator,
    state: statemachine.State,
    translations: TranslationStore,
    drwls_splitter: imgui.DrawListSplitterPtr,
    mappings_list: FxMaps,
    preferences: Preferences,
    fx_plugins_by_type: fx_types.FxByType,
    fx_chains: fx_types.Directory,
    track_templates: fx_types.Directory,
    fx_tags: fx_types.FxTags,
    midi_connected: bool,

    // Owned style data for StyleManager construction
    main_style: styles.StyleStruct,
    config_style: styles.StyleStruct,
    main_style_open: bool,
    config_style_open: bool,

    pub fn init(allocator: std.mem.Allocator) TestUiStateBuilder {
        return .{
            .allocator = allocator,
            .state = statemachine.State.init(allocator),
            .translations = TranslationStore.defaults(allocator) catch @panic("failed to init translations"),
            .drwls_splitter = null,
            .mappings_list = FxMaps.empty(allocator),
            .preferences = Preferences.empty,
            .fx_plugins_by_type = fx_types.FxByType.initFill(.{}),
            .fx_chains = .{ .path = "", .name = "", .subdirs = null, .files = null },
            .track_templates = .{ .path = "", .name = "", .subdirs = null, .files = null },
            .fx_tags = .{ .category = .{}, .developer = .{} },
            .midi_connected = true,
            .main_style = std.mem.zeroes(styles.StyleStruct),
            .config_style = std.mem.zeroes(styles.StyleStruct),
            .main_style_open = false,
            .config_style_open = false,
        };
    }

    pub fn deinit(self: *TestUiStateBuilder) void {
        self.state.deinit(self.allocator);
        self.translations.store.strings.deinit(self.allocator);
    }

    pub fn build(self: *TestUiStateBuilder) UiState {
        return .{
            .state = &self.state,
            .translations = &self.translations,
            .drwls_splitter = &self.drwls_splitter,
            .mappings_list = &self.mappings_list,
            .settings_panel = null,
            .preferences = &self.preferences,
            .midi_connected = self.midi_connected,
            .main_font = null,
            .icon_font = null,
            .fx_plugins_by_type = &self.fx_plugins_by_type,
            .fx_chains = &self.fx_chains,
            .track_templates = &self.track_templates,
            .fx_tags = &self.fx_tags,
        };
    }

    pub fn buildStyleManager(self: *TestUiStateBuilder) styles.StyleManager {
        return .{
            .MainStyle = &self.main_style,
            .ConfigStyle = &self.config_style,
            .main_style_open = &self.main_style_open,
            .config_style_open = &self.config_style_open,
        };
    }

    pub fn withMode(self: *TestUiStateBuilder, mode: statemachine.Mode) *TestUiStateBuilder {
        self.state.current_mode = mode;
        return self;
    }

    pub fn withMidiConnected(self: *TestUiStateBuilder, connected: bool) *TestUiStateBuilder {
        self.midi_connected = connected;
        return self;
    }

    pub fn withCurrentTrackId(self: *TestUiStateBuilder, id: ?c_int) *TestUiStateBuilder {
        self.state.current_tr_id = id;
        return self;
    }
};

test "builder produces valid UiState with defaults" {
    var builder = TestUiStateBuilder.init(std.testing.allocator);
    defer builder.deinit();
    const ui = builder.build();

    try std.testing.expect(ui.settings_panel == null);
    try std.testing.expect(ui.midi_connected);
    try std.testing.expectEqual(statemachine.Mode.fx_ctrl, ui.state.current_mode);
}

test "withMode sets the current mode" {
    var builder = TestUiStateBuilder.init(std.testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.fx_sel);
    const ui = builder.build();

    try std.testing.expectEqual(statemachine.Mode.fx_sel, ui.state.current_mode);
}

test "withMidiConnected false" {
    var builder = TestUiStateBuilder.init(std.testing.allocator);
    defer builder.deinit();
    _ = builder.withMidiConnected(false);
    const ui = builder.build();

    try std.testing.expect(!ui.midi_connected);
}

test "buildStyleManager returns valid manager" {
    var builder = TestUiStateBuilder.init(std.testing.allocator);
    defer builder.deinit();
    const style_mgr = builder.buildStyleManager();

    // Verify the pointers point into the builder's owned data
    try std.testing.expect(@intFromPtr(style_mgr.MainStyle) == @intFromPtr(&builder.main_style));
    try std.testing.expect(@intFromPtr(style_mgr.ConfigStyle) == @intFromPtr(&builder.config_style));
}
