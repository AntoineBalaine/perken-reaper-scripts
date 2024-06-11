const std = @import("std");
pub const Buttons = struct { .disp_on = u8, .disp_mode = u8, .shift = u8, .filt_to_comp = u8, .phase_inv = u8, .preset = u8, .pg_up = u8, .pg_dn = u8, .tr1 = u8, .tr2 = u8, .tr3 = u8, .tr4 = u8, .tr5 = u8, .tr6 = u8, .tr7 = u8, .tr8 = u8, .tr9 = u8, .tr10 = u8, .tr11 = u8, .tr12 = u8, .tr13 = u8, .tr14 = u8, .tr15 = u8, .tr16 = u8, .tr17 = u8, .tr18 = u8, .tr19 = u8, .tr20 = u8, .shape = u8, .hard_gate = u8, .eq = u8, .hp_shape = u8, .lp_shape = u8, .comp = u8, .tr_grp = u8, .tr_copy = u8, .order = u8, .ext_sidechain = u8, .solo = u8, .mute = u8 };

const Modes = struct { .main = .{}, .fx_selection_display = .{}, .settings_screen = .{} };

const Module = struct {
    name: [*:0]const u8,
    params: ?[*:0]const u8,
    idx: ?u8,
};

/// TODO include allocator in controller struct?
pub const Controller = struct { .id = [*:0]const u8, .name = [*:0]const u8, .modules = []Module, .buttons = Buttons, .modes = Modes, .action_ids = ?[]c_int };

pub const c1 = Controller{
    .id = "C1",
    .name = "Console1",
    .modules = .{ Module{ .name = "eq" }, Module{ .name = "comp" }, Module{ .name = "shape" }, Module{ .name = "input" }, Module{ .name = "output" } },
    .buttons = Buttons{
        .disp_on = 1, // if not loaded, load default channel strip on track, else quit

        .disp_mode = 2, // switch to next mode (fx ctrl, settings)

        .shift = 3, // Shift's going to have to be excluded, and used only to trigger values of realearn "shift" param
        .filt_to_comp = 4, // switch order of fx
        .phase_inv = 5,
        .preset = 6,
        .pg_up = 7,
        .pg_dn = 8,
        .tr1 = 9,
        .tr2 = 10,
        .tr3 = 11,
        .tr4 = 12,
        .tr5 = 13,
        .tr6 = 14,
        .tr7 = 15,
        .tr8 = 16,
        .tr9 = 17,
        .tr10 = 18,
        .tr11 = 19,
        .tr12 = 20,
        .tr13 = 21,
        .tr14 = 22,
        .tr15 = 23,
        .tr16 = 24,
        .tr17 = 25,
        .tr18 = 26,
        .tr19 = 27,
        .tr20 = 28,
        .shape = 29,
        .hard_gate = 30,
        .eq = 31,
        .hp_shape = 32,
        .lp_shape = 33,
        .comp = 34,
        .tr_grp = 35,
        .tr_copy = 36,
        .order = 37,
        .ext_sidechain = 38,
        .solo = 39,
        .mute = 40,
    },
    .modes = .{ .main = .{}, .fx_selection_display = .{}, .settings_screen = .{} },
};
