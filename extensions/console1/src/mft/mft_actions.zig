//! The actions that the controller adds to REAPER's Action List: their ids and their names. The extension registers them and runs them, and the AUTO plate
//! of the mapping panel lists them, so that a control of the AUTO page can run them. Because this is only data, it is here, where both reach it.
const std = @import("std");

pub const Kind = enum { toggle_ui, order_eq_s_c, order_s_c_eq, order_s_eq_c, order_next, order_previous, calibrate };

pub const Entry = struct {
    kind: Kind,
    /// The id that the action is registered with. REAPER names it with an underscore in front, which is how a map keeps it (`command`).
    id: [:0]const u8,
    command: [:0]const u8,
    name: [:0]const u8,
};

fn entry(kind: Kind, comptime id: [:0]const u8, name: [:0]const u8) Entry {
    return .{ .kind = kind, .id = id, .command = "_" ++ id, .name = name };
}

pub const entries = [_]Entry{
    entry(.toggle_ui, "PRKN_MFT_TOGGLE_UI", "MFT: Toggle UI"),
    entry(.order_eq_s_c, "PRKN_MFT_ORDER_EQ_S_C", "MFT: Module order EQ-S-C"),
    entry(.order_s_c_eq, "PRKN_MFT_ORDER_S_C_EQ", "MFT: Module order S-C-EQ"),
    entry(.order_s_eq_c, "PRKN_MFT_ORDER_S_EQ_C", "MFT: Module order S-EQ-C"),
    entry(.order_next, "PRKN_MFT_ORDER_NEXT", "MFT: Next module order"),
    entry(.order_previous, "PRKN_MFT_ORDER_PREVIOUS", "MFT: Previous module order"),
    entry(.calibrate, "PRKN_MFT_CALIBRATE", "MFT: Calibration wizard"),
};

/// The name of an action of the controller from the name that a map keeps, or null for another action.
pub fn nameOfCommand(command: []const u8) ?[:0]const u8 {
    for (entries) |e| {
        if (std.mem.eql(u8, e.command, command)) return e.name;
    }
    return null;
}

test "every action of the controller has an id of its own, and its command is the id with an underscore" {
    const t = std.testing;
    for (entries, 0..) |a, i| {
        try t.expect(std.mem.startsWith(u8, a.id, "PRKN_MFT_"));
        try t.expectEqualStrings(a.id, a.command[1..]);
        for (entries[i + 1 ..]) |b| try t.expect(!std.mem.eql(u8, a.id, b.id));
    }
    try t.expectEqualStrings("MFT: Next module order", nameOfCommand("_PRKN_MFT_ORDER_NEXT").?);
    try t.expectEqual(@as(?[:0]const u8, null), nameOfCommand("_SWS_ABOUT"));
}
