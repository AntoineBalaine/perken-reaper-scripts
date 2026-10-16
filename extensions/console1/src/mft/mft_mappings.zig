const std = @import("std");
const MftActiveModule = @import("mft_state.zig").MftActiveModule;

pub const MFT_MAPPING_FORMAT_VERSION: u8 = 1;

// A mappable module routes the eight top-row encoders to FX parameters. Only
// IO, GATE, EQ and COMP carry FX mappings; SETTINGS and TRANSPORT are control
// modes with no parameter mapping.
pub const MappableModule = enum {
    IO,
    GATE,
    EQ,
    COMP,

    pub fn fromActive(module: MftActiveModule) ?MappableModule {
        return switch (module) {
            .IO => .IO,
            .GATE => .GATE,
            .EQ => .EQ,
            .COMP => .COMP,
            .SETTINGS, .TRANSPORT => null,
        };
    }

    pub fn dirName(self: MappableModule) [:0]const u8 {
        return switch (self) {
            .IO => "IO",
            .GATE => "GATE",
            .EQ => "EQ",
            .COMP => "COMP",
        };
    }
};

pub const MftModuleMapping = struct {
    version: u8 = MFT_MAPPING_FORMAT_VERSION,
    knob_1: ?u16 = null,
    knob_2: ?u16 = null,
    knob_3: ?u16 = null,
    knob_4: ?u16 = null,
    knob_5: ?u16 = null,
    knob_6: ?u16 = null,
    knob_7: ?u16 = null,
    knob_8: ?u16 = null,

    pub fn slotToParam(self: *const MftModuleMapping, slot: u3) ?u16 {
        return switch (slot) {
            0 => self.knob_1,
            1 => self.knob_2,
            2 => self.knob_3,
            3 => self.knob_4,
            4 => self.knob_5,
            5 => self.knob_6,
            6 => self.knob_7,
            7 => self.knob_8,
        };
    }

    // Assign a slot by its knob index. Used by the INI parser, which reads
    // keys of the form "knob_N".
    pub fn setSlot(self: *MftModuleMapping, slot: u3, value: u16) void {
        switch (slot) {
            0 => self.knob_1 = value,
            1 => self.knob_2 = value,
            2 => self.knob_3 = value,
            3 => self.knob_4 = value,
            4 => self.knob_5 = value,
            5 => self.knob_6 = value,
            6 => self.knob_7 = value,
            7 => self.knob_8 = value,
        }
    }
};

test "MftModuleMapping: slot round-trip" {
    const t = std.testing;
    var m = MftModuleMapping{};
    try t.expectEqual(@as(?u16, null), m.slotToParam(0));

    m.setSlot(0, 9);
    m.setSlot(7, 3);
    try t.expectEqual(@as(?u16, 9), m.slotToParam(0));
    try t.expectEqual(@as(?u16, 3), m.slotToParam(7));
    try t.expectEqual(@as(?u16, null), m.slotToParam(4));
}

test "MappableModule: only FX modules map" {
    const t = std.testing;
    try t.expectEqual(@as(?MappableModule, .EQ), MappableModule.fromActive(.EQ));
    try t.expectEqual(@as(?MappableModule, null), MappableModule.fromActive(.SETTINGS));
    try t.expectEqual(@as(?MappableModule, null), MappableModule.fromActive(.TRANSPORT));
}
