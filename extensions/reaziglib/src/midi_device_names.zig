//! How a control surface finds its MIDI devices again after REAPER restarts. REAPER numbers the MIDI devices of Linux from a list that
//! it keeps, in which a device that is plugged in at another USB port, or that PipeWire names another way, is a new entry: the number
//! that a surface saved is of an entry that is not used any more, and the console is "not mapped" the next time. The name of such a
//! device is made of the client and of the port, as in
//!
//!   Midi-Bridge:Softube AB Console 1 at usb-0000:00:14-0-2- full speed:(capture_0) Console 1 MIDI 1
//!   Midi-Bridge:Console 1 2:(capture_0) Console 1 MIDI 1
//!
//! of which the client changes and the port does not. The surface saves the port, and looks for it among the devices that are there.
const std = @import("std");

/// The longest key that is kept: a port description is a few dozen letters, and the longest names of devices are cut.
pub const max_key = 200;

/// What identifies a device from one session to the next: the description of its port, which follows the client in the name that
/// REAPER gives it, or the whole name when it has no client (an ALSA device, or the name that a driver gives).
pub fn key(name: []const u8) []const u8 {
    const port_at = std.mem.indexOf(u8, name, ":(") orelse return limited(name);
    return limited(name[port_at + 1 ..]);
}

fn limited(text: []const u8) []const u8 {
    return text[0..@min(text.len, max_key)];
}

/// Writes a key in a form that has no space, so that it is one word of the config string: the letters, the digits, the dot and the
/// underscore as they are, and the other bytes as `%` and their two hexadecimal digits. An empty key is written as `-`, which
/// the encoding of anything else never gives.
pub fn encode(buf: []u8, text: []const u8) []const u8 {
    if (text.len == 0) return "-";
    const digits = "0123456789ABCDEF";
    var length: usize = 0;
    for (text) |byte| {
        const plain = std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '_';
        const needed: usize = if (plain) 1 else 3;
        if (length + needed > buf.len) break;
        if (plain) {
            buf[length] = byte;
        } else {
            buf[length] = '%';
            buf[length + 1] = digits[byte >> 4];
            buf[length + 2] = digits[byte & 0x0F];
        }
        length += needed;
    }
    return buf[0..length];
}

/// The key that a word of the config string stands for, or null when it stands for no device (`-`, or something that is not an
/// encoding).
pub fn decode(buf: []u8, word: []const u8) ?[]const u8 {
    if (word.len == 0 or std.mem.eql(u8, word, "-")) return null;
    var length: usize = 0;
    var at: usize = 0;
    while (at < word.len) {
        if (length >= buf.len) break;
        if (word[at] == '%') {
            // An encoding that is cut short is not one.
            if (at + 3 > word.len) return null;
            const value = std.fmt.parseInt(u8, word[at + 1 .. at + 3], 16) catch return null;
            buf[length] = value;
            at += 3;
        } else {
            buf[length] = word[at];
            at += 1;
        }
        length += 1;
    }
    return if (length == 0) null else buf[0..length];
}

/// The keys of the devices that a config string has after its four numbers, which are null when it has none: the config strings that
/// an older version saved only have the numbers. The words that follow the numbers are the input and the output.
pub const Keys = struct {
    in_buf: [max_key]u8 = undefined,
    out_buf: [max_key]u8 = undefined,
    in: ?[]const u8 = null,
    out: ?[]const u8 = null,
};

/// Reads the keys of a config string, which are its fifth and sixth words.
pub fn parseKeys(config: []const u8, keys: *Keys) void {
    keys.in = null;
    keys.out = null;
    var iterator = std.mem.tokenizeScalar(u8, config, ' ');
    var word: u8 = 0;
    while (iterator.next()) |token| : (word += 1) {
        if (word == 4) keys.in = decode(&keys.in_buf, token);
        if (word == 5) keys.out = decode(&keys.out_buf, token);
    }
}

/// The device that has this key among the ones that are there, the first when several have it, or null. `source` tells how many
/// numbers there are, and the name of the device of a number, which is null for a number that has no device.
pub fn find(source: anytype, wanted: []const u8) ?c_int {
    var name_buf: [512]u8 = undefined;
    const count = source.count();
    var dev: c_int = 0;
    while (dev < count) : (dev += 1) {
        const name = source.name(dev, &name_buf) orelse continue;
        if (std.mem.eql(u8, key(name), wanted)) return dev;
    }
    return null;
}

const Fake = struct {
    names: []const ?[]const u8,

    pub fn count(self: Fake) c_int {
        return @intCast(self.names.len);
    }

    pub fn name(self: Fake, dev: c_int, buf: []u8) ?[]const u8 {
        const text = self.names[@intCast(dev)] orelse return null;
        @memcpy(buf[0..text.len], text);
        return buf[0..text.len];
    }
};

test "the key of a device is the description of its port, whatever its client is" {
    const a = key("Midi-Bridge:Softube AB Console 1 at usb-0000:00:14-0-2- full speed:(capture_0) Console 1 MIDI 1");
    const b = key("Midi-Bridge:Console 1 2:(capture_0) Console 1 MIDI 1");
    try std.testing.expectEqualStrings("(capture_0) Console 1 MIDI 1", a);
    try std.testing.expectEqualStrings(a, b);
    // A name that has no client is the key as it is.
    try std.testing.expectEqualStrings("MIDI Output 2", key("MIDI Output 2"));
    // A long one is cut.
    const long: [400]u8 = @splat('x');
    try std.testing.expectEqual(@as(usize, max_key), key(&long).len);
}

test "a key is a word of the config string, and comes back from it" {
    var encoded_buf: [600]u8 = undefined;
    var decoded_buf: [600]u8 = undefined;
    const original = "(capture_0) Console 1 MIDI 1";
    const word = encode(&encoded_buf, original);
    try std.testing.expect(std.mem.indexOfScalar(u8, word, ' ') == null);
    try std.testing.expectEqualStrings(original, decode(&decoded_buf, word).?);

    // No device is a dash, which no key is written as, and what is not an encoding is no device.
    try std.testing.expectEqualStrings("-", encode(&encoded_buf, ""));
    try std.testing.expect(decode(&decoded_buf, "-") == null);
    try std.testing.expect(decode(&decoded_buf, "") == null);
    try std.testing.expect(decode(&decoded_buf, "%G1") == null);
    const dashed = encode(&encoded_buf, "-");
    try std.testing.expect(!std.mem.eql(u8, dashed, "-"));
    try std.testing.expectEqualStrings("-", decode(&decoded_buf, dashed).?);
}

test "the device is found again under another client and another number, and not when it is not there" {
    // The console was the device 1 under the client that it had, and is the device 3 under another one.
    const devices = Fake{ .names = &.{
        "Midi-Bridge:Midi Through:(capture_0) Midi Through Port-0",
        "Midi-Bridge:Softube AB Console 1 at usb-0000:00:14-0-2-3-1- full speed:(capture_0) Console 1 MIDI 1",
        null,
        "Midi-Bridge:Console 1 3:(capture_0) Console 1 MIDI 1",
    } };
    // A number that has no device is skipped: the entry 1 is a client that was there, and the device that is there is the 3. Here both
    // are listed, so the first with the port is taken, and the test below has the entry that is gone.
    try std.testing.expectEqual(@as(?c_int, 1), find(devices, "(capture_0) Console 1 MIDI 1"));
    const only_new = Fake{ .names = &.{
        "Midi-Bridge:Midi Through:(capture_0) Midi Through Port-0",
        null,
        null,
        "Midi-Bridge:Console 1 3:(capture_0) Console 1 MIDI 1",
    } };
    try std.testing.expectEqual(@as(?c_int, 3), find(only_new, "(capture_0) Console 1 MIDI 1"));
    try std.testing.expectEqual(@as(?c_int, null), find(only_new, "(capture_0) Another MIDI 1"));
}

test "the keys are the fifth and the sixth words of a config, and an older config has none" {
    var keys: Keys = .{};
    parseKeys("0 0 87 91", &keys);
    try std.testing.expect(keys.in == null and keys.out == null);

    var word_buf: [3 * max_key]u8 = undefined;
    var config_buf: [512]u8 = undefined;
    const config = std.fmt.bufPrint(&config_buf, "0 0 87 91 {s} -", .{encode(&word_buf, "(capture_0) Console 1 MIDI 1")}) catch unreachable;
    parseKeys(config, &keys);
    try std.testing.expectEqualStrings("(capture_0) Console 1 MIDI 1", keys.in.?);
    try std.testing.expect(keys.out == null);
}
