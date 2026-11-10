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

pub const MappableModule = mappings.MappableModule;

/// The hue of the color LEDs in the mode, which is a green on the wheel of the controller.
pub const hue: u8 = 0x2B;

/// The encoders that have a function in the mode, by their position on the grid (from 0, row by row).
pub const list_encoder = 12;
pub const cancel_encoder = 13;

pub const Screen = enum {
    /// The first screen: the module and the action.
    actions,
    /// The plugins that can be loaded for the module.
    browse,
};

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
    browse_cursor: u16 = 0,
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
    /// The plugin at that entry of the list is to be loaded, and the mode closed.
    load_plugin: u16,
    /// The action has no screen yet.
    not_done: Action,
};

fn move(cursor: anytype, delta: i8, count: usize) void {
    if (count == 0) return;
    const next = @as(i32, cursor.*) + @as(i32, if (delta > 0) 1 else -1);
    cursor.* = @intCast(std.math.clamp(next, 0, @as(i32, @intCast(count)) - 1));
}

/// A turn of an encoder. Only the encoder 13 does something: it scrolls the list of the screen.
pub fn turn(state: *FxSelState, encoder: usize, delta: i8) Outcome {
    if (encoder != list_encoder or delta == 0) return .none;
    switch (state.screen) {
        .actions => move(&state.action_cursor, delta, action_count),
        .browse => move(&state.browse_cursor, delta, state.browser.count),
    }
    return .none;
}

fn runAction(state: *FxSelState, action: Action) Outcome {
    switch (action) {
        .load_fx => {
            state.screen = .browse;
            state.browse_cursor = 0;
            return .fill_browser;
        },
        .select_preset, .save_preset, .create_mapping => return .{ .not_done = action },
    }
}

/// A press of an encoder.
pub fn press(state: *FxSelState, encoder: usize) Outcome {
    if (moduleForEncoder(encoder)) |module| {
        state.module = module;
        state.browse_cursor = 0;
        return if (state.screen == .browse) .fill_browser else .none;
    }
    if (encoder == cancel_encoder) {
        return switch (state.screen) {
            .actions => .leave,
            .browse => blk: {
                state.screen = .actions;
                break :blk .none;
            },
        };
    }
    if (encoder == list_encoder) {
        return switch (state.screen) {
            .actions => runAction(state, state.action()),
            .browse => if (state.browser.count == 0) .none else .{ .load_plugin = state.browse_cursor },
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

test "the first screen scrolls the list, stops at its ends, and the module buttons choose the module" {
    const t = std.testing;
    var state = FxSelState{};
    try t.expectEqual(Action.load_fx, state.action());
    _ = turn(&state, list_encoder, -1);
    try t.expectEqual(@as(u8, 0), state.action_cursor);
    for (0..10) |_| _ = turn(&state, list_encoder, 1);
    try t.expectEqual(Action.create_mapping, state.action());
    // Another encoder does not scroll.
    _ = turn(&state, 5, 1);
    try t.expectEqual(Action.create_mapping, state.action());

    try t.expectEqual(Outcome.none, press(&state, 9));
    try t.expectEqual(MappableModule.GATE, state.module);
    try t.expectEqual(Outcome.none, press(&state, 15));
    try t.expectEqual(MappableModule.OUTPUT, state.module);
}

test "Load FX opens the browser, which loads the entry that the cursor is on, and Back goes to the first screen" {
    const t = std.testing;
    var state = FxSelState{};
    try t.expectEqual(Outcome.fill_browser, press(&state, list_encoder));
    try t.expectEqual(Screen.browse, state.screen);
    // The list is empty until the handler fills it, so a press loads nothing.
    try t.expectEqual(Outcome.none, press(&state, list_encoder));
    state.browser.add("VST: ReaEQ (Cockos)");
    state.browser.add("JS: 3-Band EQ");
    state.browser.add("JS: 4-Band EQ");
    _ = turn(&state, list_encoder, 1);
    _ = turn(&state, list_encoder, 1);
    _ = turn(&state, list_encoder, 1);
    try t.expectEqual(@as(u16, 2), state.browse_cursor);
    try t.expectEqual(Outcome{ .load_plugin = 2 }, press(&state, list_encoder));
    // A module button in the browser asks for the list of that module, from the top.
    try t.expectEqual(Outcome.fill_browser, press(&state, 11));
    try t.expectEqual(@as(u16, 0), state.browse_cursor);
    try t.expectEqual(Outcome.none, press(&state, cancel_encoder));
    try t.expectEqual(Screen.actions, state.screen);
    try t.expectEqual(Outcome.leave, press(&state, cancel_encoder));
}

test "the shortcuts of the top row run their action, and the actions without a screen say so" {
    const t = std.testing;
    var state = FxSelState{};
    try t.expectEqual(Outcome{ .not_done = .select_preset }, press(&state, 1));
    try t.expectEqual(Outcome{ .not_done = .create_mapping }, press(&state, 3));
    try t.expectEqual(Outcome.none, press(&state, 4));
    try t.expectEqual(Outcome.fill_browser, press(&state, 0));
    // In the browser the top row has no shortcut.
    try t.expectEqual(Outcome.none, press(&state, 1));
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
