const std = @import("std");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;

pub const SlotTarget = struct {
    fx_index: c_int,
    param: u16,
};

// Per-encoder routing for the active module. Each of the eight top-row
// encoders either points at an (fx, param) pair or is unmapped.
pub const SlotRouting = struct {
    targets: [8]?SlotTarget = [_]?SlotTarget{null} ** 8,

    // Fill this routing's empty slots from a mapping belonging to one FX.
    // Slots already claimed by an earlier FX are left untouched, so the first
    // FX to define a slot wins.
    pub fn merge(self: *SlotRouting, fx_index: c_int, mapping: mappings.MftModuleMapping) void {
        var slot: u3 = 0;
        while (true) : (slot += 1) {
            if (self.targets[slot] == null) {
                if (mapping.slotToParam(slot)) |param| {
                    self.targets[slot] = .{ .fx_index = fx_index, .param = param };
                }
            }
            if (slot == 7) break;
        }
    }
};

// The default plugin(s) inserted when a module is selected, taken from the
// Console One defaults. IO gets both an input and an output plugin so the two
// halves of the module have something to drive.
fn defaultPluginsFor(module: MappableModule) []const [:0]const u8 {
    return switch (module) {
        .IO => &.{ "JS: Volume/Pan Smoother v5", "JS: Saturation" },
        .GATE => &.{"VST: ReaGate (Cockos)"},
        .EQ => &.{"VST: ReaEQ (Cockos)"},
        .COMP => &.{"VST: ReaComp (Cockos)"},
    };
}

fn trackHasFx(track: reaper.MediaTrack, name: [:0]const u8) bool {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var name_buf: [512:0]u8 = undefined;
        if (!reaper.TrackFX_GetFXName(track, i, &name_buf, name_buf.len)) continue;
        if (std.mem.eql(u8, std.mem.sliceTo(&name_buf, 0), name)) return true;
    }
    return false;
}

// Insert the module's default plugins onto the track if they are not already
// present, so that switching to a module gives the encoders something to drive.
// instantiate = -1 appends a fresh instance at the end of the chain.
pub fn ensureModuleFx(track: reaper.MediaTrack, module: MappableModule) void {
    for (defaultPluginsFor(module)) |name| {
        if (!trackHasFx(track, name)) {
            _ = reaper.TrackFX_AddByName(track, name, false, -1);
        }
    }
}

// Build the eight-slot routing for a module by scanning the track's FX chain.
// Every FX that has a map for the module contributes the slots it defines; the
// first FX to define a slot wins. Because a module's maps use disjoint knob
// ranges (for IO the input plugin fills knobs 1-4 and the output plugin fills
// knobs 5-8), several plugins merge into one surface without colliding. For a
// single-plugin module this simply fills that plugin's slots.
pub fn resolveModule(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule) SlotRouting {
    var routing = SlotRouting{};
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var name_buf: [512:0]u8 = undefined;
        if (!reaper.TrackFX_GetFXName(track, i, &name_buf, name_buf.len)) continue;
        const name: [:0]const u8 = std.mem.sliceTo(&name_buf, 0);
        const mapping = globals.map_store.get(module, name) orelse continue;
        routing.merge(i, mapping);
    }
    return routing;
}

test "SlotRouting.merge: input and output plugins combine without collision" {
    const t = std.testing;
    // An input plugin on knobs 1-3 and an output plugin on knobs 5-6, as the
    // IO module lays them out.
    var input = mappings.MftModuleMapping{};
    input.setSlot(0, 1);
    input.setSlot(1, 0);
    input.setSlot(2, 2);

    var output = mappings.MftModuleMapping{};
    output.setSlot(4, 0);
    output.setSlot(5, 1);

    var routing = SlotRouting{};
    routing.merge(3, input);
    routing.merge(5, output);

    try t.expectEqual(@as(?SlotTarget, .{ .fx_index = 3, .param = 1 }), routing.targets[0]);
    try t.expectEqual(@as(?SlotTarget, .{ .fx_index = 3, .param = 2 }), routing.targets[2]);
    try t.expectEqual(@as(?SlotTarget, null), routing.targets[3]);
    try t.expectEqual(@as(?SlotTarget, .{ .fx_index = 5, .param = 0 }), routing.targets[4]);
    try t.expectEqual(@as(?SlotTarget, .{ .fx_index = 5, .param = 1 }), routing.targets[5]);
    try t.expectEqual(@as(?SlotTarget, null), routing.targets[7]);
}

test "SlotRouting.merge: first FX to claim a slot wins" {
    const t = std.testing;
    var first = mappings.MftModuleMapping{};
    first.setSlot(0, 9);
    var second = mappings.MftModuleMapping{};
    second.setSlot(0, 3);

    var routing = SlotRouting{};
    routing.merge(1, first);
    routing.merge(2, second);

    try t.expectEqual(@as(?SlotTarget, .{ .fx_index = 1, .param = 9 }), routing.targets[0]);
}
