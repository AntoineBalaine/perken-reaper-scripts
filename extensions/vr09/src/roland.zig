//! Roland SysEx for the VR-09: the DT1 (write) and RQ1 (read) messages, their
//! checksum, and the parsing of what the keyboard sends back.
//!
//! Because the keyboard part and the synth section use different model ids
//! and address widths, every message carries a `Kind` that selects both. The
//! formats come from `docs/midi-capabilities.md` in the roland-vr09 project.
const std = @import("std");

pub const device_id: u8 = 0x10;
pub const roland_id: u8 = 0x41;

pub const sysex_start: u8 = 0xF0;
pub const sysex_end: u8 = 0xF7;

/// Which sound generator a message addresses.
pub const Kind = enum {
    /// The keyboard part: model 62H, three-byte addresses and sizes.
    kb,
    /// The synth section: model 00 00 71H, four-byte addresses and sizes.
    synth,

    pub fn model(self: Kind) []const u8 {
        return switch (self) {
            .kb => &[_]u8{0x62},
            .synth => &[_]u8{ 0x00, 0x00, 0x71 },
        };
    }

    pub fn addressLen(self: Kind) usize {
        return switch (self) {
            .kb => 3,
            .synth => 4,
        };
    }
};

pub const Command = enum(u8) {
    rq1 = 0x11,
    dt1 = 0x12,
};

/// The longest message we build or accept: header, a four-byte address, a
/// 0x69-byte block and the checksum fit with room to spare.
pub const max_message = 256;

/// Roland's checksum: the value that brings the sum of the address and data
/// bytes to a multiple of 128.
pub fn checksum(bytes: []const u8) u8 {
    var sum: u32 = 0;
    for (bytes) |b| sum += b;
    return @intCast((128 - sum % 128) % 128);
}

/// Splits `value` into `out.len` bytes of seven bits each, most significant
/// first, which is how addresses and sizes travel.
pub fn packSevenBit(value: u32, out: []u8) void {
    var i: usize = out.len;
    var v = value;
    while (i > 0) {
        i -= 1;
        out[i] = @intCast(v & 0x7F);
        v >>= 7;
    }
}

pub fn unpackSevenBit(bytes: []const u8) u32 {
    var v: u32 = 0;
    for (bytes) |b| v = (v << 7) | (b & 0x7F);
    return v;
}

pub const EncodeError = error{BufferTooSmall};

fn writeHeader(out: []u8, kind: Kind, command: Command) usize {
    var n: usize = 0;
    out[n] = sysex_start;
    out[n + 1] = roland_id;
    out[n + 2] = device_id;
    n += 3;
    const model = kind.model();
    @memcpy(out[n .. n + model.len], model);
    n += model.len;
    out[n] = @backingInt(command);
    return n + 1;
}

/// Writes `F0 41 10 <model> 12 <address> <data> <checksum> F7` into `out` and
/// returns its length.
pub fn encodeDt1(out: []u8, kind: Kind, address: u32, data: []const u8) EncodeError!usize {
    const addr_len = kind.addressLen();
    const need = 3 + kind.model().len + 1 + addr_len + data.len + 2;
    if (out.len < need) return error.BufferTooSmall;
    var n = writeHeader(out, kind, .dt1);
    const body_start = n;
    packSevenBit(address, out[n .. n + addr_len]);
    n += addr_len;
    @memcpy(out[n .. n + data.len], data);
    n += data.len;
    out[n] = checksum(out[body_start..n]);
    out[n + 1] = sysex_end;
    return n + 2;
}

/// Writes `F0 41 10 <model> 11 <address> <size> <checksum> F7` into `out` and
/// returns its length.
pub fn encodeRq1(out: []u8, kind: Kind, address: u32, size: u32) EncodeError!usize {
    const addr_len = kind.addressLen();
    const need = 3 + kind.model().len + 1 + addr_len * 2 + 2;
    if (out.len < need) return error.BufferTooSmall;
    var n = writeHeader(out, kind, .rq1);
    const body_start = n;
    packSevenBit(address, out[n .. n + addr_len]);
    n += addr_len;
    packSevenBit(size, out[n .. n + addr_len]);
    n += addr_len;
    out[n] = checksum(out[body_start..n]);
    out[n + 1] = sysex_end;
    return n + 2;
}

/// The Identity Request that tells the MIDI IN mode of the unit.
pub const identity_request = [_]u8{ 0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7 };

pub const MidiInMode = enum { mode1, mode2, unknown };

/// Reads an Identity Reply. In Mode 2 the bytes after the Roland id are
/// `62 00 ...`, in Mode 1 they are `42 00 ...`; only Mode 2 addresses the
/// keyboard part with model 62H.
pub fn identityMode(message: []const u8) ?MidiInMode {
    const body = stripFraming(message);
    // 7E <device> 06 02 41 <family lsb> <family msb> ...
    if (body.len < 7) return null;
    if (body[0] != 0x7E or body[2] != 0x06 or body[3] != 0x02 or body[4] != roland_id) return null;
    return switch (body[5]) {
        0x62 => .mode2,
        0x42 => .mode1,
        else => .unknown,
    };
}

/// Removes a leading F0 and a trailing F7 when they are present. Because
/// hosts differ on whether a SysEx event includes its framing bytes, every
/// parser accepts both forms.
pub fn stripFraming(message: []const u8) []const u8 {
    var body = message;
    if (body.len > 0 and body[0] == sysex_start) body = body[1..];
    if (body.len > 0 and body[body.len - 1] == sysex_end) body = body[0 .. body.len - 1];
    return body;
}

/// A data message received from the keyboard.
pub const Dt1 = struct {
    kind: Kind,
    address: u32,
    len: u8,
    data: [max_message]u8,

    pub fn bytes(self: *const Dt1) []const u8 {
        return self.data[0..self.len];
    }
};

pub const ParseError = error{ NotRoland, WrongModel, NotDt1, TooShort, BadChecksum };

/// Parses one complete SysEx message (framing optional) as a DT1.
pub fn parseDt1(message: []const u8) ParseError!Dt1 {
    const body = stripFraming(message);
    if (body.len < 3) return error.TooShort;
    if (body[0] != roland_id or body[1] != device_id) return error.NotRoland;
    const rest = body[2..];
    const kind: Kind = blk: {
        if (rest.len >= 1 and rest[0] == 0x62) break :blk .kb;
        if (rest.len >= 3 and rest[0] == 0x00 and rest[1] == 0x00 and rest[2] == 0x71) break :blk .synth;
        return error.WrongModel;
    };
    const model_len = kind.model().len;
    // command, address, at least no data, checksum
    const addr_len = kind.addressLen();
    if (rest.len < model_len + 1 + addr_len + 1) return error.TooShort;
    if (rest[model_len] != @backingInt(Command.dt1)) return error.NotDt1;
    const payload = rest[model_len + 1 ..];
    const given = payload[payload.len - 1];
    const covered = payload[0 .. payload.len - 1];
    if (checksum(covered) != given) return error.BadChecksum;
    const data = covered[addr_len..];
    if (data.len > max_message) return error.TooShort;
    var result = Dt1{
        .kind = kind,
        .address = unpackSevenBit(covered[0..addr_len]),
        .len = @intCast(data.len),
        .data = undefined,
    };
    @memcpy(result.data[0..data.len], data);
    return result;
}

/// Reassembles SysEx messages from a raw byte stream, dropping the realtime
/// bytes (F8 to FF) that the unit interleaves, even inside a reply. The plugin
/// receives whole messages from the host, so this is the fallback for a host
/// that splits a message across several events.
pub const StreamParser = struct {
    buf: [max_message * 2]u8 = undefined,
    len: usize = 0,
    inside: bool = false,

    /// Feeds one byte; returns the complete message (framing included) when
    /// this byte ends one. The slice stays valid until the next call.
    pub fn feed(self: *StreamParser, byte: u8) ?[]const u8 {
        if (byte >= 0xF8) return null;
        if (byte == sysex_start) {
            self.inside = true;
            self.len = 0;
        }
        if (!self.inside) return null;
        if (self.len == self.buf.len) {
            self.inside = false;
            self.len = 0;
            return null;
        }
        self.buf[self.len] = byte;
        self.len += 1;
        if (byte == sysex_end) {
            self.inside = false;
            return self.buf[0..self.len];
        }
        return null;
    }
};

test "checksum matches the example in Roland's document" {
    // Setting the upper synth tone to JP8 Brass: address 01 03 01, data 59 01 00.
    const body = [_]u8{ 0x01, 0x03, 0x01, 0x59, 0x01, 0x00 };
    try std.testing.expectEqual(@as(u8, 0x21), checksum(&body));
}

test "encodeDt1 builds the documented JP8 Brass message" {
    var out: [32]u8 = undefined;
    const n = try encodeDt1(&out, .kb, 0x01 << 14 | 0x03 << 7 | 0x01, &.{ 0x59, 0x01, 0x00 });
    const expected = [_]u8{ 0xF0, 0x41, 0x10, 0x62, 0x12, 0x01, 0x03, 0x01, 0x59, 0x01, 0x00, 0x21, 0xF7 };
    try std.testing.expectEqualSlices(u8, &expected, out[0..n]);
}

test "encodeDt1 builds the documented Grand Piano message" {
    var out: [32]u8 = undefined;
    const n = try encodeDt1(&out, .kb, 0x01 << 14 | 0x01 << 7 | 0x01, &.{ 0x38, 0x02, 0x00 });
    const expected = [_]u8{ 0xF0, 0x41, 0x10, 0x62, 0x12, 0x01, 0x01, 0x01, 0x38, 0x02, 0x00, 0x43, 0xF7 };
    try std.testing.expectEqualSlices(u8, &expected, out[0..n]);
}

test "encodeRq1 for the synth section uses four-byte addresses and sizes" {
    var out: [32]u8 = undefined;
    const address: u32 = 0x18 << 21 | 0x00 << 14 | 0x22 << 7 | 0x00;
    const n = try encodeRq1(&out, .synth, address, 9);
    try std.testing.expectEqual(@as(usize, 3 + 3 + 1 + 8 + 2), n);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xF0, 0x41, 0x10, 0x00, 0x00, 0x71, 0x11 }, out[0..7]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x18, 0x00, 0x22, 0x00, 0, 0, 0, 9 }, out[7..15]);
    try std.testing.expectEqual(checksum(out[7..15]), out[15]);
    try std.testing.expectEqual(@as(u8, 0xF7), out[16]);
}

test "encodeDt1 rejects a buffer that is too small" {
    var out: [4]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, encodeDt1(&out, .kb, 0, &.{1}));
}

test "parseDt1 round trips an encoded message" {
    var out: [32]u8 = undefined;
    const address: u32 = 0x02 << 14 | 0x00 << 7 | 0x05;
    const n = try encodeDt1(&out, .kb, address, &.{8});
    const parsed = try parseDt1(out[0..n]);
    try std.testing.expectEqual(Kind.kb, parsed.kind);
    try std.testing.expectEqual(address, parsed.address);
    try std.testing.expectEqualSlices(u8, &[_]u8{8}, parsed.bytes());
    // Without the framing bytes the same message parses the same.
    const bare = try parseDt1(out[1 .. n - 1]);
    try std.testing.expectEqual(parsed.address, bare.address);
}

test "parseDt1 reads a synth section message" {
    var out: [32]u8 = undefined;
    const address: u32 = 0x18 << 21 | 0x22 << 7 | 6;
    const n = try encodeDt1(&out, .synth, address, &.{ 1, 2, 3 });
    const parsed = try parseDt1(out[0..n]);
    try std.testing.expectEqual(Kind.synth, parsed.kind);
    try std.testing.expectEqual(address, parsed.address);
    try std.testing.expectEqual(@as(u8, 3), parsed.len);
}

test "parseDt1 refuses a bad checksum, another maker and an RQ1" {
    var out: [32]u8 = undefined;
    const n = try encodeDt1(&out, .kb, 5, &.{1});
    out[n - 2] ^= 1;
    try std.testing.expectError(error.BadChecksum, parseDt1(out[0..n]));
    const other = [_]u8{ 0xF0, 0x43, 0x10, 0x62, 0x12, 0, 0, 0, 0xF7 };
    try std.testing.expectError(error.NotRoland, parseDt1(&other));
    const rq = try encodeRq1(&out, .kb, 0, 4);
    try std.testing.expectError(error.NotDt1, parseDt1(out[0..rq]));
}

test "identityMode tells Mode 2 from Mode 1" {
    const mode2 = [_]u8{ 0xF0, 0x7E, 0x10, 0x06, 0x02, 0x41, 0x62, 0x00, 0x00, 0x06, 0x00, 0x01, 0x00, 0x00, 0xF7 };
    const mode1 = [_]u8{ 0xF0, 0x7E, 0x10, 0x06, 0x02, 0x41, 0x42, 0x00, 0x00, 0x06, 0x00, 0x01, 0x00, 0x00, 0xF7 };
    try std.testing.expectEqual(MidiInMode.mode2, identityMode(&mode2).?);
    try std.testing.expectEqual(MidiInMode.mode1, identityMode(&mode1).?);
    try std.testing.expect(identityMode(&[_]u8{ 0xF0, 0x41, 0xF7 }) == null);
}

test "StreamParser drops realtime bytes inside a message" {
    var parser = StreamParser{};
    var out: [32]u8 = undefined;
    const n = try encodeDt1(&out, .kb, 9, &.{ 4, 5 });
    var got: ?[]const u8 = null;
    for (out[0..n], 0..) |b, i| {
        if (i == 4) _ = parser.feed(0xF8);
        if (parser.feed(b)) |m| got = m;
    }
    try std.testing.expect(got != null);
    try std.testing.expectEqualSlices(u8, out[0..n], got.?);
}
