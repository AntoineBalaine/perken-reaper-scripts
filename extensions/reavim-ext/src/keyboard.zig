//! The keyboard view of the whichkey window: physical layouts, the key each
//! cap produces on each modifier layer, and the short labels and categories
//! drawn on the caps.
//!
//! Because ReaVim binds the character that a key produces rather than the
//! physical key, a layout only has to say which character sits on which cap.
//! The same keymap then lands on different caps on BÉPO and on QWERTY. This
//! module is pure (no REAPER or ImGui calls), so that it can be unit tested;
//! ui.zig draws what it describes.
const std = @import("std");
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");

const Key = keymod.Key;
const VK = keymod.VK;

pub const View = enum { list, keyboard };
pub const Layout = enum { qwerty, bepo };
pub const Board = enum { staggered, ortho };

/// The color group of a binding. The first ten come from a `[labels]` entry
/// (`Name = Label | category`). The last four are the fallbacks used when an
/// action has no category: they follow the grammar type of the binding.
pub const Category = enum {
    select,
    extend,
    jump,
    pitch,
    time,
    length,
    quant,
    edit,
    view,
    mode,
    motion,
    operator,
    selector,
    command,
    group,

    pub fn title(self: Category) []const u8 {
        return switch (self) {
            .select => "select",
            .extend => "extend",
            .jump => "move cursor",
            .pitch => "pitch",
            .time => "time",
            .length => "length",
            .quant => "quantize",
            .edit => "edit",
            .view => "view",
            .mode => "mode",
            .motion => "motion",
            .operator => "operator",
            .selector => "selector",
            .command => "command",
            .group => "menu",
        };
    }
};

/// A short cap label and an optional category, from the `[labels]` section.
pub const Label = struct {
    text: []const u8,
    category: ?Category = null,
};

/// Parses a `[labels]` value: "Label" or "Label | category". An unknown
/// category is reported as an error, so that the config loader can warn.
pub fn parseLabel(raw: []const u8) error{ EmptyLabel, UnknownCategory }!Label {
    const bar = std.mem.lastIndexOfScalar(u8, raw, '|');
    const text = std.mem.trim(u8, if (bar) |i| raw[0..i] else raw, " \t");
    if (text.len == 0) return error.EmptyLabel;
    if (bar) |i| {
        const cat_name = std.mem.trim(u8, raw[i + 1 ..], " \t");
        const cat = std.meta.stringToEnum(Category, cat_name) orelse return error.UnknownCategory;
        return .{ .text = text, .category = cat };
    }
    return .{ .text = text };
}

/// The category of a binding without a `[labels]` category: menus are
/// groups, and actions follow their grammar type.
pub fn fallbackCategory(action_type: ?grammar.ActionType, is_group: bool) Category {
    if (is_group) return .group;
    const t = action_type orelse return .command;
    return switch (t) {
        .track_motion, .timeline_motion => .motion,
        .track_operator, .timeline_operator => .operator,
        .track_selector, .timeline_selector => .selector,
        .command => .command,
        .visual_track_command, .visual_timeline_command => .mode,
    };
}

/// One physical key. A character cap has the characters of its base and Shift
/// layers. A named cap (esc, tab, space, arrows) has a virtual-key code and a
/// glyph instead. `gap` is the empty space before the cap, in key units.
pub const Cap = struct {
    base: []const u8 = "",
    shifted: []const u8 = "",
    named: ?u8 = null,
    glyph: []const u8 = "",
    width: f64 = 1,
    gap: f64 = 0,
};

/// A row of caps, and its indent in key units on each board.
pub const Row = struct {
    ortho: f64,
    staggered: f64,
    caps: []const Cap,
};

fn c(base: []const u8, shifted: []const u8) Cap {
    return .{ .base = base, .shifted = shifted };
}

const esc_cap = Cap{ .named = VK.ESCAPE, .glyph = "esc" };
const tab_cap = Cap{ .named = VK.TAB, .glyph = "tab", .width = 1 };

/// Because the arrows sit under the right hand on both boards, the bottom row
/// is the space bar, a gap, then the four arrows.
const bottom_row = Row{ .ortho = 0, .staggered = 2.5, .caps = &.{
    .{ .named = VK.SPACE, .glyph = "space", .width = 6 },
    .{ .named = VK.LEFT, .glyph = "\xe2\x86\x90", .gap = 3 },
    .{ .named = VK.DOWN, .glyph = "\xe2\x86\x93" },
    .{ .named = VK.UP, .glyph = "\xe2\x86\x91" },
    .{ .named = VK.RIGHT, .glyph = "\xe2\x86\x92" },
} };

const bepo_rows = [_]Row{
    .{ .ortho = 0, .staggered = 0, .caps = &.{
        esc_cap,     c("$", "#"), c("\"", "1"), c("\xc2\xab", "2"), c("\xc2\xbb", "3"), c("(", "4"),        c(")", "5"),
        c("@", "6"), c("+", "7"), c("-", "8"),  c("/", "9"),        c("*", "0"),        c("=", "\xc2\xb0"), c("%", "`"),
    } },
    .{ .ortho = 0, .staggered = 0.5, .caps = &.{
        tab_cap,     c("b", "B"), c("\xc3\xa9", "\xc3\x89"), c("p", "P"), c("o", "O"), c("\xc3\xa8", "\xc3\x88"), c("^", "!"),
        c("v", "V"), c("d", "D"), c("l", "L"),               c("j", "J"), c("z", "Z"), c("w", "W"),
    } },
    .{ .ortho = 1, .staggered = 1.75, .caps = &.{
        c("a", "A"), c("u", "U"), c("i", "I"), c("e", "E"), c(",", ";"), c("c", "C"),
        c("t", "T"), c("s", "S"), c("r", "R"), c("n", "N"), c("m", "M"), c("\xc3\xa7", "\xc3\x87"),
    } },
    .{ .ortho = 0, .staggered = 1.25, .caps = &.{
        c("\xc3\xaa", "\xc3\x8a"), c("\xc3\xa0", "\xc3\x80"), c("y", "Y"), c("x", "X"), c(".", ":"), c("k", "K"),
        c("'", "?"),               c("q", "Q"),               c("g", "G"), c("h", "H"), c("f", "F"),
    } },
    bottom_row,
};

const qwerty_rows = [_]Row{
    .{ .ortho = 0, .staggered = 0, .caps = &.{
        esc_cap,     c("`", "~"), c("1", "!"), c("2", "@"), c("3", "#"), c("4", "$"), c("5", "%"),
        c("6", "^"), c("7", "&"), c("8", "*"), c("9", "("), c("0", ")"), c("-", "_"), c("=", "+"),
    } },
    .{ .ortho = 0, .staggered = 0.5, .caps = &.{
        tab_cap,     c("q", "Q"), c("w", "W"), c("e", "E"), c("r", "R"), c("t", "T"), c("y", "Y"),
        c("u", "U"), c("i", "I"), c("o", "O"), c("p", "P"), c("[", "{"), c("]", "}"),
    } },
    .{ .ortho = 1, .staggered = 1.75, .caps = &.{
        c("a", "A"), c("s", "S"), c("d", "D"), c("f", "F"), c("g", "G"),  c("h", "H"),
        c("j", "J"), c("k", "K"), c("l", "L"), c(";", ":"), c("'", "\""), c("\\", "|"),
    } },
    .{ .ortho = 1, .staggered = 2.25, .caps = &.{
        c("z", "Z"), c("x", "X"), c("c", "C"), c("v", "V"), c("b", "B"),
        c("n", "N"), c("m", "M"), c(",", "<"), c(".", ">"), c("/", "?"),
    } },
    bottom_row,
};

pub fn rows(layout: Layout) []const Row {
    return switch (layout) {
        .bepo => &bepo_rows,
        .qwerty => &qwerty_rows,
    };
}

/// The width of the widest row in key units, so that the caller can size the
/// caps to the window.
pub fn boardWidth(layout: Layout, board: Board) f64 {
    var widest: f64 = 0;
    for (rows(layout)) |row| {
        var w: f64 = if (board == .ortho) row.ortho else row.staggered;
        for (row.caps) |cap| w += cap.gap + cap.width;
        widest = @max(widest, w);
    }
    return widest;
}

pub const Layer = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
};

/// The character a character cap types on a layer. Shift picks the shifted
/// character; Ctrl and Alt do not change it.
pub fn charOf(cap: Cap, layer: Layer) []const u8 {
    return if (layer.shift) cap.shifted else cap.base;
}

/// The engine key that a cap produces on a layer, or null when the cap types
/// a character the binding notation cannot express (é, «, ç, ...).
///
/// Because the engine binds produced characters, a shifted punctuation cap is
/// its shifted character without a Shift flag ('?' rather than Shift+'), a
/// digit never carries Shift (AZERTY and BÉPO digits need it), and only
/// letters and named keys keep the Shift flag.
pub fn keyOf(cap: Cap, layer: Layer) ?Key {
    if (cap.named) |vk| {
        return .{ .vk = vk, .shift = layer.shift, .ctrl = layer.ctrl, .alt = layer.alt };
    }
    var k = keyForChar(charOf(cap, layer)) orelse return null;
    k.ctrl = layer.ctrl;
    k.alt = layer.alt;
    return k;
}

fn keyForChar(ch: []const u8) ?Key {
    if (ch.len != 1) return null;
    if (ch[0] == '<') return .{ .vk = '<', .is_char = true };
    const tok = keymod.parseToken(ch) catch return null;
    return tok.key;
}

/// A readable label made from an action name when `[labels]` has none:
/// "AddNextNoteToSelection" becomes "Add Next Note To Selection", and the
/// "_PERKEN_" or "_" prefix of a named command is dropped.
pub fn humanize(name: []const u8, buf: []u8) []const u8 {
    var src = name;
    if (std.mem.startsWith(u8, src, "_PERKEN_")) {
        src = src["_PERKEN_".len..];
    } else if (src.len > 0 and src[0] == '_') {
        src = src[1..];
    }
    var n: usize = 0;
    for (src, 0..) |ch, i| {
        if (n + 2 > buf.len) break;
        const prev_lower = i > 0 and (std.ascii.isLower(src[i - 1]) or std.ascii.isDigit(src[i - 1]));
        if (std.ascii.isUpper(ch) and prev_lower) {
            buf[n] = ' ';
            n += 1;
        }
        buf[n] = if (ch == '_') ' ' else ch;
        n += 1;
    }
    return buf[0..n];
}

// ---- tests ----

test "keyOf follows the produced character, not the physical key" {
    const bepo = rows(.bepo);
    // The BÉPO cap under the QWERTY "q" types b, and B with Shift.
    const b_cap = bepo[1].caps[1];
    try std.testing.expect(keyOf(b_cap, .{}).?.eql(.{ .vk = 'B' }));
    try std.testing.expect(keyOf(b_cap, .{ .shift = true }).?.eql(.{ .vk = 'B', .shift = true }));
    try std.testing.expect(keyOf(b_cap, .{ .ctrl = true }).?.eql(.{ .vk = 'B', .ctrl = true }));

    // A BÉPO digit needs Shift but is bound as a plain digit.
    const one = bepo[0].caps[2];
    try std.testing.expect(keyOf(one, .{ .shift = true }).?.eql(.{ .vk = '1' }));
    try std.testing.expect(keyOf(one, .{}).?.eql(.{ .vk = '"', .is_char = true }));

    // é is not expressible in the binding notation.
    try std.testing.expect(keyOf(bepo[1].caps[2], .{}) == null);

    // A shifted QWERTY punctuation cap is its shifted character.
    const comma = rows(.qwerty)[3].caps[7];
    try std.testing.expect(keyOf(comma, .{ .shift = true }).?.eql(.{ .vk = '<', .is_char = true }));
}

test "keyOf on named caps keeps every modifier" {
    const left = bottom_row.caps[1];
    const k = keyOf(left, .{ .shift = true, .ctrl = true }).?;
    try std.testing.expect(k.eql(.{ .vk = VK.LEFT, .shift = true, .ctrl = true }));
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("<C-S-left>", keymod.format(k, &buf));
}

test "keyOf matches the notation used in bindings.ini" {
    const cases = [_]struct { cap: Cap, layer: Layer, notation: []const u8 }{
        .{ .cap = rows(.bepo)[2].caps[3], .layer = .{ .shift = true }, .notation = "E" },
        .{ .cap = rows(.bepo)[3].caps[9], .layer = .{ .ctrl = true }, .notation = "<C-h>" },
        .{ .cap = rows(.bepo)[3].caps[9], .layer = .{ .ctrl = true, .shift = true }, .notation = "<C-H>" },
        .{ .cap = rows(.bepo)[0].caps[8], .layer = .{ .ctrl = true }, .notation = "<C-+>" },
        .{ .cap = rows(.bepo)[2].caps[6], .layer = .{ .alt = true }, .notation = "<M-t>" },
    };
    for (cases) |cs| {
        const want = (try keymod.parseToken(cs.notation)).key;
        try std.testing.expect(keyOf(cs.cap, cs.layer).?.eql(want));
    }
}

test "boards are as wide as their widest row" {
    try std.testing.expectEqual(@as(f64, 14), boardWidth(.bepo, .ortho));
    try std.testing.expectEqual(@as(f64, 14), boardWidth(.qwerty, .ortho));
    try std.testing.expect(boardWidth(.qwerty, .staggered) > 14);
}

test "parseLabel reads the text and the optional category" {
    const plain = try parseLabel("Next note");
    try std.testing.expectEqualStrings("Next note", plain.text);
    try std.testing.expect(plain.category == null);

    const cat = try parseLabel(" Extend \xe2\x86\x92 | extend ");
    try std.testing.expectEqualStrings("Extend \xe2\x86\x92", cat.text);
    try std.testing.expectEqual(Category.extend, cat.category.?);

    try std.testing.expectError(error.UnknownCategory, parseLabel("X | nope"));
    try std.testing.expectError(error.EmptyLabel, parseLabel(" | edit"));
}

test "humanize splits camel case and drops command prefixes" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("Add Next Note To Selection", humanize("AddNextNoteToSelection", &buf));
    try std.testing.expectEqualStrings("Legato", humanize("_PERKEN_Legato", &buf));
    try std.testing.expectEqualStrings("SWS AWFILLGAPS", humanize("_SWS_AWFILLGAPS", &buf));
    try std.testing.expectEqualStrings("Pitch Up7", humanize("PitchUp7", &buf));
}

test "fallback categories follow the grammar type" {
    try std.testing.expectEqual(Category.group, fallbackCategory(.command, true));
    try std.testing.expectEqual(Category.motion, fallbackCategory(.timeline_motion, false));
    try std.testing.expectEqual(Category.operator, fallbackCategory(.track_operator, false));
    try std.testing.expectEqual(Category.command, fallbackCategory(null, false));
}
