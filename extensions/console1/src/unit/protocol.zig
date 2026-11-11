//! The bytes of the Console 1 sysex protocol, as recorded in `tools/sniff-usb/PROTOCOL.md`: the handshake, the
//! parser of what the unit sends, and the state frame builder with its checksum.
const std = @import("std");

pub const payload_length = 97;
const header_length = 8;
/// A whole state frame: F0, 7D, the kind, three zeros, the length, a zero, the payload, five checksum bytes and F7.
pub const state_frame_length = header_length + payload_length + 5 + 1;
const checksum_start = header_length + payload_length;

pub const Kind = struct {
    pub const control: u8 = 0x00;
    pub const state: u8 = 0x01;
    pub const challenge: u8 = 0x02;
    pub const challenge_answer: u8 = 0x03;
    pub const version_request: u8 = 0x05;
    pub const version_answer: u8 = 0x06;
    pub const hello: u8 = 0x20;
    pub const hello_answer: u8 = 0x21;
    pub const ack: u8 = 0x24;
};

/// Control id of shift. It is not a c1.CCs member, because the legacy unit never reported it.
pub const shift_id: u8 = 0x02;

/// Byte of the payload that has the global switch of the LEDs, and the one that the application never changes.
pub const switch_byte = 95;
pub const unknown_byte = 96;
pub const switch_value: u8 = 0x20;
pub const unknown_value: u8 = 0x03;

pub const hello_frame = [_]u8{ 0xF0, 0x7D, 0x20, 0x00, 0x00, 0x00, 0x01, 0x00, 0x7F, 0x49, 0x6F, 0x6C, 0x73, 0x00, 0xF7 };

pub const challenge_frame = [_]u8{
    0xF0, 0x7D, 0x02, 0x00, 0x00, 0x00, 0x4A, 0x00, 0x00, 0x21, 0x41, 0x75, 0x08, 0x38, 0x0C, 0x14,
    0x2D, 0x2D, 0x6F, 0x62, 0x04, 0x54, 0x08, 0x76, 0x0D, 0x07, 0x2B, 0x01, 0x62, 0x11, 0x6A, 0x30,
    0x2F, 0x16, 0x6E, 0x58, 0x06, 0x17, 0x27, 0x7D, 0x6A, 0x33, 0x69, 0x43, 0x43, 0x0C, 0x3C, 0x39,
    0x54, 0x21, 0x41, 0x7D, 0x5D, 0x3F, 0x7B, 0x39, 0x39, 0x40, 0x26, 0x12, 0x21, 0x62, 0x45, 0x76,
    0x6F, 0x44, 0x7A, 0x3C, 0x46, 0x5B, 0x2A, 0x20, 0x7C, 0x65, 0x68, 0x0F, 0x67, 0x01, 0x04, 0x37,
    0x51, 0x00, 0x77, 0x36, 0x40, 0x0D, 0x02, 0xF7,
};

pub const version_request_frame = [_]u8{ 0xF0, 0x7D, 0x05, 0x00, 0x00, 0x00, 0x01, 0x00, 0x7F, 0x54, 0x6A, 0x7A, 0x48, 0x0C, 0xF7 };

/// The state frame that closes the handshake, as the application sent it: every control dark, counter 1.
pub const handshake_state_frame = [_]u8{
    0xF0, 0x7D, 0x01, 0x00, 0x00, 0x00, 0x61, 0x00, 0x01, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x60, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x03, 0x56, 0x78, 0x2A, 0x6C, 0x0C, 0xF7,
};

/// A frame of the application with its checksum, which the checksum model is relative to.
const base_frame = [_]u8{
    0xF0, 0x7D, 0x01, 0x00, 0x00, 0x00, 0x61, 0x00, 0x26, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x7F, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x3F, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F, 0x3F, 0x3F,
    0x00, 0x3F, 0x3F, 0x3F, 0x3F, 0x00, 0x3F, 0x3F, 0x00, 0x3F, 0x3F, 0x3F, 0x3F, 0x7F, 0x69, 0x7F,
    0x7F, 0x3F, 0x7F, 0x3F, 0x00, 0x00, 0x3F, 0x3F, 0x00, 0x00, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x3F,
    0x65, 0x62, 0x00, 0x00, 0x01, 0x7A, 0x04, 0x00, 0x0F, 0x7F, 0x7F, 0x20, 0x62, 0x00, 0x00, 0x00,
    0x02, 0x04, 0x00, 0x0F, 0x78, 0x0F, 0x20, 0x20, 0x03, 0x1E, 0x12, 0x11, 0x0C, 0x08, 0xF7,
};

/// The 32x32 matrix over GF(2) as 32 rows: bit r of (step_rows times v) is the parity of (step_rows[r] and v).
const step_rows = [32]u32{
    0xC0000000, 0x80000001, 0x00000002, 0x80000004, 0x80000008, 0x00000010, 0x80000020, 0xA0000000,
    0x00000080, 0x00000100, 0x00000200, 0x80000400, 0x80000800, 0x80001000, 0x10000000, 0x80004000,
    0x80008000, 0x00010000, 0x00020000, 0x00040000, 0x00080000, 0x80000000, 0x00200000, 0x00400000,
    0x00800000, 0x01000000, 0x02000000, 0x84000000, 0x08000000, 0x00100000, 0x00002000, 0x80000040,
};
const effect_of_first_bit: u32 = 0x62295AF5;

fn applyStep(vector: u32) u32 {
    var result: u32 = 0;
    for (step_rows, 0..) |mask, row| {
        result |= @as(u32, @popCount(mask & vector) & 1) << @intCast(row);
    }
    return result;
}

/// effects[position][bit] is what the checksum changes by when that bit of the payload flips.
const effects: [payload_length][7]u32 = blk: {
    @setEvalBranchQuota(1_000_000);
    var table: [payload_length][7]u32 = undefined;
    var vector = effect_of_first_bit;
    for (0..8 * payload_length) |step| {
        const position = step / 8;
        const bit = step % 8;
        if (bit < 7) table[position][bit] = vector;
        vector = applyStep(vector);
    }
    break :blk table;
};

fn checksumOf(frame: []const u8) u32 {
    var sum: u32 = 0;
    for (0..5) |i| sum |= @as(u32, frame[checksum_start + i]) << @intCast(7 * i);
    return sum;
}

/// The whole state frame (kind 01) for a payload, with a valid checksum. Every byte of the payload has 7 bits.
pub fn buildStateFrame(payload: *const [payload_length]u8) [state_frame_length]u8 {
    var frame = base_frame;
    var checksum = checksumOf(&base_frame);
    for (payload, 0..) |value, position| {
        std.debug.assert(value < 0x80);
        const difference = base_frame[header_length + position] ^ value;
        for (0..7) |bit| {
            if ((difference >> @intCast(bit)) & 1 != 0) checksum ^= effects[position][bit];
        }
        frame[header_length + position] = value;
    }
    for (0..5) |i| frame[checksum_start + i] = @intCast((checksum >> @intCast(7 * i)) & 0x7F);
    return frame;
}

pub const Message = struct {
    kind: u8,
    payload: []const u8,
};

/// Reads a sysex of the unit. The F0 and the F7 are optional, because it is not known whether REAPER delivers them.
/// A message that is not of this protocol, or that is cut short, is null.
pub fn parse(bytes: []const u8) ?Message {
    var data = bytes;
    if (data.len > 0 and data[0] == 0xF0) data = data[1..];
    if (data.len > 0 and data[data.len - 1] == 0xF7) data = data[0 .. data.len - 1];
    // 7D, the kind, three zeros, the length and a zero.
    if (data.len < 7 or data[0] != 0x7D) return null;
    const length = data[5];
    if (data.len < 7 + length) return null;
    return .{ .kind = data[1], .payload = data[7 .. 7 + length] };
}

pub const ControlMessage = struct { id: u8, value: u8 };

pub fn parseControl(message: Message) ?ControlMessage {
    if (message.kind != Kind.control or message.payload.len != 2) return null;
    return .{ .id = message.payload[0], .value = message.payload[1] };
}

fn payloadOf(frame: []const u8) [payload_length]u8 {
    return frame[header_length..][0..payload_length].*;
}

test "the checksum model rebuilds the frames of the application byte for byte" {
    try std.testing.expectEqualSlices(u8, &base_frame, &buildStateFrame(&payloadOf(&base_frame)));
    try std.testing.expectEqualSlices(u8, &handshake_state_frame, &buildStateFrame(&payloadOf(&handshake_state_frame)));
}

test "a frame has the markers of the protocol and 7-bit bytes whatever the payload" {
    const frame = buildStateFrame(&@as([payload_length]u8, @splat(0x7F)));
    try std.testing.expectEqual(@as(u8, 0xF0), frame[0]);
    try std.testing.expectEqual(@as(u8, 0xF7), frame[frame.len - 1]);
    try std.testing.expectEqual(@as(usize, 111), frame.len);
    for (frame[1 .. frame.len - 1]) |byte| try std.testing.expect(byte < 0x80);
}

test "the checksum depends on the counter" {
    var payload = payloadOf(&base_frame);
    payload[0] = 1;
    const one = buildStateFrame(&payload);
    payload[0] = 2;
    const two = buildStateFrame(&payload);
    try std.testing.expect(!std.mem.eql(u8, one[checksum_start..][0..5], two[checksum_start..][0..5]));
}

test "parse reads a control event with and without its F0 and F7" {
    const with_markers = [_]u8{ 0xF0, 0x7D, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x1B, 0x7F, 0x12, 0x34, 0x56, 0x78, 0x09, 0xF7 };
    const parsed = parse(&with_markers).?;
    try std.testing.expectEqual(Kind.control, parsed.kind);
    const control = parseControl(parsed).?;
    try std.testing.expectEqual(@as(u8, 0x1B), control.id);
    try std.testing.expectEqual(@as(u8, 0x7F), control.value);
    const without = parse(with_markers[1 .. with_markers.len - 1]).?;
    try std.testing.expectEqual(Kind.control, without.kind);
}

test "parse refuses what is not of the protocol or is cut short" {
    try std.testing.expectEqual(@as(?Message, null), parse(&.{ 0xF0, 0x41, 0x00, 0xF7 }));
    try std.testing.expectEqual(@as(?Message, null), parse(&.{ 0xF0, 0x7D, 0x00, 0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0xF7 }));
    try std.testing.expectEqual(@as(?Message, null), parse(&.{}));
}

test "parse reads the acknowledgement and the version" {
    const ack = parse(&.{ 0xF0, 0x7D, 0x24, 0x00, 0x00, 0x00, 0x01, 0x00, 0x05, 0x01, 0x02, 0x03, 0x04, 0x05, 0xF7 }).?;
    try std.testing.expectEqual(Kind.ack, ack.kind);
    try std.testing.expectEqual(@as(u8, 5), ack.payload[0]);
}
