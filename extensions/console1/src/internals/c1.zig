const std = @import("std");

const actions = struct {
    pub fn selectTrackOnPage(trackNumber: u8) void {
        _ = trackNumber;
    }
    pub fn cycleControllerMode() void {} // go to next controller mode
    pub fn cycleFxReorder() void {}
    pub fn cycleGateMode() void {}
    pub fn cycleHPShape() void {}
    pub fn cycleLPShape() void {}
    pub fn focus_next_page() void {}
    pub fn focus_prev_page() void {}
    pub fn toggleCmp() void {}
    pub fn toggleDisplay() void {}
    pub fn toggleEQ() void {}
    pub fn toggleShape() void {}
    pub fn toggleSelectedTrackPhase() void {}
    pub fn toggleShift() void {}
    pub fn trackMute() void {}
    pub fn trackSolo() void {}
    pub fn prefs_showStartUpMessage() void {}
    pub fn prefs_showFeedbackWindow() void {}
    pub fn prefs_showPluginUi() void {}
    pub fn prefs_save() void {}
    pub fn sel_dispEqOpts() void {}
    pub fn sel_dispShpOpts() void {}
    pub fn sel_dispCmpOpts() void {}
    pub fn sel_dispGateOpts() void {}
    pub fn sel_slot(slotId: u8) void {
        _ = slotId;
    }
};

pub const Mode = enum {
    fx_ctrl,
    fx_sel,
};

pub const ActionId = enum {
    disp_on,
    disp_mode,
    shift,
    filt_to_comp,
    phase_inv,
    preset,
    pg_up,
    pg_dn,
    tr1,
    tr2,
    tr3,
    tr4,
    tr5,
    tr6,
    tr7,
    tr8,
    tr9,
    tr10,
    tr11,
    tr12,
    tr13,
    tr14,
    tr15,
    tr16,
    tr17,
    tr18,
    tr19,
    tr20,
    shape,
    hard_gate,
    eq,
    hp_shape,
    lp_shape,
    comp,
    tr_grp,
    tr_copy,
    order,
    ext_sidechain,
    solo,
    mute,
};

pub const Btns = std.EnumArray(ActionId, ?*const fn () void);

pub const controller = std.EnumArray(Mode, Btns).init(.{
    .fx_ctrl = Btns.init(.{
        .disp_on = actions.toggleDisplay,
        .disp_mode = actions.cycleControllerMode,
        .shift = actions.toggleShift,
        .filt_to_comp = null,
        .phase_inv = actions.toggleSelectedTrackPhase,
        .preset = null,
        .pg_up = null,
        .pg_dn = null,
        .tr1 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(1);
            }
        }.action,
        .tr2 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(2);
            }
        }.action,
        .tr3 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(3);
            }
        }.action,
        .tr4 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(4);
            }
        }.action,
        .tr5 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(5);
            }
        }.action,
        .tr6 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(6);
            }
        }.action,
        .tr7 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(7);
            }
        }.action,
        .tr8 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(8);
            }
        }.action,
        .tr9 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(9);
            }
        }.action,
        .tr10 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(10);
            }
        }.action,
        .tr11 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(11);
            }
        }.action,
        .tr12 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(12);
            }
        }.action,
        .tr13 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(13);
            }
        }.action,
        .tr14 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(14);
            }
        }.action,
        .tr15 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(15);
            }
        }.action,
        .tr16 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(16);
            }
        }.action,
        .tr17 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(17);
            }
        }.action,
        .tr18 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(18);
            }
        }.action,
        .tr19 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(19);
            }
        }.action,
        .tr20 = struct {
            pub fn action() void {
                return actions.selectTrackOnPage(20);
            }
        }.action,
        .shape = actions.toggleShape,
        .hard_gate = actions.cycleGateMode,
        .eq = actions.toggleEQ,
        .hp_shape = actions.cycleHPShape,
        .lp_shape = actions.cycleLPShape,
        .comp = actions.toggleCmp,
        .tr_grp = null,
        .tr_copy = null,
        .order = actions.cycleFxReorder,
        .ext_sidechain = null,
        .solo = actions.trackSolo,
        .mute = actions.trackMute,
    }),
    .fx_sel = Btns.init(.{
        .disp_on = null,
        .disp_mode = actions.cycleControllerMode,
        .shift = null,
        .filt_to_comp = null,
        .phase_inv = null,
        .preset = null,
        .pg_up = null,
        .pg_dn = null,
        .tr1 = struct {
            pub fn action() void {
                actions.sel_slot(1);
            }
        }.action,
        .tr2 = struct {
            pub fn action() void {
                actions.sel_slot(2);
            }
        }.action,
        .tr3 = struct {
            pub fn action() void {
                actions.sel_slot(3);
            }
        }.action,
        .tr4 = struct {
            pub fn action() void {
                actions.sel_slot(4);
            }
        }.action,
        .tr5 = struct {
            pub fn action() void {
                actions.sel_slot(5);
            }
        }.action,
        .tr6 = struct {
            pub fn action() void {
                actions.sel_slot(6);
            }
        }.action,
        .tr7 = struct {
            pub fn action() void {
                actions.sel_slot(7);
            }
        }.action,
        .tr8 = struct {
            pub fn action() void {
                actions.sel_slot(8);
            }
        }.action,
        .tr9 = struct {
            pub fn action() void {
                actions.sel_slot(9);
            }
        }.action,
        .tr10 = struct {
            pub fn action() void {
                actions.sel_slot(10);
            }
        }.action,
        .tr11 = struct {
            pub fn action() void {
                actions.sel_slot(11);
            }
        }.action,
        .tr12 = struct {
            pub fn action() void {
                actions.sel_slot(12);
            }
        }.action,
        .tr13 = struct {
            pub fn action() void {
                actions.sel_slot(13);
            }
        }.action,
        .tr14 = struct {
            pub fn action() void {
                actions.sel_slot(14);
            }
        }.action,
        .tr15 = struct {
            pub fn action() void {
                actions.sel_slot(15);
            }
        }.action,
        .tr16 = struct {
            pub fn action() void {
                actions.sel_slot(16);
            }
        }.action,
        .tr17 = struct {
            pub fn action() void {
                actions.sel_slot(17);
            }
        }.action,
        .tr18 = struct {
            pub fn action() void {
                actions.sel_slot(18);
            }
        }.action,
        .tr19 = struct {
            pub fn action() void {
                actions.sel_slot(19);
            }
        }.action,
        .tr20 = struct {
            pub fn action() void {
                actions.sel_slot(20);
            }
        }.action,
        .shape = actions.sel_dispShpOpts,
        .hard_gate = null,
        .eq = actions.sel_dispEqOpts,
        .hp_shape = null,
        .lp_shape = null,
        .comp = actions.sel_dispCmpOpts,
        .tr_grp = null,
        .tr_copy = null,
        .order = null,
        .ext_sidechain = null,
        .solo = null,
        .mute = null,
    }),
});
pub const CCs = enum(u8) {
    Comp_Attack = 0x33,
    Comp_DryWet = 0x32,
    Comp_Ratio = 0x31,
    Comp_Release = 0x30,
    Comp_Thresh = 0x2f,
    Comp_comp = 0x2e,
    Eq_HiFrq = 0x53,
    Eq_HiGain = 0x52,
    Eq_HiMidFrq = 0x56,
    Eq_HiMidGain = 0x55,
    Eq_HiMidQ = 0x57,
    Eq_LoFrq = 0x5c,
    Eq_LoGain = 0x5b,
    Eq_LoMidFrq = 0x59,
    Eq_LoMidGain = 0x58,
    Eq_LoMidQ = 0x5a,
    Eq_eq = 0x50,
    Eq_hp_shape = 0x5d,
    Eq_lp_shape = 0x41,
    Inpt_Gain = 0x6b,
    Inpt_HiCut = 0x69,
    Inpt_LoCut = 0x67,
    Inpt_disp_mode = 0x68,
    Inpt_disp_on = 0x66,
    Inpt_filt_to_comp = 0x3d,
    Inpt_phase_inv = 0x6c,
    Inpt_preset = 0x3a,
    Inpt_MtrLft = 0x6e,
    Inpt_MtrRgt = 0x6f,
    // Inpt_shift = 0x0,
    Out_MtrLft = 0x70,
    Out_MtrRgt = 0x71,
    Shp_Mtr = 0x72,
    Comp_Mtr = 0x73,
    Out_Drive = 0xf,
    Out_DriveChar = 0x12,
    Out_Pan = 0xa,
    Out_Vol = 0x7,
    Out_mute = 0xc,
    Out_solo = 0xd,
    Shp_Gate = 0x36,
    Shp_GateRelease = 0x38,
    Shp_Punch = 0x39,
    Shp_hard_gate = 0x3b,
    Shp_shape = 0x35,
    Shp_sustain = 0x37,
    Tr_ext_sidechain = 0x11,
    Tr_order = 0xe,
    Tr_pg_dn = 0x61,
    Tr_pg_up = 0x60,
    Tr_tr1 = 0x15,
    Tr_tr10 = 0x1e,
    Tr_tr11 = 0x1f,
    Tr_tr12 = 0x20,
    Tr_tr13 = 0x21,
    Tr_tr14 = 0x22,
    Tr_tr15 = 0x23,
    Tr_tr16 = 0x24,
    Tr_tr17 = 0x25,
    Tr_tr18 = 0x26,
    Tr_tr19 = 0x27,
    Tr_tr2 = 0x16,
    Tr_tr20 = 0x28,
    Tr_tr3 = 0x17,
    Tr_tr4 = 0x18,
    Tr_tr5 = 0x19,
    Tr_tr6 = 0x1a,
    Tr_tr7 = 0x1b,
    Tr_tr8 = 0x1c,
    Tr_tr9 = 0x1d,
    Tr_tr_copy = 0x7b,
    Tr_tr_grp = 0x78,
    pub fn getLabel(self: CCs) [:0]const u8 {
        return switch (self) {
            .Comp_Attack => "Attack",
            .Comp_Release => "Release",
            .Comp_DryWet => "unlbld",
            .Comp_Ratio => "unlbld",
            .Comp_Thresh => "unlbld",
            .Comp_comp => "unlbld",
            .Eq_HiFrq => "unlbld",
            .Eq_HiGain => "unlbld",
            .Eq_HiMidFrq => "unlbld",
            .Eq_HiMidGain => "unlbld",
            .Eq_HiMidQ => "unlbld",
            .Eq_LoFrq => "unlbld",
            .Eq_LoGain => "unlbld",
            .Eq_LoMidFrq => "unlbld",
            .Eq_LoMidGain => "unlbld",
            .Eq_LoMidQ => "unlbld",
            .Eq_eq => "unlbld",
            .Eq_hp_shape => "unlbld",
            .Eq_lp_shape => "unlbld",
            .Inpt_Gain => "unlbld",
            .Inpt_HiCut => "unlbld",
            .Inpt_LoCut => "unlbld",
            .Inpt_disp_mode => "unlbld",
            .Inpt_disp_on => "unlbld",
            .Inpt_filt_to_comp => "unlbld",
            .Inpt_phase_inv => "unlbld",
            .Inpt_preset => "unlbld",
            .Inpt_MtrLft => "unlbld",
            .Inpt_MtrRgt => "unlbld",
            .Out_MtrLft => "unlbld",
            .Out_MtrRgt => "unlbld",
            .Shp_Mtr => "unlbld",
            .Comp_Mtr => "unlbld",
            .Out_Drive => "unlbld",
            .Out_DriveChar => "unlbld",
            .Out_Pan => "unlbld",
            .Out_Vol => "unlbld",
            .Out_mute => "unlbld",
            .Out_solo => "unlbld",
            .Shp_Gate => "unlbld",
            .Shp_GateRelease => "unlbld",
            .Shp_Punch => "unlbld",
            .Shp_hard_gate => "unlbld",
            .Shp_shape => "unlbld",
            .Shp_sustain => "unlbld",
            .Tr_ext_sidechain => "unlbld",
            .Tr_order => "unlbld",
            .Tr_pg_dn => "unlbld",
            .Tr_pg_up => "unlbld",
            .Tr_tr1 => "unlbld",
            .Tr_tr10 => "unlbld",
            .Tr_tr11 => "unlbld",
            .Tr_tr12 => "unlbld",
            .Tr_tr13 => "unlbld",
            .Tr_tr14 => "unlbld",
            .Tr_tr15 => "unlbld",
            .Tr_tr16 => "unlbld",
            .Tr_tr17 => "unlbld",
            .Tr_tr18 => "unlbld",
            .Tr_tr19 => "unlbld",
            .Tr_tr2 => "unlbld",
            .Tr_tr20 => "unlbld",
            .Tr_tr3 => "unlbld",
            .Tr_tr4 => "unlbld",
            .Tr_tr5 => "unlbld",
            .Tr_tr6 => "unlbld",
            .Tr_tr7 => "unlbld",
            .Tr_tr8 => "unlbld",
            .Tr_tr9 => "unlbld",
            .Tr_tr_copy => "unlbld",
            .Tr_tr_grp => "unlbld",
        };
    }
};

pub const Tracks = enum(u8) {
    Tr_tr1 = 0x15,
    Tr_tr2 = 0x16,
    Tr_tr3 = 0x17,
    Tr_tr4 = 0x18,
    Tr_tr5 = 0x19,
    Tr_tr6 = 0x1a,
    Tr_tr7 = 0x1b,
    Tr_tr8 = 0x1c,
    Tr_tr9 = 0x1d,
    Tr_tr10 = 0x1e,
    Tr_tr11 = 0x1f,
    Tr_tr12 = 0x20,
    Tr_tr13 = 0x21,
    Tr_tr14 = 0x22,
    Tr_tr15 = 0x23,
    Tr_tr16 = 0x24,
    Tr_tr17 = 0x25,
    Tr_tr18 = 0x26,
    Tr_tr19 = 0x27,
    Tr_tr20 = 0x28,
};

const Knobs = enum {
    Inpt_Gain,
    Inpt_HiCut,
    Inpt_LoCut,
    Shp_Gate,
    Shp_GateRelease,
    Shp_sustain,
    Shp_Punch,
    Eq_LoFrq,
    Eq_LoGain,
    Eq_LoMidQ,
    Eq_LoMidFrq,
    Eq_LoMidGain,
    Eq_HiMidQ,
    Eq_HiMidFrq,
    Eq_HiMidGain,
    Eq_HiGain,
    Eq_HiFrq,
    Comp_Thresh,
    Comp_Ratio,
    Comp_Attack,
    Comp_Release,
    Comp_DryWet,
    Out_Drive,
    Out_DriveChar,
    Out_Pan,
    Out_Vol,
};
