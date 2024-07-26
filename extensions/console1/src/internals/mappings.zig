const std = @import("std");
const config = @import("config.zig");
const ModulesList = config.ModulesList;
const fs_helpers = @import("fs_helpers.zig");

// Trk only carries action buttons, so no need to map them
const Trk = enum {
    Tr_ext_sidechain,
    Tr_order,
    Tr_pg_dn,
    Tr_pg_up,
    Tr_tr1,
    Tr_tr10,
    Tr_tr11,
    Tr_tr12,
    Tr_tr13,
    Tr_tr14,
    Tr_tr15,
    Tr_tr16,
    Tr_tr17,
    Tr_tr18,
    Tr_tr19,
    Tr_tr2,
    Tr_tr20,
    Tr_tr3,
    Tr_tr4,
    Tr_tr5,
    Tr_tr6,
    Tr_tr7,
    Tr_tr8,
    Tr_tr9,
    Tr_tr_copy,
    Tr_tr_grp,
};

const Comp = enum(u8) {
    Comp_Attack = u8,
    Comp_DryWet = u8,
    Comp_Ratio = u8,
    Comp_Release = u8,
    Comp_Thresh = u8,
    Comp_comp = u8,
    // Comp_Mtr = u8,
};
const Eq = enum(u8) {
    Eq_HiFrq = u8,
    Eq_HiGain = u8,
    Eq_HiMidFrq = u8,
    Eq_HiMidGain = u8,
    Eq_HiMidQ = u8,
    Eq_LoFrq = u8,
    Eq_LoGain = u8,
    Eq_LoMidFrq = u8,
    Eq_LoMidGain = u8,
    Eq_LoMidQ = u8,
    Eq_eq = u8,
    Eq_hp_shape = u8,
    Eq_lp_shape = u8,
};
const Inpt = enum(u8) {
    // Inpt_MtrLft = u8,
    // Inpt_MtrRgt = u8,
    Inpt_Gain = u8,
    Inpt_HiCut = u8,
    Inpt_LoCut = u8,
    Inpt_disp_mode = u8,
    Inpt_disp_on = u8,
    Inpt_filt_to_comp = u8,
    Inpt_phase_inv = u8,
    Inpt_preset = u8,
};
const Outpt = enum(u8) {
    Out_Drive = u8,
    Out_DriveChar = u8,
    // Out_MtrLft = u8,
    // Out_MtrRgt = u8,
    Out_Pan = u8,
    Out_Vol = u8,
    // Out_mute = u8,
    // Out_solo = u8,
};

const Shp = enum(u8) {
    Shp_Gate = u8,
    Shp_GateRelease = u8,
    Shp_Punch = u8,
    Shp_hard_gate = u8,
    Shp_shape = u8,
    Shp_sustain = u8,
};

/// FxMap associates an Fx index with a module map
const FxMap = struct {
    Comp: std.meta.Tuple(&.{ u8, Comp }),
    Eq: std.meta.Tuple(&.{ u8, Eq }),
    Inpt: std.meta.Tuple(&.{ u8, Inpt }),
    Outpt: std.meta.Tuple(&.{ u8, Outpt }),
    Shp: std.meta.Tuple(&.{ u8, Shp }),
    Trk: std.meta.Tuple(&.{ u8, Trk }),
};

const MapStore = struct {
    Comp: std.StringHashMap(Comp),
    Eq: std.StringHashMap(Eq),
    Inpt: std.StringHashMap(Inpt),
    Outpt: std.StringHashMap(Outpt),
    Shp: std.StringHashMap(Shp),
    Trk: std.StringHashMap(Trk),
};

pub fn findMap(allocator: std.mem.Allocator, fxName: [:0]const u8, module: ModulesList, controller_dir: []const u8) void {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const subdir = @tagName(module);
    const elements = [_][]const u8{ controller_dir, subdir, fxName };
    var pos: usize = 0;
    for (elements, 0) |element, idx| {
        @memcpy(&buf[pos..], subdir);
        pos += element.len;
        if (idx != elements.len) { // not last in list
            @memcpy(&buf[pos..], std.fs.path.sep);
            pos += 1;
        }
    }
    const filePath = buf[0..pos];

    const contents = try fs_helpers.readFile(allocator, filePath);
    _ = contents; // autofix
}
