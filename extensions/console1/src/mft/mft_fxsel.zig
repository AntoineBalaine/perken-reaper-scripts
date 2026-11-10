//! The FX SEL mode, which the key L3 opens and which takes over all sixteen encoders of the controller.
//!
//! In the mode, the encoders of the bottom row that select a module (the input, the gate, the EQ, the compressor and the output) choose the module
//! that the mode works on, the turn of the encoder 13 scrolls a list and its push runs the entry, and the push of the encoder 14 cancels. The
//! first screen has the actions that can be done to the module (load a plugin, select or save a preset, create a mapping), and the screens that
//! follow have their own lists. Because the logic does not call REAPER, it is here, where the unit tests can reach it; the file that handles the
//! MIDI events does what the outcomes ask for.
const std = @import("std");
const mft_state = @import("mft_state.zig");
const mappings = @import("mft_mappings.zig");
const fx_browser = @import("fx_browser");

pub const MappableModule = mappings.MappableModule;

/// The hue of the color LEDs in the mode, which is a green on the wheel of the controller.
pub const hue: u8 = 0x2B;

/// The encoders that have a function in the mode, by their position on the grid (from 0, row by row).
pub const list_encoder = 12;
pub const cancel_encoder = 13;

/// How many ticks of the encoder scroll the list by one entry. Because the encoder sends a tick for every small turn, and a list of dozens of
/// entries would fly past, the ticks are counted and the cursor moves once for each of these.
pub const ticks_per_step = 6;

pub const Screen = enum {
    /// The first screen: the module and the action.
    actions,
    /// The plugins that can be loaded for the module.
    browse,
};

/// The menus of the browser that the controller leaves out. The FX chains and the track templates insert more than a plugin into a module, the
/// container and the video processor have nothing to map, and the recent plugins are not kept here, so what is left are the plugins that have a
/// map and the lists of all the plugins, by type and by tag.
pub const hidden_menus = fx_browser.HiddenMenus.initMany(&.{ .fx_chains, .track_templates, .container, .video_processor, .recent });

/// The name of a menu of the first level.
pub fn rootMenuName(menu: fx_browser.RootMenu) [:0]const u8 {
    return switch (menu) {
        .fx_chains => "FX chains",
        .track_templates => "Track templates",
        .all_plugins => "All plugins",
        .tags_category => "Categories",
        .tags_developer => "Developers",
        .container => "Container",
        .video_processor => "Video processor",
        .recent => "Recent",
    };
}

/// The name that the window shows for an entry of the level that is open: the plugins that have a map and the menus on the first level, and what
/// `fx_browser` names on the others.
pub fn entryName(state: *const FxSelState, source: fx_browser.Source, level: fx_browser.Level, index: usize) [:0]const u8 {
    switch (level) {
        .root => {
            if (index < state.browser.count) return state.browser.get(index);
            const menu = fx_browser.rootMenuOf(source, index) orelse return "?";
            return rootMenuName(menu);
        },
        else => return fx_browser.entryName(source, level, index) orelse "?",
    }
}

/// What can be done to the module, in the order of the list.
pub const Action = enum {
    load_fx,
    select_preset,
    save_preset,
    create_mapping,

    pub fn label(self: Action) [:0]const u8 {
        return switch (self) {
            .load_fx => "Load FX",
            .select_preset => "Select preset",
            .save_preset => "Save preset",
            .create_mapping => "Create mapping",
        };
    }

    /// The shorter word under the shortcut on the top row.
    pub fn shortcut(self: Action) [:0]const u8 {
        return switch (self) {
            .load_fx => "Load FX",
            .select_preset => "Presets",
            .save_preset => "Save Preset",
            .create_mapping => "Mapping",
        };
    }
};

pub const action_count = @typeInfo(Action).@"enum".field_names.len;

/// The list of plugins that the browser shows. It has room for a fixed number, because a module has a few dozens of them.
pub const BrowserList = struct {
    pub const max_entries = 256;
    pub const name_len = 96;

    names: [max_entries][name_len:0]u8 = undefined,
    count: usize = 0,

    pub fn clear(self: *BrowserList) void {
        self.count = 0;
    }

    /// Adds a name, cut to `name_len`. A name that does not fit in the list is dropped.
    pub fn add(self: *BrowserList, name: []const u8) void {
        if (self.count >= max_entries) return;
        const n = @min(name.len, name_len);
        @memcpy(self.names[self.count][0..n], name[0..n]);
        self.names[self.count][n] = 0;
        self.count += 1;
    }

    pub fn get(self: *const BrowserList, index: usize) [:0]const u8 {
        std.debug.assert(index < self.count);
        return std.mem.sliceTo(&self.names[index], 0);
    }

    /// Sorts the names without regard to the case, so that the list reads in the order of the alphabet.
    pub fn sort(self: *BrowserList) void {
        std.mem.sort([name_len:0]u8, self.names[0..self.count], {}, lessThan);
    }

    fn lessThan(_: void, a: [name_len:0]u8, b: [name_len:0]u8) bool {
        const x = std.mem.sliceTo(&a, 0);
        const y = std.mem.sliceTo(&b, 0);
        const n = @min(x.len, y.len);
        for (0..n) |i| {
            const cx = std.ascii.toLower(x[i]);
            const cy = std.ascii.toLower(y[i]);
            if (cx != cy) return cx < cy;
        }
        return x.len < y.len;
    }
};

pub const FxSelState = struct {
    screen: Screen = .actions,
    /// The module that the mode works on.
    module: MappableModule = .EQ,
    /// The entry of the list of actions, and the entry of the list of plugins.
    action_cursor: u8 = 0,
    /// Where the browser is: the menus that are open (`browse_path` has the entry that opened each one), and the cursor of every level.
    browse_depth: u8 = 0,
    browse_path: [fx_browser.max_depth]usize = @splat(0),
    browse_cursors: [fx_browser.max_depth + 1]u16 = @splat(0),
    /// The ticks of the encoder that have not made a step yet, which keep the sign of the turn.
    scroll_ticks: i16 = 0,
    /// The page that the controller was on when the mode opened, which it goes back to when the mode closes.
    return_page: mft_state.MftActiveModule = .TRANSPORT,
    browser: BrowserList = .{},
    /// A line that tells the player what the last press did or why it did nothing, which the panel shows under the list.
    note: [96:0]u8 = @splat(0),

    pub fn setNote(self: *FxSelState, text: []const u8) void {
        const n = @min(text.len, self.note.len);
        @memcpy(self.note[0..n], text[0..n]);
        self.note[n] = 0;
    }

    pub fn noteText(self: *const FxSelState) [:0]const u8 {
        return std.mem.sliceTo(&self.note, 0);
    }

    /// The entry of the level that is open that the cursor is on.
    pub fn cursor(self: *const FxSelState) u16 {
        return self.browse_cursors[self.browse_depth];
    }

    /// Goes back to the first level, with the cursor on the first entry.
    pub fn resetBrowser(self: *FxSelState) void {
        self.browse_depth = 0;
        self.browse_cursors = @splat(0);
    }

    /// The level that is open, or the first one when the path leads nowhere (the data changed).
    pub fn level(self: *const FxSelState, source: fx_browser.Source) fx_browser.Level {
        return fx_browser.levelAt(source, self.browse_path[0..self.browse_depth]) orelse .root;
    }

    pub fn action(self: *const FxSelState) Action {
        return @fromBackingInt(@intCast(self.action_cursor));
    }
};

/// The module that a bottom-row encoder chooses in the mode, or null for the other encoders.
pub fn moduleForEncoder(encoder: usize) ?MappableModule {
    return switch (encoder) {
        8 => .INPUT,
        9 => .GATE,
        10 => .EQ,
        11 => .COMP,
        15 => .OUTPUT,
        else => null,
    };
}

/// What the handler of the MIDI events has to do after an event, beyond the change of the state that is already made.
pub const Outcome = union(enum) {
    none,
    /// The mode is closed.
    leave,
    /// The list of plugins has to be filled again, for the module of the state.
    fill_browser,
    /// The plugin of that name is to be loaded for the module, and the mode closed.
    load_plugin: [:0]const u8,
    /// The action has no screen yet.
    not_done: Action,
};

fn move(cursor: anytype, steps: i32, count: usize) void {
    if (count == 0) return;
    const next = @as(i32, cursor.*) + steps;
    cursor.* = @intCast(std.math.clamp(next, 0, @as(i32, @intCast(count)) - 1));
}

/// How many entries the list of the screen has. The browser has the levels of `fx_browser`, and none when the data of the plugins is not there.
pub fn listCount(state: *const FxSelState, source: ?fx_browser.Source) usize {
    return switch (state.screen) {
        .actions => action_count,
        .browse => if (source) |data| fx_browser.entryCount(data, state.level(data)) else 0,
    };
}

/// A turn of an encoder. Only the encoder 13 does something: it scrolls the list of the screen, one entry for each `ticks_per_step` ticks.
pub fn turn(state: *FxSelState, encoder: usize, delta: i8, source: ?fx_browser.Source) Outcome {
    if (encoder != list_encoder or delta == 0) return .none;
    const total: i32 = @as(i32, state.scroll_ticks) + delta;
    const steps = @divTrunc(total, ticks_per_step);
    state.scroll_ticks = @intCast(total - steps * ticks_per_step);
    if (steps == 0) return .none;
    switch (state.screen) {
        .actions => move(&state.action_cursor, steps, action_count),
        .browse => move(&state.browse_cursors[state.browse_depth], steps, listCount(state, source)),
    }
    return .none;
}

fn runAction(state: *FxSelState, action: Action) Outcome {
    switch (action) {
        .load_fx => {
            state.screen = .browse;
            state.resetBrowser();
            return .fill_browser;
        },
        .select_preset, .save_preset, .create_mapping => return .{ .not_done = action },
    }
}

/// Confirms the entry that the cursor is on in the browser: a menu opens, and a plugin is loaded.
fn confirmEntry(state: *FxSelState, source: fx_browser.Source) Outcome {
    const level = state.level(source);
    const index = state.cursor();
    var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    switch (fx_browser.activate(source, level, index, &path_buf)) {
        .enter => {
            if (state.browse_depth >= fx_browser.max_depth) return .none;
            state.browse_path[state.browse_depth] = index;
            state.browse_depth += 1;
            state.browse_cursors[state.browse_depth] = 0;
            return .none;
        },
        .mapped => |entry| return .{ .load_plugin = state.browser.get(entry) },
        .plugin => |name| return .{ .load_plugin = name },
        // The menus that insert chains and templates are hidden, so these do not come; a leaf of the first level has nothing to load.
        .fx_chain, .track_template, .root_leaf, .none => return .none,
    }
}

/// A press of an encoder.
pub fn press(state: *FxSelState, encoder: usize, source: ?fx_browser.Source) Outcome {
    state.scroll_ticks = 0;
    if (moduleForEncoder(encoder)) |module| {
        state.module = module;
        if (state.screen != .browse) return .none;
        state.resetBrowser();
        return .fill_browser;
    }
    if (encoder == cancel_encoder) {
        return switch (state.screen) {
            .actions => .leave,
            .browse => blk: {
                // Back leaves the menu that is open, and the browser when it is on the first level.
                if (state.browse_depth > 0) state.browse_depth -= 1 else state.screen = .actions;
                break :blk .none;
            },
        };
    }
    if (encoder == list_encoder) {
        return switch (state.screen) {
            .actions => runAction(state, state.action()),
            .browse => if (source) |data| confirmEntry(state, data) else .none,
        };
    }
    // The top row has a shortcut for each action on the first screen.
    if (state.screen == .actions and encoder < action_count) return runAction(state, @fromBackingInt(@intCast(encoder)));
    return .none;
}

/// What the window of an encoder says in the mode: the word of a turn, the word of a press, and whether the encoder is the module that is chosen.
pub const Label = struct {
    turn: ?[:0]const u8 = null,
    press: [:0]const u8 = "-",
    chosen: bool = false,
};

pub fn label(state: *const FxSelState, encoder: usize) Label {
    if (encoder < 8) {
        if (state.screen == .actions and encoder < action_count) {
            const action: Action = @fromBackingInt(@intCast(encoder));
            return .{ .press = action.shortcut(), .chosen = action == state.action() };
        }
        return .{};
    }
    if (moduleForEncoder(encoder)) |module| return .{ .press = @tagName(module), .chosen = module == state.module };
    if (encoder == list_encoder) {
        return .{ .turn = switch (state.screen) {
            .actions => state.action().label(),
            .browse => "Scroll",
        }, .press = "OK" };
    }
    if (encoder == cancel_encoder) return .{ .press = if (state.screen == .actions) "Cancel" else "Back" };
    return .{};
}

/// A browser source for the tests: the plugins that have a map (`mapped`), and the VST list with a few plugins.
const TestData = struct {
    chains: fx_browser_types.Directory = .{ .path = "/chains", .name = "chains", .subdirs = null, .files = null },
    templates: fx_browser_types.Directory = .{ .path = "/templates", .name = "templates", .subdirs = null, .files = null },
    by_type: fx_browser_types.FxByType = fx_browser_types.FxByType.initFill(.{}),
    tags: fx_browser_types.FxTags = .{ .category = .{}, .developer = .{} },

    fn init(self: *TestData, allocator: std.mem.Allocator) !void {
        try self.by_type.getPtr(.VST).put(allocator, "ReaEQ", {});
        try self.by_type.getPtr(.VST).put(allocator, "ReaComp", {});
    }

    fn deinit(self: *TestData, allocator: std.mem.Allocator) void {
        for (&self.by_type.values) |*list| list.deinit(allocator);
    }

    fn source(self: *const TestData, mapped: usize) fx_browser.Source {
        return .{ .mapped_count = mapped, .fx_chains = &self.chains, .track_templates = &self.templates, .plugins_by_type = &self.by_type, .tags = &self.tags, .hidden_menus = hidden_menus };
    }
};

const fx_browser_types = @import("fx_parser_types");

/// Turns the encoder 13 by `entries` entries (negative for the other way), as many ticks as that takes.
fn scroll(state: *FxSelState, entries: i32, source: ?fx_browser.Source) void {
    const sign: i8 = if (entries < 0) -1 else 1;
    var ticks: i32 = @intCast(@abs(entries) * ticks_per_step);
    while (ticks > 0) : (ticks -= 1) _ = turn(state, list_encoder, sign, source);
}

test "the encoder scrolls one entry for every few ticks, and keeps the ticks that did not make a step" {
    const t = std.testing;
    var state = FxSelState{};
    for (0..ticks_per_step - 1) |_| _ = turn(&state, list_encoder, 1, null);
    try t.expectEqual(@as(u8, 0), state.action_cursor);
    _ = turn(&state, list_encoder, 1, null);
    try t.expectEqual(@as(u8, 1), state.action_cursor);
    // A fast turn that sends a large tick moves several entries at once, and the rest is kept.
    _ = turn(&state, list_encoder, ticks_per_step + 2, null);
    try t.expectEqual(@as(u8, 2), state.action_cursor);
    try t.expectEqual(@as(i16, 2), state.scroll_ticks);
    // A press starts the count again.
    _ = press(&state, 5, null);
    try t.expectEqual(@as(i16, 0), state.scroll_ticks);
}

test "the first screen scrolls the list, stops at its ends, and the module buttons choose the module" {
    const t = std.testing;
    var state = FxSelState{};
    try t.expectEqual(Action.load_fx, state.action());
    scroll(&state, -1, null);
    try t.expectEqual(@as(u8, 0), state.action_cursor);
    scroll(&state, 10, null);
    try t.expectEqual(Action.create_mapping, state.action());
    // Another encoder does not scroll.
    for (0..ticks_per_step) |_| _ = turn(&state, 5, 1, null);
    try t.expectEqual(Action.create_mapping, state.action());

    try t.expectEqual(Outcome.none, press(&state, 9, null));
    try t.expectEqual(MappableModule.GATE, state.module);
    try t.expectEqual(Outcome.none, press(&state, 15, null));
    try t.expectEqual(MappableModule.OUTPUT, state.module);
}

test "the browser lists the plugins that have a map and then the menus, opens a menu, loads a plugin, and Back leaves level by level" {
    const t = std.testing;
    var data = TestData{};
    try data.init(t.allocator);
    defer data.deinit(t.allocator);
    var state = FxSelState{};
    try t.expectEqual(Outcome.fill_browser, press(&state, list_encoder, null));
    try t.expectEqual(Screen.browse, state.screen);
    // The first level: two plugins that have a map, then the menus that are not hidden (all plugins, categories, developers).
    state.browser.add("VST: ReaEQ (Cockos)");
    state.browser.add("JS: 3-Band EQ");
    const source = data.source(state.browser.count);
    try t.expectEqual(@as(usize, 2 + 3), listCount(&state, source));
    try t.expectEqualStrings("JS: 3-Band EQ", entryName(&state, source, state.level(source), 1));
    try t.expectEqualStrings("All plugins", entryName(&state, source, state.level(source), 2));

    // A plugin that has a map is loaded by its name.
    scroll(&state, 1, source);
    const mapped = press(&state, list_encoder, source);
    try t.expectEqualStrings("JS: 3-Band EQ", mapped.load_plugin);

    // The menu of all the plugins opens the types, and the type opens its list, whose entry is loaded.
    scroll(&state, 1, source);
    try t.expectEqual(Outcome.none, press(&state, list_encoder, source));
    try t.expectEqual(@as(u8, 1), state.browse_depth);
    try t.expectEqual(@as(u16, 0), state.cursor());
    // The first type is VST, which has two plugins.
    try t.expectEqual(Outcome.none, press(&state, list_encoder, source));
    try t.expectEqual(@as(u8, 2), state.browse_depth);
    try t.expectEqual(@as(usize, 2), listCount(&state, source));
    scroll(&state, 1, source);
    const loaded = press(&state, list_encoder, source);
    try t.expectEqualStrings("ReaComp", loaded.load_plugin);

    // Back leaves the lists one at a time, the first level goes back to the first screen, and then the mode closes.
    try t.expectEqual(Outcome.none, press(&state, cancel_encoder, source));
    try t.expectEqual(@as(u8, 1), state.browse_depth);
    try t.expectEqual(Outcome.none, press(&state, cancel_encoder, source));
    try t.expectEqual(@as(u8, 0), state.browse_depth);
    try t.expectEqual(Screen.browse, state.screen);
    try t.expectEqual(Outcome.none, press(&state, cancel_encoder, source));
    try t.expectEqual(Screen.actions, state.screen);
    try t.expectEqual(Outcome.leave, press(&state, cancel_encoder, source));
}

test "a module button in the browser asks for the list of that module, from the top" {
    const t = std.testing;
    var state = FxSelState{};
    _ = press(&state, list_encoder, null);
    state.browse_depth = 1;
    state.browse_cursors[1] = 4;
    try t.expectEqual(Outcome.fill_browser, press(&state, 11, null));
    try t.expectEqual(@as(u8, 0), state.browse_depth);
    try t.expectEqual(@as(u16, 0), state.cursor());
    try t.expectEqual(MappableModule.COMP, state.module);
}

test "without the data of the plugins, the browser is empty and a press loads nothing" {
    const t = std.testing;
    var state = FxSelState{};
    _ = press(&state, list_encoder, null);
    try t.expectEqual(@as(usize, 0), listCount(&state, null));
    try t.expectEqual(Outcome.none, press(&state, list_encoder, null));
}

test "the shortcuts of the top row run their action, and the actions without a screen say so" {
    const t = std.testing;
    var state = FxSelState{};
    try t.expectEqual(Outcome{ .not_done = .select_preset }, press(&state, 1, null));
    try t.expectEqual(Outcome{ .not_done = .create_mapping }, press(&state, 3, null));
    try t.expectEqual(Outcome.none, press(&state, 4, null));
    try t.expectEqual(Outcome.fill_browser, press(&state, 0, null));
    // In the browser the top row has no shortcut.
    try t.expectEqual(Outcome.none, press(&state, 1, null));
}

test "BrowserList: names are kept, cut to their size, sorted without regard to the case, and dropped when the list is full" {
    const t = std.testing;
    var list = BrowserList{};
    list.add("VST: ReaEQ (Cockos)");
    list.add("JS: 3-Band EQ");
    list.add("js: another");
    list.sort();
    try t.expectEqualStrings("JS: 3-Band EQ", list.get(0));
    try t.expectEqualStrings("js: another", list.get(1));
    try t.expectEqualStrings("VST: ReaEQ (Cockos)", list.get(2));
    const long: [200]u8 = @splat('x');
    list.clear();
    list.add(&long);
    try t.expectEqual(@as(usize, BrowserList.name_len), list.get(0).len);
    for (0..BrowserList.max_entries + 5) |_| list.add("x");
    try t.expectEqual(@as(usize, BrowserList.max_entries), list.count);
}

test "label: the windows of the first screen and of the browser" {
    const t = std.testing;
    var state = FxSelState{};
    state.module = .COMP;
    try t.expectEqualStrings("Load FX", label(&state, 0).press);
    try t.expect(label(&state, 0).chosen);
    try t.expect(!label(&state, 1).chosen);
    try t.expectEqualStrings("-", label(&state, 6).press);
    try t.expectEqualStrings("COMP", label(&state, 11).press);
    try t.expect(label(&state, 11).chosen);
    try t.expectEqualStrings("Load FX", label(&state, list_encoder).turn.?);
    try t.expectEqualStrings("Cancel", label(&state, cancel_encoder).press);
    state.screen = .browse;
    try t.expectEqualStrings("-", label(&state, 0).press);
    try t.expectEqualStrings("Scroll", label(&state, list_encoder).turn.?);
    try t.expectEqualStrings("Back", label(&state, cancel_encoder).press);
}
