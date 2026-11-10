const std = @import("std");
const MftActiveModule = @import("mft_state.zig").MftActiveModule;

pub const MFT_MAPPING_FORMAT_VERSION: u8 = 2;

// A mappable module routes the encoders of its page to FX parameters. Only INPUT, GATE, EQ, COMP and OUTPUT carry FX mappings; SETTINGS,
// TRANSPORT and AUTO are control pages with no FX of their own.
pub const MappableModule = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    OUTPUT,

    pub fn fromActive(module: MftActiveModule) ?MappableModule {
        return switch (module) {
            .INPUT => .INPUT,
            .GATE => .GATE,
            .EQ => .EQ,
            .COMP => .COMP,
            .OUTPUT => .OUTPUT,
            .SETTINGS, .TRANSPORT, .AUTO => null,
        };
    }

    pub fn dirName(self: MappableModule) [:0]const u8 {
        return switch (self) {
            .INPUT => "INPUT",
            .GATE => "GATE",
            .EQ => "EQ",
            .COMP => "COMP",
            .OUTPUT => "OUTPUT",
        };
    }
};

/// How many knobs and how many pushes a page of the controller has: the sixteen encoders all turn, and the eight of the top two rows also
/// push.
pub const knob_count = 16;
pub const push_count = 8;

/// In a map, the value `wet` stands for the dry/wet parameter that REAPER gives every FX. Because the number of that parameter is not the same
/// in every plugin, the map keeps this marker, and the routing replaces it by the number that the FX has.
pub const wet_param: u16 = 0xFFFF;

/// What a click on a push does. Most pushes step a parameter, and the pushes of the EQ change the shape of a band, which ReaEQ does not
/// offer as a parameter.
pub const PushAction = union(enum) {
    /// Toggles a parameter, or steps it when it has steps.
    param: u16,
    /// Steps the shape of a band of ReaEQ, counted from 0.
    band: u2,
};

/// The parameters that the encoders of one FX move, by position: `knob_N` in a map file is the position N of the grid (1 to 16, row by
/// row), and `push_N` the push of the encoder N (1 to 8). The value of a knob is a parameter number or `wet`, and the value of a push is a
/// parameter number, `wet` or `band:N`. Because the maps of the first version only had `knob_1` to `knob_8`, they stay valid in this version.
pub const MftModuleMapping = struct {
    version: u8 = MFT_MAPPING_FORMAT_VERSION,
    knobs: [knob_count]?u16 = @splat(null),
    pushes: [push_count]?PushAction = @splat(null),

    pub fn slotToParam(self: *const MftModuleMapping, slot: u4) ?u16 {
        return self.knobs[slot];
    }

    pub fn pushAt(self: *const MftModuleMapping, push: u3) ?PushAction {
        return self.pushes[push];
    }

    /// Whether no knob and no push has a parameter.
    pub fn isEmpty(self: *const MftModuleMapping) bool {
        for (self.knobs) |knob| if (knob != null) return false;
        for (self.pushes) |push| if (push != null) return false;
        return true;
    }

    /// Assigns a knob by its position. The INI parser reads keys of the form `knob_N`.
    pub fn setSlot(self: *MftModuleMapping, slot: u4, value: u16) void {
        self.knobs[slot] = value;
    }

    pub fn setPush(self: *MftModuleMapping, push: u3, action: PushAction) void {
        self.pushes[push] = action;
    }

    /// The same map with the dry/wet marker replaced by the number of the parameter that the FX has for it, or by nothing when the FX has none.
    pub fn withWet(self: *const MftModuleMapping, wet_index: ?u16) MftModuleMapping {
        var out = self.*;
        for (&out.knobs) |*knob| {
            if (knob.* == wet_param) knob.* = wet_index;
        }
        for (&out.pushes) |*push| {
            const action = push.* orelse continue;
            if (action == .param and action.param == wet_param) {
                push.* = if (wet_index) |index| .{ .param = index } else null;
            }
        }
        return out;
    }
};

test "MftModuleMapping: slot round-trip" {
    const t = std.testing;
    var m = MftModuleMapping{};
    try t.expectEqual(@as(?u16, null), m.slotToParam(0));

    m.setSlot(0, 9);
    m.setSlot(7, 3);
    m.setSlot(15, 4);
    m.setPush(7, .{ .param = 5 });
    try t.expectEqual(@as(?u16, 9), m.slotToParam(0));
    try t.expectEqual(@as(?u16, 3), m.slotToParam(7));
    try t.expectEqual(@as(?u16, 4), m.slotToParam(15));
    try t.expectEqual(@as(?PushAction, .{ .param = 5 }), m.pushAt(7));
    try t.expectEqual(@as(?PushAction, null), m.pushAt(0));
    try t.expectEqual(@as(?u16, null), m.slotToParam(4));
}

test "MappableModule: only FX modules map" {
    const t = std.testing;
    try t.expectEqual(@as(?MappableModule, .EQ), MappableModule.fromActive(.EQ));
    try t.expectEqual(@as(?MappableModule, null), MappableModule.fromActive(.SETTINGS));
    try t.expectEqual(@as(?MappableModule, null), MappableModule.fromActive(.TRANSPORT));
    try t.expectEqual(@as(?MappableModule, null), MappableModule.fromActive(.AUTO));
    try t.expectEqual(@as(?MappableModule, .OUTPUT), MappableModule.fromActive(.OUTPUT));
}

test "MftModuleMapping.withWet: the marker becomes the parameter of the FX, or nothing" {
    const t = std.testing;
    var m = MftModuleMapping{};
    m.setSlot(15, wet_param);
    m.setSlot(0, 4);
    m.setPush(0, .{ .param = wet_param });
    m.setPush(1, .{ .band = 2 });
    const resolved = m.withWet(17);
    try t.expectEqual(@as(?u16, 17), resolved.slotToParam(15));
    try t.expectEqual(@as(?u16, 4), resolved.slotToParam(0));
    try t.expectEqual(@as(?PushAction, .{ .param = 17 }), resolved.pushAt(0));
    try t.expectEqual(@as(?PushAction, .{ .band = 2 }), resolved.pushAt(1));
    const without = m.withWet(null);
    try t.expectEqual(@as(?u16, null), without.slotToParam(15));
    try t.expectEqual(@as(?PushAction, null), without.pushAt(0));
    try t.expectEqual(@as(?PushAction, .{ .band = 2 }), without.pushAt(1));
}
