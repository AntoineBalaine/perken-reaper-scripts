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

// The five physical Console One module slots, in track order. The MFT reuses
// the Console One (C1-X) suffix scheme so a track set up by either extension is
// recognized by the other. IO occupies two slots (input first, output last),
// bracketing the dynamics and EQ.
pub const ModuleSlot = enum {
    input,
    gate,
    eq,
    comp,
    output,

    // Canonical track order: input, gate, eq, comp, output.
    pub fn rank(self: ModuleSlot) u8 {
        return @intFromEnum(self);
    }

    pub fn suffixChar(self: ModuleSlot) u8 {
        return switch (self) {
            .input => 'I',
            .gate => 'S',
            .eq => 'E',
            .comp => 'C',
            .output => 'O',
        };
    }

    pub fn defaultPlugin(self: ModuleSlot) [:0]const u8 {
        return switch (self) {
            .input => "JS: Volume/Pan Smoother v5",
            .gate => "VST: ReaGate (Cockos)",
            .eq => "VST: ReaEQ (Cockos)",
            .comp => "VST: ReaComp (Cockos)",
            .output => "JS: Saturation",
        };
    }
};

// The track slots a module drives. IO spans input and output; the others are a
// single slot.
fn slotsFor(module: MappableModule) []const ModuleSlot {
    return switch (module) {
        .IO => &.{ .input, .output },
        .GATE => &.{.gate},
        .EQ => &.{.eq},
        .COMP => &.{.comp},
    };
}

fn slotsContain(slots: []const ModuleSlot, slot: ModuleSlot) bool {
    for (slots) |s| {
        if (s == slot) return true;
    }
    return false;
}

// Parse the Console One "(C1-X)" suffix, returning the module slot it names.
fn parseSlot(renamed: []const u8) ?ModuleSlot {
    const start = std.mem.lastIndexOf(u8, renamed, "(C1-") orelse return null;
    const end = std.mem.indexOfPos(u8, renamed, start, ")") orelse return null;
    for (renamed[start + 4 .. end]) |ch| {
        const slot: ?ModuleSlot = switch (ch) {
            'I' => .input,
            'S' => .gate,
            'E' => .eq,
            'C' => .comp,
            'O' => .output,
            else => null,
        };
        if (slot) |s| return s;
    }
    return null;
}

// The module slot an FX belongs to, read from its renamed_name suffix, or null
// if the FX carries no Console One suffix.
fn fxSlot(track: reaper.MediaTrack, fx: c_int) ?ModuleSlot {
    var buf: [512:0]u8 = undefined;
    if (!reaper.TrackFX_GetNamedConfigParm(track, fx, "renamed_name", &buf, buf.len)) return null;
    const renamed = std.mem.sliceTo(&buf, 0);
    if (renamed.len == 0) return null;
    return parseSlot(renamed);
}

// The FX's base plugin name for map lookup, with any Console One suffix removed.
// Reading GetFXName and stripping the suffix works whether or not this REAPER
// version folds the rename into GetFXName.
fn fxBaseName(track: reaper.MediaTrack, fx: c_int, buf: *[512:0]u8) ?[:0]const u8 {
    if (!reaper.TrackFX_GetFXName(track, fx, buf, buf.len)) return null;
    const full = std.mem.sliceTo(buf, 0);
    const base_len = std.mem.lastIndexOf(u8, full, " (C1-") orelse full.len;
    buf[base_len] = 0;
    return buf[0..base_len :0];
}

// Toggle the floating window of one FX. TrackFX_GetOpen reports whether it is
// visible; showFlag 3 shows the floating window, 2 hides it.
pub fn toggleFxWindow(track: reaper.MediaTrack, fx_index: c_int) void {
    if (reaper.TrackFX_GetOpen(track, fx_index)) {
        reaper.TrackFX_Show(track, fx_index, 2);
    } else {
        reaper.TrackFX_Show(track, fx_index, 3);
    }
}

fn trackHasSlot(track: reaper.MediaTrack, slot: ModuleSlot) bool {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i)) |s| {
            if (s == slot) return true;
        }
    }
    return false;
}

// The chain index to insert a slot at so that suffixed FX stay in canonical
// order: before the first suffixed FX of higher rank, or the end of the chain.
fn insertPosFor(track: reaper.MediaTrack, slot: ModuleSlot) c_int {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i)) |s| {
            if (s.rank() > slot.rank()) return i;
        }
    }
    return -1;
}

// An existing un-suffixed FX whose base name matches the slot's default plugin,
// so we can adopt it (suffix it) instead of inserting a duplicate.
fn findUnsuffixedFx(track: reaper.MediaTrack, name: [:0]const u8) ?c_int {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i) != null) continue;
        var buf: [512:0]u8 = undefined;
        const base = fxBaseName(track, i, &buf) orelse continue;
        if (std.mem.eql(u8, base, name)) return i;
    }
    return null;
}

fn setSlotSuffix(track: reaper.MediaTrack, fx: c_int, name: [:0]const u8, slot: ModuleSlot) void {
    var buf: [560:0]u8 = undefined;
    const renamed = std.fmt.bufPrintZ(&buf, "{s} (C1-{c})", .{ name, slot.suffixChar() }) catch return;
    _ = reaper.TrackFX_SetNamedConfigParm(track, fx, "renamed_name", renamed);
}

// Ensure each slot the module drives has a suffixed FX on the track. A missing
// slot is filled by adopting an existing un-suffixed instance of its default
// plugin if present, otherwise inserting a fresh one at the canonical position.
// Because the position comes from the slot rank rather than the selection order,
// selecting modules out of order still yields a correctly ordered chain.
pub fn ensureModuleFx(track: reaper.MediaTrack, module: MappableModule) void {
    for (slotsFor(module)) |slot| {
        if (trackHasSlot(track, slot)) continue;
        const name = slot.defaultPlugin();

        if (findUnsuffixedFx(track, name)) |existing| {
            setSlotSuffix(track, existing, name, slot);
            continue;
        }

        const insert_pos = insertPosFor(track, slot);
        const instantiate: c_int = if (insert_pos >= 0) -1000 - insert_pos else -1;
        const new_idx = reaper.TrackFX_AddByName(track, name, false, instantiate);
        if (new_idx < 0) continue;
        setSlotSuffix(track, new_idx, name, slot);
    }
}

// Build the eight-slot routing for a module from the suffixed FX on the track.
// Every FX whose suffix names one of the module's slots contributes the knob
// slots its map defines; the first FX to define a knob wins. For IO the input
// plugin (knobs 1-4) and the output plugin (knobs 5-8) merge onto one surface.
pub fn resolveModule(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule) SlotRouting {
    var routing = SlotRouting{};
    const slots = slotsFor(module);
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const slot = fxSlot(track, i) orelse continue;
        if (!slotsContain(slots, slot)) continue;
        var name_buf: [512:0]u8 = undefined;
        const base = fxBaseName(track, i, &name_buf) orelse continue;
        const mapping = globals.map_store.get(module, base) orelse continue;
        routing.merge(i, mapping);
    }
    return routing;
}

test "parseSlot: reads the C1 suffix char" {
    const t = std.testing;
    try t.expectEqual(@as(?ModuleSlot, .input), parseSlot("JS: Vol (C1-I)"));
    try t.expectEqual(@as(?ModuleSlot, .eq), parseSlot("VST: ReaEQ (Cockos) (C1-E)"));
    try t.expectEqual(@as(?ModuleSlot, .output), parseSlot("JS: Saturation (C1-O)"));
    try t.expectEqual(@as(?ModuleSlot, null), parseSlot("VST: ReaEQ (Cockos)"));
    try t.expectEqual(@as(?ModuleSlot, null), parseSlot("Plugin (C1-"));
}

test "ModuleSlot: canonical rank order" {
    const t = std.testing;
    try t.expect(ModuleSlot.input.rank() < ModuleSlot.gate.rank());
    try t.expect(ModuleSlot.gate.rank() < ModuleSlot.eq.rank());
    try t.expect(ModuleSlot.eq.rank() < ModuleSlot.comp.rank());
    try t.expect(ModuleSlot.comp.rank() < ModuleSlot.output.rank());
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
