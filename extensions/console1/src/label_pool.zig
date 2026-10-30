const std = @import("std");
const CCs = @import("c1.zig").CCs;

const Self = @This();

pub const SLOT_SIZE = 32;
pub const ENTRY_SIZE = SLOT_SIZE * 2;
pub const COUNT = 41;

pub const empty: Self = .{};

buffer: [COUNT * ENTRY_SIZE]u8 = @splat(0),

pub fn indexOf(cc: CCs) ?u8 {
    return switch (cc) {
        .Comp_Attack => 0,
        .Comp_DryWet => 1,
        .Comp_HiCut => 2,
        .Comp_LoCut => 3,
        .Comp_Ratio => 4,
        .Comp_Release => 5,
        .Comp_Thresh => 6,
        .Comp_comp => 7,
        .Eq_HiFrq => 8,
        .Eq_HiGain => 9,
        .Eq_HiMidFrq => 10,
        .Eq_HiMidGain => 11,
        .Eq_HiMidQ => 12,
        .Eq_LoFrq => 13,
        .Eq_LoGain => 14,
        .Eq_LoMidFrq => 15,
        .Eq_LoMidGain => 16,
        .Eq_LoMidQ => 17,
        .Eq_eq => 18,
        .Eq_hp_shape => 19,
        .Eq_lp_shape => 20,
        .Inpt_Gain => 21,
        .Inpt_HiCut => 22,
        .Inpt_LoCut => 23,
        .Inpt_disp_mode => 24,
        .Inpt_disp_on => 25,
        .Inpt_filt_to_comp => 26,
        .Inpt_phase_inv => 27,
        .Inpt_preset => 28,
        .Out_Drive => 29,
        .Out_DriveChar => 30,
        .Out_Pan => 31,
        .Out_Vol => 32,
        .Shp_Gate => 33,
        .Shp_GateRelease => 34,
        .Shp_Punch => 35,
        .Shp_hard_gate => 36,
        .Shp_shape => 37,
        .Shp_sustain => 38,
        .Tr_order => 39,
        .Tr_ext_sidechain => 40,
        else => null,
    };
}

pub fn getPrmLabel(self: *const Self, cc: CCs) [:0]const u8 {
    const idx = indexOf(cc) orelse return "";
    const start = @as(usize, idx) * ENTRY_SIZE;
    return std.mem.span(@as([*:0]const u8, @ptrCast(&self.buffer[start])));
}

pub fn getFmtValue(self: *const Self, cc: CCs) [:0]const u8 {
    const idx = indexOf(cc) orelse return "";
    const start = @as(usize, idx) * ENTRY_SIZE + SLOT_SIZE;
    return std.mem.span(@as([*:0]const u8, @ptrCast(&self.buffer[start])));
}

pub fn setPrmLabel(self: *Self, cc: CCs, label: []const u8) void {
    const idx = indexOf(cc) orelse return;
    const start = @as(usize, idx) * ENTRY_SIZE;
    const dest = self.buffer[start..][0..SLOT_SIZE];
    @memset(dest, 0);
    const len = @min(label.len, SLOT_SIZE - 1);
    @memcpy(dest[0..len], label[0..len]);
}

pub fn setFmtValue(self: *Self, cc: CCs, value: []const u8) void {
    const idx = indexOf(cc) orelse return;
    const start = @as(usize, idx) * ENTRY_SIZE + SLOT_SIZE;
    const dest = self.buffer[start..][0..SLOT_SIZE];
    @memset(dest, 0);
    const len = @min(value.len, SLOT_SIZE - 1);
    @memcpy(dest[0..len], value[0..len]);
}

pub fn fillDefaults(self: *Self, cc: ?CCs) void {
    if (cc) |c| {
        self.setPrmLabel(c, "-");
        self.setFmtValue(c, "-");
    } else {
        inline for (comptime std.enums.values(CCs)) |c| {
            if (indexOf(c) != null) {
                self.setPrmLabel(c, "-");
                self.setFmtValue(c, "-");
            }
        }
    }
}

test "indexOf returns sequential indices for assignable CCs" {
    const testing = std.testing;
    try testing.expectEqual(@as(?u8, 0), indexOf(.Comp_Attack));
    try testing.expectEqual(@as(?u8, 7), indexOf(.Comp_comp));
    try testing.expectEqual(@as(?u8, 39), indexOf(.Tr_order));
    try testing.expectEqual(@as(?u8, null), indexOf(.Tr_tr1));
    try testing.expectEqual(@as(?u8, null), indexOf(.Out_mute));
    try testing.expectEqual(@as(?u8, null), indexOf(.Out_solo));
}

test "setPrmLabel and getPrmLabel round-trip" {
    const testing = std.testing;
    var pool = Self{};
    pool.setPrmLabel(.Comp_Attack, "Attack (ms)");
    try testing.expectEqualStrings("Attack (ms)", pool.getPrmLabel(.Comp_Attack));
}

test "setFmtValue and getFmtValue round-trip" {
    const testing = std.testing;
    var pool = Self{};
    pool.setFmtValue(.Eq_HiGain, "12.5 dB");
    try testing.expectEqualStrings("12.5 dB", pool.getFmtValue(.Eq_HiGain));
}

test "strings longer than 31 bytes are truncated" {
    const testing = std.testing;
    var pool = Self{};
    const long = "This is a very long parameter name that exceeds the slot";
    pool.setPrmLabel(.Comp_Thresh, long);
    const result = pool.getPrmLabel(.Comp_Thresh);
    try testing.expect(result.len == SLOT_SIZE - 1);
    try testing.expect(result[SLOT_SIZE - 2] != 0);
}

test "fillDefaults with null fills all assignable CCs" {
    const testing = std.testing;
    var pool = Self{};
    pool.fillDefaults(null);
    try testing.expectEqualStrings("-", pool.getPrmLabel(.Comp_Attack));
    try testing.expectEqualStrings("-", pool.getFmtValue(.Comp_Attack));
    try testing.expectEqualStrings("-", pool.getPrmLabel(.Tr_order));
    try testing.expectEqualStrings("-", pool.getFmtValue(.Tr_order));
}

test "fillDefaults with specific CC fills only that CC" {
    const testing = std.testing;
    var pool = Self{};
    pool.setPrmLabel(.Comp_Attack, "custom");
    pool.setPrmLabel(.Comp_Ratio, "also custom");
    pool.fillDefaults(.Comp_Attack);
    try testing.expectEqualStrings("-", pool.getPrmLabel(.Comp_Attack));
    try testing.expectEqualStrings("-", pool.getFmtValue(.Comp_Attack));
    try testing.expectEqualStrings("also custom", pool.getPrmLabel(.Comp_Ratio));
}

test "non-assignable CC returns empty string" {
    const testing = std.testing;
    var pool = Self{};
    pool.fillDefaults(null);
    try testing.expectEqualStrings("", pool.getPrmLabel(.Tr_tr1));
    try testing.expectEqualStrings("", pool.getFmtValue(.Tr_tr1));
}
