//! The control ids of the unit in sysex mode, as the table of `tools/sniff-usb/PROTOCOL.md` has them, and the c1.CCs
//! that the rest of the extension knows the controls by.
const std = @import("std");
const c1 = @import("../c1.zig");

const Entry = struct { id: u8, cc: c1.CCs };

const table = [_]Entry{
    .{ .id = 0x00, .cc = .Inpt_disp_on },
    .{ .id = 0x01, .cc = .Inpt_disp_mode },
    .{ .id = 0x03, .cc = .Tr_pg_dn },
    .{ .id = 0x04, .cc = .Tr_pg_up },
    .{ .id = 0x05, .cc = .Tr_tr1 },
    .{ .id = 0x06, .cc = .Tr_tr2 },
    .{ .id = 0x07, .cc = .Tr_tr3 },
    .{ .id = 0x08, .cc = .Tr_tr4 },
    .{ .id = 0x09, .cc = .Tr_tr5 },
    .{ .id = 0x0A, .cc = .Tr_tr6 },
    .{ .id = 0x0B, .cc = .Tr_tr7 },
    .{ .id = 0x0C, .cc = .Tr_tr8 },
    .{ .id = 0x0D, .cc = .Tr_tr9 },
    .{ .id = 0x0E, .cc = .Tr_tr10 },
    .{ .id = 0x0F, .cc = .Tr_tr11 },
    .{ .id = 0x10, .cc = .Tr_tr12 },
    .{ .id = 0x11, .cc = .Tr_tr13 },
    .{ .id = 0x12, .cc = .Tr_tr14 },
    .{ .id = 0x13, .cc = .Tr_tr15 },
    .{ .id = 0x14, .cc = .Tr_tr16 },
    .{ .id = 0x15, .cc = .Tr_tr17 },
    .{ .id = 0x16, .cc = .Tr_tr18 },
    .{ .id = 0x17, .cc = .Tr_tr19 },
    .{ .id = 0x18, .cc = .Tr_tr20 },
    .{ .id = 0x19, .cc = .Tr_tr_copy },
    .{ .id = 0x1A, .cc = .Tr_tr_grp },
    .{ .id = 0x1B, .cc = .Inpt_Gain },
    .{ .id = 0x1C, .cc = .Inpt_HiCut },
    .{ .id = 0x1D, .cc = .Inpt_LoCut },
    .{ .id = 0x1E, .cc = .Inpt_filt_to_comp },
    .{ .id = 0x1F, .cc = .Inpt_phase_inv },
    .{ .id = 0x20, .cc = .Inpt_preset },
    .{ .id = 0x21, .cc = .Shp_shape },
    .{ .id = 0x22, .cc = .Shp_Gate },
    .{ .id = 0x23, .cc = .Shp_hard_gate },
    .{ .id = 0x24, .cc = .Shp_GateRelease },
    .{ .id = 0x25, .cc = .Shp_sustain },
    .{ .id = 0x26, .cc = .Shp_Punch },
    .{ .id = 0x27, .cc = .Eq_eq },
    .{ .id = 0x28, .cc = .Eq_lp_shape },
    .{ .id = 0x29, .cc = .Eq_LoFrq },
    .{ .id = 0x2A, .cc = .Eq_LoGain },
    .{ .id = 0x2B, .cc = .Eq_LoMidFrq },
    .{ .id = 0x2C, .cc = .Eq_LoMidQ },
    .{ .id = 0x2D, .cc = .Eq_LoMidGain },
    .{ .id = 0x2E, .cc = .Eq_HiMidFrq },
    .{ .id = 0x2F, .cc = .Eq_HiMidQ },
    .{ .id = 0x30, .cc = .Eq_HiMidGain },
    .{ .id = 0x31, .cc = .Eq_hp_shape },
    .{ .id = 0x32, .cc = .Eq_HiFrq },
    .{ .id = 0x33, .cc = .Eq_HiGain },
    .{ .id = 0x34, .cc = .Comp_comp },
    .{ .id = 0x35, .cc = .Comp_Ratio },
    .{ .id = 0x36, .cc = .Comp_DryWet },
    .{ .id = 0x37, .cc = .Comp_Attack },
    .{ .id = 0x38, .cc = .Comp_Release },
    .{ .id = 0x39, .cc = .Comp_Thresh },
    .{ .id = 0x3A, .cc = .Tr_order },
    .{ .id = 0x3B, .cc = .Tr_ext_sidechain },
    .{ .id = 0x3C, .cc = .Out_Drive },
    .{ .id = 0x3D, .cc = .Out_DriveChar },
    .{ .id = 0x3E, .cc = .Out_Pan },
    .{ .id = 0x3F, .cc = .Out_solo },
    .{ .id = 0x40, .cc = .Out_mute },
    .{ .id = 0x41, .cc = .Out_Vol },
    .{ .id = 0x42, .cc = .Inpt_MtrLft },
    .{ .id = 0x43, .cc = .Inpt_MtrRgt },
    .{ .id = 0x44, .cc = .Out_MtrLft },
    .{ .id = 0x45, .cc = .Out_MtrRgt },
    .{ .id = 0x46, .cc = .Shp_Mtr },
    .{ .id = 0x47, .cc = .Comp_Mtr },
};

/// One past the highest id, which is the number of ids that the bit flags of a state frame have room for.
pub const id_count = 0x48;

const no_id: u8 = 0xFF;

// Because c1.CCs has sparse values, the table is indexed by the backing byte of the control.
const cc_to_id: [256]u8 = blk: {
    var array: [256]u8 = @splat(no_id);
    for (table) |entry| array[@backingInt(entry.cc)] = entry.id;
    break :blk array;
};

const id_to_cc: [id_count]?c1.CCs = blk: {
    var array: [id_count]?c1.CCs = @splat(null);
    for (table) |entry| array[entry.id] = entry.cc;
    break :blk array;
};

pub fn ccOf(id: u8) ?c1.CCs {
    if (id >= id_count) return null;
    return id_to_cc[id];
}

/// Null for the two virtual controls, Comp_HiCut and Comp_LoCut.
pub fn idOf(cc: c1.CCs) ?u8 {
    const id = cc_to_id[@backingInt(cc)];
    return if (id == no_id) null else id;
}

pub fn isMeter(cc: c1.CCs) bool {
    return switch (cc) {
        .Inpt_MtrLft, .Inpt_MtrRgt, .Out_MtrLft, .Out_MtrRgt, .Shp_Mtr, .Comp_Mtr => true,
        else => false,
    };
}

/// A control that reports ticks: it is neither a button nor a meter.
pub fn isKnob(cc: c1.CCs) bool {
    return !cc.isBtn() and !isMeter(cc);
}

test "every control of the unit has one id, and the virtual ones have none" {
    var seen: [id_count]bool = @splat(false);
    for (std.enums.values(c1.CCs)) |cc| {
        switch (cc) {
            .Comp_HiCut, .Comp_LoCut => try std.testing.expectEqual(@as(?u8, null), idOf(cc)),
            else => {
                const id = idOf(cc) orelse return error.ControlWithoutId;
                try std.testing.expect(!seen[id]);
                seen[id] = true;
                try std.testing.expectEqual(@as(?c1.CCs, cc), ccOf(id));
            },
        }
    }
}

test "the ids of the table are unique and shift has none" {
    var seen: [id_count]bool = @splat(false);
    for (table) |entry| {
        try std.testing.expect(!seen[entry.id]);
        seen[entry.id] = true;
    }
    try std.testing.expectEqual(@as(?c1.CCs, null), ccOf(0x02));
    try std.testing.expectEqual(@as(usize, 71), table.len);
}

test "knobs, buttons and meters are three distinct sets" {
    try std.testing.expect(isKnob(.Inpt_Gain));
    try std.testing.expect(isKnob(.Out_Vol));
    try std.testing.expect(!isKnob(.Out_mute));
    try std.testing.expect(!isKnob(.Comp_Mtr));
    try std.testing.expect(isMeter(.Comp_Mtr));
}
