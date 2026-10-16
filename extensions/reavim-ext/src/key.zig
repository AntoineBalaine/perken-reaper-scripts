//! Key encoding: a keystroke is a win32 virtual-key code plus modifier flags
//! (SWELL delivers standard win32 VKs on all platforms). Bindings are written
//! in vim notation and parsed into Key values at config load.
//!
//! Supported notation: letters ("g" / "G" = shift), digits, named keys
//! ("<space>", "<esc>", "<cr>", "<tab>", "<up>", ...), modifier wraps
//! ("<C-d>", "<M-x>", "<C-M-p>"), and a raw escape hatch ("<vk=0x41>").
//! Punctuation is TODO pending a probe round: several ASCII codes collide with
//! VK codes (e.g. '.' = 0x2E = VK_DELETE), so we need to see what SWELL
//! actually delivers before committing a table.
const std = @import("std");

pub const Key = packed struct(u16) {
    vk: u8,
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    /// True when vk holds a literal ASCII character (punctuation) rather than
    /// a virtual-key code — SWELL delivers punctuation as raw ASCII without
    /// FVIRTKEY, already shifted ('?' arrives as 0x3F on any layout).
    is_char: bool = false,
    _pad: u4 = 0,

    pub fn bits(self: Key) u16 {
        return @bitCast(self);
    }

    pub fn eql(a: Key, b: Key) bool {
        return a.bits() == b.bits();
    }
};

pub const VK = struct {
    pub const BACK: u8 = 0x08;
    pub const TAB: u8 = 0x09;
    pub const RETURN: u8 = 0x0d;
    pub const ESCAPE: u8 = 0x1b;
    pub const SPACE: u8 = 0x20;
    pub const PRIOR: u8 = 0x21; // page up
    pub const NEXT: u8 = 0x22; // page down
    pub const END: u8 = 0x23;
    pub const HOME: u8 = 0x24;
    pub const LEFT: u8 = 0x25;
    pub const UP: u8 = 0x26;
    pub const RIGHT: u8 = 0x27;
    pub const DOWN: u8 = 0x28;
    pub const INSERT: u8 = 0x2d;
    pub const DELETE: u8 = 0x2e;
    pub const F1: u8 = 0x70;
};

const named_keys = std.StaticStringMap(u8).initComptime(.{
    .{ "space", VK.SPACE },
    .{ "esc", VK.ESCAPE },
    .{ "cr", VK.RETURN },
    .{ "return", VK.RETURN },
    .{ "enter", VK.RETURN },
    .{ "tab", VK.TAB },
    .{ "bs", VK.BACK },
    .{ "del", VK.DELETE },
    .{ "ins", VK.INSERT },
    .{ "up", VK.UP },
    .{ "down", VK.DOWN },
    .{ "left", VK.LEFT },
    .{ "right", VK.RIGHT },
    .{ "home", VK.HOME },
    .{ "end", VK.END },
    .{ "pageup", VK.PRIOR },
    .{ "pagedown", VK.NEXT },
});

/// Builds the canonical Key for an incoming key event (SWELL semantics).
/// - numpad digits normalize to plain digits (counts work from the numpad)
/// - GDK keyvals are layout-resolved: on layouts where digits need Shift
///   (AZERTY), a digit arrives as vk '0'-'9' WITH the shift flag — the shift
///   was consumed producing the digit and must not survive into the token
/// - non-virtual keys are literal ASCII chars, already shifted ('?' is 0x3F)
pub fn fromEvent(vk: u8, virt: bool, shift: bool, ctrl: bool, alt: bool) Key {
    const norm_vk: u8 = if (virt and vk >= 0x60 and vk <= 0x69) '0' + (vk - 0x60) else vk;
    const digit_vk = norm_vk >= '0' and norm_vk <= '9';
    return .{
        .vk = norm_vk,
        .ctrl = ctrl,
        .shift = if (virt and !digit_vk) shift else false,
        .alt = alt,
        .is_char = !virt and vk != VK.SPACE,
    };
}

test "fromEvent: AZERTY shifted digits become plain digits" {
    const k = fromEvent(0x31, true, true, false, false); // '1' with shift held
    try std.testing.expectEqual(@as(u8, '1'), k.vk);
    try std.testing.expect(!k.shift);
    try std.testing.expect(!k.is_char);
}

test "fromEvent: numpad digits normalize; letters keep shift; chars pre-shifted" {
    const np = fromEvent(0x65, true, false, false, false); // VK_NUMPAD5
    try std.testing.expectEqual(@as(u8, '5'), np.vk);

    const J = fromEvent('J', true, true, false, false);
    try std.testing.expect(J.shift);

    const q = fromEvent('?', false, false, false, false);
    try std.testing.expect(q.is_char);
    try std.testing.expectEqual(@as(u8, '?'), q.vk);
}

pub const ParseError = error{
    UnknownKeyName,
    UnknownModifier,
    UnterminatedBracket,
    EmptyToken,
    UnsupportedCharacter,
    InvalidVkEscape,
};

/// Parses one token from the start of `input`. Returns the key and the number
/// of bytes consumed. Tokens: a bare character, or one <...> group.
pub fn parseToken(input: []const u8) ParseError!struct { key: Key, len: usize } {
    if (input.len == 0) return error.EmptyToken;

    if (input[0] == '<') {
        const close = std.mem.indexOfScalar(u8, input, '>') orelse return error.UnterminatedBracket;
        const inner = input[1..close];
        if (inner.len == 0) return error.EmptyToken;
        var key = try parseBracketGroup(inner);
        _ = &key;
        return .{ .key = key, .len = close + 1 };
    }

    return .{ .key = try parseBareChar(input[0]), .len = 1 };
}

/// Parses a full sequence like "gg" or "<C-w>j" into keys appended to `out`.
pub fn parseSequence(input: []const u8, out: *std.ArrayList(Key)) ParseError!void {
    var rest = input;
    while (rest.len > 0) {
        const tok = try parseToken(rest);
        out.append(tok.key) catch return error.EmptyToken;
        rest = rest[tok.len..];
    }
}

fn parseBareChar(c: u8) ParseError!Key {
    return switch (c) {
        'a'...'z' => .{ .vk = std.ascii.toUpper(c) },
        'A'...'Z' => .{ .vk = c, .shift = true },
        '0'...'9' => .{ .vk = c },
        ' ' => .{ .vk = VK.SPACE },
        // Printable punctuation: literal ASCII char keys ('<' needs <lt>).
        '!'...'/', ':'...'@', '['...'`', '{'...'~' => .{ .vk = c, .is_char = true },
        else => error.UnsupportedCharacter,
    };
}

fn parseBracketGroup(inner: []const u8) ParseError!Key {
    var ctrl = false;
    var shift = false;
    var alt = false;
    var rest = inner;

    while (rest.len >= 2 and rest[1] == '-') {
        switch (rest[0]) {
            'C', 'c' => ctrl = true,
            'S', 's' => shift = true,
            'M', 'm', 'A', 'a' => alt = true,
            else => return error.UnknownModifier,
        }
        rest = rest[2..];
    }
    if (rest.len == 0) return error.EmptyToken;

    var key: Key = blk: {
        if (rest.len == 1) break :blk try parseBareChar(rest[0]);

        if (std.mem.eql(u8, rest, "lt"))
            break :blk Key{ .vk = '<', .is_char = true };

        if (std.mem.startsWith(u8, rest, "vk=")) {
            const vk = std.fmt.parseInt(u8, rest[3..], 0) catch return error.InvalidVkEscape;
            break :blk .{ .vk = vk };
        }

        // F1..F12
        if ((rest[0] == 'F' or rest[0] == 'f') and rest.len <= 3) {
            if (std.fmt.parseInt(u8, rest[1..], 10)) |n| {
                if (n >= 1 and n <= 12) break :blk .{ .vk = VK.F1 + n - 1 };
            } else |_| {}
        }

        var lower_buf: [16]u8 = undefined;
        if (rest.len > lower_buf.len) return error.UnknownKeyName;
        const lower = std.ascii.lowerString(&lower_buf, rest);
        const vk = named_keys.get(lower) orelse return error.UnknownKeyName;
        break :blk .{ .vk = vk };
    };

    key.ctrl = key.ctrl or ctrl;
    key.shift = key.shift or shift;
    key.alt = key.alt or alt;
    return key;
}

/// Formats a key back to vim notation (for the feedback UI / logs).
pub fn format(key: Key, buf: []u8) []const u8 {
    var fbs = std.io.fixedBufferStream(buf);
    const w = fbs.writer();

    const name: ?[]const u8 = switch (key.vk) {
        VK.SPACE => "space",
        VK.ESCAPE => "esc",
        VK.RETURN => "cr",
        VK.TAB => "tab",
        VK.BACK => "bs",
        VK.DELETE => "del",
        VK.INSERT => "ins",
        VK.UP => "up",
        VK.DOWN => "down",
        VK.LEFT => "left",
        VK.RIGHT => "right",
        VK.HOME => "home",
        VK.END => "end",
        VK.PRIOR => "pageup",
        VK.NEXT => "pagedown",
        else => null,
    };

    const is_letter = !key.is_char and key.vk >= 'A' and key.vk <= 'Z';
    const is_digit = !key.is_char and key.vk >= '0' and key.vk <= '9';
    const is_plain_char = key.is_char and !key.ctrl and !key.alt and key.vk != '<';
    const needs_bracket = key.ctrl or key.alt or name != null or
        (!is_letter and !is_digit and !is_plain_char) or (key.shift and !is_letter);

    if (!needs_bracket) {
        const c: u8 = if (is_letter and !key.shift) std.ascii.toLower(key.vk) else key.vk;
        w.writeByte(c) catch return fbs.getWritten();
        return fbs.getWritten();
    }

    w.writeByte('<') catch return fbs.getWritten();
    if (key.ctrl) w.writeAll("C-") catch return fbs.getWritten();
    if (key.alt) w.writeAll("M-") catch return fbs.getWritten();
    if (key.shift and !is_letter) w.writeAll("S-") catch return fbs.getWritten();
    if (key.is_char) {
        if (key.vk == '<') {
            w.writeAll("lt") catch return fbs.getWritten();
        } else {
            w.writeByte(key.vk) catch return fbs.getWritten();
        }
    } else if (name) |n| {
        w.writeAll(n) catch return fbs.getWritten();
    } else if (is_letter) {
        w.writeByte(if (key.shift) key.vk else std.ascii.toLower(key.vk)) catch return fbs.getWritten();
    } else if (key.vk >= VK.F1 and key.vk < VK.F1 + 12) {
        w.print("F{d}", .{key.vk - VK.F1 + 1}) catch return fbs.getWritten();
    } else {
        w.print("vk=0x{x:0>2}", .{key.vk}) catch return fbs.getWritten();
    }
    w.writeByte('>') catch return fbs.getWritten();
    return fbs.getWritten();
}

test "parse bare letters and shift" {
    const g = try parseToken("g");
    try std.testing.expectEqual(@as(u8, 'G'), g.key.vk);
    try std.testing.expect(!g.key.shift);

    const G = try parseToken("G");
    try std.testing.expect(G.key.shift);
    try std.testing.expectEqual(@as(u8, 'G'), G.key.vk);
}

test "parse modifier groups" {
    const cd = try parseToken("<C-d>");
    try std.testing.expect(cd.key.ctrl);
    try std.testing.expectEqual(@as(u8, 'D'), cd.key.vk);
    try std.testing.expectEqual(@as(usize, 5), cd.len);

    const cmp = try parseToken("<C-M-p>");
    try std.testing.expect(cmp.key.ctrl and cmp.key.alt);
}

test "parse named keys and escapes" {
    const esc = try parseToken("<esc>");
    try std.testing.expectEqual(VK.ESCAPE, esc.key.vk);

    const f5 = try parseToken("<F5>");
    try std.testing.expectEqual(VK.F1 + 4, f5.key.vk);

    const raw = try parseToken("<vk=0xBA>");
    try std.testing.expectEqual(@as(u8, 0xBA), raw.key.vk);
}

test "parse sequence" {
    var keys = std.ArrayList(Key).init(std.testing.allocator);
    defer keys.deinit();
    try parseSequence("g<C-w>5J", &keys);
    try std.testing.expectEqual(@as(usize, 4), keys.items.len);
    try std.testing.expectEqual(@as(u8, 'G'), keys.items[0].vk);
    try std.testing.expect(keys.items[1].ctrl);
    try std.testing.expectEqual(@as(u8, '5'), keys.items[2].vk);
    try std.testing.expect(keys.items[3].shift);
}

test "format round trip" {
    var buf: [16]u8 = undefined;
    try std.testing.expectEqualStrings("g", format(.{ .vk = 'G' }, &buf));
    try std.testing.expectEqualStrings("G", format(.{ .vk = 'G', .shift = true }, &buf));
    try std.testing.expectEqualStrings("<C-d>", format(.{ .vk = 'D', .ctrl = true }, &buf));
    try std.testing.expectEqualStrings("<esc>", format(.{ .vk = VK.ESCAPE }, &buf));
    try std.testing.expectEqualStrings("<space>", format(.{ .vk = VK.SPACE }, &buf));
}
