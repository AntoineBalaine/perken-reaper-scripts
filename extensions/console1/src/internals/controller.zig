const std = @import("std");
pub var Buttons = [_][]const u8{
    "disp_on",
    "disp_mode",
    "shift",
    "filt_to_comp",
    "phase_inv",
    "preset",
    "pg_up",
    "pg_dn",
    "tr1",
    "tr2",
    "tr3",
    "tr4",
    "tr5",
    "tr6",
    "tr7",
    "tr8",
    "tr9",
    "tr10",
    "tr11",
    "tr12",
    "tr13",
    "tr14",
    "tr15",
    "tr16",
    "tr17",
    "tr18",
    "tr19",
    "tr20",
    "shape",
    "hard_gate",
    "eq",
    "hp_shape",
    "lp_shape",
    "comp",
    "tr_grp",
    "tr_copy",
    "order",
    "ext_sidechain",
    "solo",
    "mute",
};

// const Modes = struct { main: .{}, fx_selection_display: .{}, settings_screen: .{} };

const Module = struct {
    name: []const u8,
    params: ?[]const u8,
    idx: ?u8,
};

/// TODO include allocator in controller struct?
pub const Controller = struct {
    id: []const u8,
    name: []const u8,
    modules: [5]Module,
    buttons: [][]const u8,
    // modes: Modes,
    action_ids: ?[]c_int,
};

pub const c1 = Controller{
    .action_ids = null,
    .id = "C1",
    .name = "Console1",
    .modules = .{ Module{ .name = "eq", .params = null, .idx = null }, Module{ .name = "comp", .params = null, .idx = null }, Module{ .name = "shape", .params = null, .idx = null }, Module{ .name = "input", .params = null, .idx = null }, Module{ .name = "output", .params = null, .idx = null } },
    .buttons = &Buttons,
    // .modes = .{ .main = .{}, .fx_selection_display = .{}, .settings_screen = .{} },
};
