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

/// The parameters that the encoders of one FX move, by position: `knob_N` in a map file is the position N of the grid (1 to 16, row by
/// row), and `push_N` the push of the encoder N (1 to 8). Because the maps of the first version only had `knob_1` to `knob_8`, they stay
/// valid in this version.
pub const MftModuleMapping = struct {
    version: u8 = MFT_MAPPING_FORMAT_VERSION,
    knobs: [knob_count]?u16 = @splat(null),
    pushes: [push_count]?u16 = @splat(null),

    pub fn slotToParam(self: *const MftModuleMapping, slot: u4) ?u16 {
        return self.knobs[slot];
    }

    pub fn pushToParam(self: *const MftModuleMapping, push: u3) ?u16 {
        return self.pushes[push];
    }

    /// Assigns a knob by its position. The INI parser reads keys of the form `knob_N`.
    pub fn setSlot(self: *MftModuleMapping, slot: u4, value: u16) void {
        self.knobs[slot] = value;
    }

    pub fn setPush(self: *MftModuleMapping, push: u3, value: u16) void {
        self.pushes[push] = value;
    }
};

test "MftModuleMapping: slot round-trip" {
    const t = std.testing;
    var m = MftModuleMapping{};
    try t.expectEqual(@as(?u16, null), m.slotToParam(0));

    m.setSlot(0, 9);
    m.setSlot(7, 3);
    m.setSlot(15, 4);
    m.setPush(7, 5);
    try t.expectEqual(@as(?u16, 9), m.slotToParam(0));
    try t.expectEqual(@as(?u16, 3), m.slotToParam(7));
    try t.expectEqual(@as(?u16, 4), m.slotToParam(15));
    try t.expectEqual(@as(?u16, 5), m.pushToParam(7));
    try t.expectEqual(@as(?u16, null), m.pushToParam(0));
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
