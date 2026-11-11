const std = @import("std");
const mft_globals = @import("mft_globals.zig");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_push = @import("mft_push.zig");
const mft_auto = @import("mft_auto.zig");
const mft_order = @import("mft_order.zig");
const mft_actions = @import("mft_actions.zig");

pub const SlotTarget = struct {
    fx_index: c_int,
    param: u16,
};

/// What a click on the push of an encoder does, and in which FX.
pub const PushRoute = struct {
    fx_index: c_int,
    action: mappings.PushAction,
};

// Per-encoder routing for the active module. Each of the sixteen encoders
// either points at an (fx, param) pair or is unmapped, and each of the eight
// pushes either has an action or has none.
pub const SlotRouting = struct {
    targets: [mappings.knob_count]?SlotTarget = @splat(null),
    pushes: [mappings.push_count]?PushRoute = @splat(null),

    // Fill this routing's empty slots from a mapping belonging to one FX.
    // Slots already claimed by an earlier FX are left untouched, so the first
    // FX to define a slot wins.
    pub fn merge(self: *SlotRouting, fx_index: c_int, mapping: mappings.MftModuleMapping) void {
        for (&self.targets, 0..) |*target, slot| {
            if (target.* != null) continue;
            if (mapping.slotToParam(@intCast(slot))) |param| {
                target.* = .{ .fx_index = fx_index, .param = param };
            }
        }
        for (&self.pushes, 0..) |*push, index| {
            if (push.* != null) continue;
            if (mapping.pushAt(@intCast(index))) |action| {
                push.* = .{ .fx_index = fx_index, .action = action };
            }
        }
    }
};

// The five physical Console One module slots, in track order. The MFT reuses
// the Console One (C1-X) suffix scheme so a track set up by either extension is
// recognized by the other. The input is the first slot and the output the last, bracketing the dynamics and EQ.
pub const ModuleSlot = enum {
    input,
    gate,
    eq,
    comp,
    output,
    /// A channel strip, which is one plugin that does the work of all the modules.
    strip,

    // Canonical track order: input, gate, eq, comp, output, and the strip after them.
    pub fn rank(self: ModuleSlot) u8 {
        return @backingInt(self);
    }

    // The place of the slot on a track whose modules are in `order`: the input first, the shape, the EQ and the compressor in the order, then the output,
    // and the strip after them.
    pub fn rankIn(self: ModuleSlot, order: mft_order.Order) u8 {
        return switch (self) {
            .input => 0,
            .gate => 1 + @as(u8, @intCast(order.rank(.gate))),
            .eq => 1 + @as(u8, @intCast(order.rank(.eq))),
            .comp => 1 + @as(u8, @intCast(order.rank(.comp))),
            .output => 4,
            .strip => 5,
        };
    }

    // The module whose order can change, or null for the input, the output and the strip.
    pub fn dyn(self: ModuleSlot) ?mft_order.Dyn {
        return switch (self) {
            .gate => .gate,
            .eq => .eq,
            .comp => .comp,
            else => null,
        };
    }

    pub fn suffixChar(self: ModuleSlot) u8 {
        return switch (self) {
            .input => 'I',
            .gate => 'S',
            .eq => 'E',
            .comp => 'C',
            .output => 'O',
            .strip => 'X',
        };
    }
};

// The default plugin for a slot, read from user preferences.
fn defaultPluginFor(globals: *MftGlobals, slot: ModuleSlot) [:0]const u8 {
    return switch (slot) {
        .input => globals.preferences.default_input,
        .gate => globals.preferences.default_gate,
        .eq => globals.preferences.default_eq,
        .comp => globals.preferences.default_comp,
        .output => globals.preferences.default_output,
        .strip => globals.preferences.default_strip,
    };
}

// The track slot that a module drives.
fn slotsFor(module: MappableModule) []const ModuleSlot {
    return switch (module) {
        .INPUT => &.{.input},
        .GATE => &.{.gate},
        .EQ => &.{.eq},
        .COMP => &.{.comp},
        .OUTPUT => &.{.output},
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
            'X' => .strip,
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

// The value of `TrackFX_GetChainVisible` when the chain window is hidden. A visible chain gives the index of the
// effect shown, or -2 when no effect is selected.
const CHAIN_HIDDEN: c_int = -1;

// The `showFlag` of `TrackFX_Show` that a press of the chain key sends. Because the chain is visible whenever the
// state is not CHAIN_HIDDEN, whether the window has the focus or not, a visible chain is hidden (0) and a hidden one is
// shown (1).
pub fn chainShowFlag(chain_visible: c_int) c_int {
    return if (chain_visible != CHAIN_HIDDEN) 0 else 1;
}

// Toggle the track's FX chain window, focused on the given FX. Matches the
// Console One, which opens the whole chain rather than a single floating window.
// The state is the chain's own visibility, and not the "open" state of the FX, which follows the focus.
pub fn toggleFxChain(track: reaper.MediaTrack, fx_index: c_int) void {
    reaper.TrackFX_Show(track, fx_index, chainShowFlag(reaper.TrackFX_GetChainVisible(track)));
}

// The FX whose window L1 should toggle for the active module: the last-tweaked
// FX if it belongs to the module, otherwise the module's first (primary) FX.
// This keeps L1 showing the plugin that matches the mode on screen.
pub fn moduleFxToShow(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule, last: ?c_int) ?c_int {
    const routing = resolveModule(globals, track, module);
    var first: ?c_int = null;
    for (routing.targets) |maybe_target| {
        if (maybe_target) |target| {
            if (first == null) first = target.fx_index;
            if (last) |l| {
                if (l == target.fx_index) return l;
            }
        }
    }
    return first;
}

// The name of an FX as its map is found by, which is its base name without the suffix, written into `buf`. Null when REAPER gives no name.
pub fn fxMapName(track: reaper.MediaTrack, fx: c_int, buf: *[160:0]u8) ?[:0]const u8 {
    var full: [512:0]u8 = undefined;
    const base = fxBaseName(track, fx, &full) orelse return null;
    const length = @min(base.len, buf.len - 1);
    @memcpy(buf[0..length], base[0..length]);
    buf[length] = 0;
    return buf[0..length :0];
}

// The first FX of the track that has that name (its base name, without the suffix of the Console One), or null.
pub fn findFxByName(track: reaper.MediaTrack, name: []const u8) ?c_int {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var buf: [512:0]u8 = undefined;
        const base = fxBaseName(track, i, &buf) orelse continue;
        if (std.mem.eql(u8, base, name)) return i;
    }
    return null;
}

// The command id of an action of the AUTO page, which REAPER is asked for when the action is one of a script or an extension. Null for a target that is
// no action, or an action that REAPER does not have any more.
pub fn autoCommand(target: mft_auto.Target) ?c_int {
    return switch (target) {
        .action => |id| id,
        .named_action => |named| blk: {
            const id = reaper.NamedCommandLookup(named.name());
            break :blk if (id > 0) id else null;
        },
        .fx_param => null,
    };
}

// The target of an action that the Action List gave: a native action by its id, and one of a script or an extension by its name, since its id changes.
pub fn actionTarget(id: c_int) mft_auto.Target {
    // REAPER gives no name (a null pointer) for a native action, which the declaration of the binding does not allow, so the function is taken as one
    // that can return null.
    const lookup: *const fn (c_int) callconv(.c) ?[*:0]const u8 = @ptrCast(reaper.ReverseNamedCommandLookup);
    const name = lookup(id) orelse return .{ .action = id };
    var buf: [mft_auto.fx_name_len + 1]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "_{s}", .{std.mem.span(name)}) catch return .{ .action = id };
    return .{ .named_action = mft_auto.NamedAction.init(text) };
}

// The name of an action as the Action List writes it, written into `buf`, or the name of the list of the AUTO page when REAPER gives none.
pub fn actionName(target: mft_auto.Target, buf: *[160:0]u8) [:0]const u8 {
    // The unit tests have no REAPER to ask, so they get the name of the list of the AUTO page.
    if (comptime @import("builtin").is_test) {
        return switch (target) {
            .action => |id| mft_auto.actionLabel(id) orelse "Action",
            .named_action => |named| std.mem.printSentinel(buf, "{s}", .{named.name()}, 0) catch "Action",
            .fx_param => "Action",
        };
    }
    // An action of the controller has its name here, even when REAPER does not know it (it is not registered yet, or in the unit tests).
    if (target == .named_action) {
        if (mft_actions.nameOfCommand(target.named_action.name())) |name| return name;
    }
    const id = autoCommand(target) orelse return switch (target) {
        .named_action => |named| std.mem.printSentinel(buf, "{s} (missing)", .{named.name()}, 0) catch "Action",
        else => "Action",
    };
    if (reaper.SectionFromUniqueID(0)) |main| {
        if (reaper.kbd_getTextFromCmd(id, main)) |text| {
            const span = std.mem.span(text);
            if (span.len > 0) return std.mem.printSentinel(buf, "{s}", .{span}, 0) catch "Action";
        }
    }
    if (mft_auto.actionLabel(id)) |label| return label;
    return std.mem.printSentinel(buf, "Action {d}", .{id}, 0) catch "Action";
}

// The routing of the AUTO page on a track: the knobs and the pushes that have a parameter of an FX of the track, which is found by its name. The ones that
// have an action are not in it, since they move no parameter.
pub fn resolveAuto(globals: *MftGlobals, track: reaper.MediaTrack) SlotRouting {
    const map = globals.map_store.getAuto(mft_globals.hostIo());
    var routing = SlotRouting{};
    for (map.knobs, 0..) |maybe, i| {
        const target = maybe orelse continue;
        if (target != .fx_param) continue;
        const fx = findFxByName(track, target.fx_param.name()) orelse continue;
        routing.targets[i] = .{ .fx_index = fx, .param = target.fx_param.param };
    }
    for (map.pushes, 0..) |maybe, i| {
        const target = maybe orelse continue;
        if (target != .fx_param) continue;
        const fx = findFxByName(track, target.fx_param.name()) orelse continue;
        routing.pushes[i] = .{ .fx_index = fx, .action = .{ .param = target.fx_param.param } };
    }
    return routing;
}

// The FX that does the work of a module on the track: the channel strip when the track has one, and otherwise the plugin of the module's slot. Null when
// the track has none.
pub fn fxForModule(track: reaper.MediaTrack, module: MappableModule) ?c_int {
    if (findStrip(track)) |strip| return strip;
    const slots = slotsFor(module);
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const slot = fxSlot(track, i) orelse continue;
        if (slotsContain(slots, slot)) return i;
    }
    return null;
}

// Whether a plugin of the module's slot is bypassed. A module that has no plugin on the track is not bypassed.
pub fn moduleBypassed(track: reaper.MediaTrack, module: MappableModule) bool {
    const slots = slotsFor(module);
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const slot = fxSlot(track, i) orelse continue;
        if (slotsContain(slots, slot) and !reaper.TrackFX_GetEnabled(track, i)) return true;
    }
    return false;
}

// Bypasses the plugins of the module's slot, or brings them back when they are bypassed.
pub fn toggleBypass(track: reaper.MediaTrack, module: MappableModule) void {
    const enable = moduleBypassed(track, module);
    const slots = slotsFor(module);
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const slot = fxSlot(track, i) orelse continue;
        if (slotsContain(slots, slot)) reaper.TrackFX_SetEnabled(track, i, enable);
    }
}

// The value of `TrackFX_Show` that shows the floating window of an FX, and the one that hides it.
const SHOW_FLOATING: c_int = 3;
const HIDE_FLOATING: c_int = 2;

// Opens the window of an FX, or closes it when it is open.
pub fn toggleFxWindow(track: reaper.MediaTrack, fx_index: c_int) void {
    const open = reaper.TrackFX_GetFloatingWindow(track, fx_index) != null;
    reaper.TrackFX_Show(track, fx_index, if (open) HIDE_FLOATING else SHOW_FLOATING);
}

pub fn toggleMute(track: reaper.MediaTrack) void {
    _ = reaper.CSurf_OnMuteChange(track, -1);
}

pub fn toggleSolo(track: reaper.MediaTrack) void {
    _ = reaper.CSurf_OnSoloChange(track, -1);
}

pub fn togglePhase(track: reaper.MediaTrack) void {
    const cur = reaper.GetMediaTrackInfo_Value(track, "B_PHASE");
    _ = reaper.SetMediaTrackInfo_Value(track, "B_PHASE", if (cur == 0) 1 else 0);
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

// The chain index to insert a slot at so that the suffixed FX stay in the order of the modules that the settings prefer: before the first suffixed FX that
// comes after it in that order, or the end of the chain.
fn insertPosFor(globals: *MftGlobals, track: reaper.MediaTrack, slot: ModuleSlot) c_int {
    const order = globals.preferences.module_order;
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i)) |s| {
            if (s.rankIn(order) > slot.rankIn(order)) return i;
        }
    }
    return -1;
}

// The modules of each FX of the track, null for the FX that are not the shape, the EQ or the compressor. It returns how many FX there are.
fn chainKinds(track: reaper.MediaTrack, kinds: *[mft_order.max_fx]?mft_order.Dyn) usize {
    const count: usize = @intCast(@max(@min(reaper.TrackFX_GetCount(track), mft_order.max_fx), 0));
    for (0..count) |i| {
        kinds[i] = if (fxSlot(track, @intCast(i))) |slot| slot.dyn() else null;
    }
    return count;
}

// The order that the modules of the track are in, or null when it has fewer than two of them or they are in no order of the list.
pub fn trackOrder(track: reaper.MediaTrack) ?mft_order.Order {
    var kinds: [mft_order.max_fx]?mft_order.Dyn = undefined;
    return mft_order.orderOf(kinds[0..chainKinds(track, &kinds)]);
}

// The 16 bytes of the GUID of an FX, which tell it apart while the FX of the chain move.
fn fxGuid(track: reaper.MediaTrack, fx: c_int) [16]u8 {
    const bytes: *const [16]u8 = @ptrCast(reaper.TrackFX_GetFXGUID(track, fx));
    return bytes.*;
}

// Puts the shape, the EQ and the compressor of the track in an order. They change places among the places they have, and the other FX stay where they are
// (see mft_order.targetChain). Each FX is found by its GUID, since the indices change as the FX move; the places are filled from the first, so the FX that
// goes to a place is always at it or after it, and moves up to it.
pub fn applyOrder(track: reaper.MediaTrack, order: mft_order.Order) void {
    var kinds: [mft_order.max_fx]?mft_order.Dyn = undefined;
    const count = chainKinds(track, &kinds);
    var target: [mft_order.max_fx]usize = undefined;
    mft_order.targetChain(kinds[0..count], order, &target);
    var guids: [mft_order.max_fx][16]u8 = undefined;
    for (0..count) |i| guids[i] = fxGuid(track, @intCast(i));
    for (0..count) |place| {
        const wanted = guids[target[place]];
        var at: usize = place;
        while (at < count and !std.mem.eql(u8, &fxGuid(track, @intCast(at)), &wanted)) : (at += 1) {}
        std.debug.assert(at < count);
        if (at != place) reaper.TrackFX_CopyToTrack(track, @intCast(at), track, @intCast(place), true);
    }
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
    const renamed = std.mem.printSentinel(&buf, "{s} (C1-{c})", .{ name, slot.suffixChar() }, 0) catch return;
    _ = reaper.TrackFX_SetNamedConfigParm(track, fx, "renamed_name", renamed);
}

// The index of the channel strip on the track, or null when the track has none.
pub fn findStrip(track: reaper.MediaTrack) ?c_int {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i)) |slot| {
            if (slot == .strip) return i;
        }
    }
    return null;
}

// Whether any FX of the track carries a suffix of the Console One.
fn hasSuffixedFx(track: reaper.MediaTrack) bool {
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i) != null) return true;
    }
    return false;
}

// Adds the default channel strip to the track and marks it as one. Returns false when no strip is named or the plugin could not be added.
fn insertDefaultStrip(globals: *MftGlobals, track: reaper.MediaTrack) bool {
    const name = defaultPluginFor(globals, .strip);
    if (name.len == 0) return false;
    const index = reaper.TrackFX_AddByName(track, name, false, -1);
    if (index < 0) {
        std.log.scoped(.mft_fx).warn("The default channel strip '{s}' could not be added", .{name});
        return false;
    }
    setSlotSuffix(track, index, name, .strip);
    afterInsert(globals, track, index);
    return true;
}

// Loads a plugin into the slot of a module: the plugin that the slot has is replaced by the new one, which takes its place in the chain. Returns
// false when the track has a channel strip, which does the work of the modules, or when the plugin could not be added.
pub fn loadPlugin(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule, fx_name: [:0]const u8) bool {
    if (findStrip(track) != null) return false;
    const slot = slotsFor(module)[0];
    // The new plugin goes where the old one was, and at the place that the order of the slots gives when there was none.
    var position: c_int = -1;
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        if (fxSlot(track, i)) |existing| {
            if (existing == slot) {
                position = i;
                break;
            }
        }
    }
    if (position >= 0) _ = reaper.TrackFX_Delete(track, position) else position = insertPosFor(globals, track, slot);
    const instantiate: c_int = if (position >= 0) -1000 - position else -1;
    const index = reaper.TrackFX_AddByName(track, fx_name, false, instantiate);
    if (index < 0) return false;
    setSlotSuffix(track, index, fx_name, slot);
    afterInsert(globals, track, index);
    return true;
}

// What the preferences ask of a plugin that the controller has just inserted: that it be bypassed, and that its window open.
fn afterInsert(globals: *MftGlobals, track: reaper.MediaTrack, fx_index: c_int) void {
    if (globals.preferences.auto_insert_bypassed) reaper.TrackFX_SetEnabled(track, fx_index, false);
    if (globals.preferences.show_plugin_ui) reaper.TrackFX_Show(track, fx_index, SHOW_FLOATING);
}

// Loads a channel strip onto the track: the strip that the track has is replaced by the new one, which takes its place, and a track that had none gets it at
// the end of its chain. Returns false when REAPER could not add it.
pub fn loadStrip(globals: *MftGlobals, track: reaper.MediaTrack, fx_name: [:0]const u8) bool {
    var position: c_int = -1;
    if (findStrip(track)) |existing| {
        position = existing;
        _ = reaper.TrackFX_Delete(track, existing);
    }
    const instantiate: c_int = if (position >= 0) -1000 - position else -1;
    const index = reaper.TrackFX_AddByName(track, fx_name, false, instantiate);
    if (index < 0) return false;
    setSlotSuffix(track, index, fx_name, .strip);
    afterInsert(globals, track, index);
    return true;
}

// Ensure each slot the module drives has a suffixed FX on the track. A missing
// slot is filled by adopting an existing un-suffixed instance of its default
// plugin if present, otherwise inserting a fresh one at the canonical position.
// Because the position comes from the slot rank rather than the selection order,
// selecting modules out of order still yields a correctly ordered chain.
/// What a module button inserted: what it should have, or, in the single FX mode, nothing because no channel strip is named in the settings, or because
/// REAPER could not add the one that is named.
pub const Ensured = enum { ok, no_default_strip, strip_not_added };

pub fn ensureModuleFx(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule) Ensured {
    // A channel strip does the work of every module, so a track that has one needs no other plugin.
    if (findStrip(track) != null) return .ok;
    // In the single FX mode, a track that has none of the plugins of the modules gets the default strip instead of them. Because the player chose that
    // mode, a strip that cannot be inserted inserts nothing else, and the caller says why.
    if (globals.preferences.single_fx_mode and !hasSuffixedFx(track)) {
        if (defaultPluginFor(globals, .strip).len == 0) return .no_default_strip;
        return if (insertDefaultStrip(globals, track)) .ok else .strip_not_added;
    }
    for (slotsFor(module)) |slot| {
        if (trackHasSlot(track, slot)) continue;
        const name = defaultPluginFor(globals, slot);

        if (findUnsuffixedFx(track, name)) |existing| {
            setSlotSuffix(track, existing, name, slot);
            continue;
        }

        const insert_pos = insertPosFor(globals, track, slot);
        const instantiate: c_int = if (insert_pos >= 0) -1000 - insert_pos else -1;
        const new_idx = reaper.TrackFX_AddByName(track, name, false, instantiate);
        if (new_idx < 0) continue;
        setSlotSuffix(track, new_idx, name, slot);
        afterInsert(globals, track, new_idx);
    }
    return .ok;
}

// Build the routing of a module's sixteen encoders from the suffixed FX on the track.
// Every FX whose suffix names the module's slot contributes the knob
// slots its map defines; the first FX to define a knob wins.
pub fn resolveModule(globals: *MftGlobals, track: reaper.MediaTrack, module: MappableModule) SlotRouting {
    const io = mft_globals.hostIo();
    var routing = SlotRouting{};
    // A channel strip has one map for all the pages, and takes every module.
    if (findStrip(track)) |strip_fx| {
        var strip_name_buf: [512:0]u8 = undefined;
        const base = fxBaseName(track, strip_fx, &strip_name_buf) orelse return routing;
        const strip = globals.map_store.getStrip(io, base) orelse return routing;
        const wet = reaper.TrackFX_GetParamFromIdent(track, strip_fx, ":wet");
        routing.merge(strip_fx, strip.pageFor(module).withWet(if (wet >= 0) @intCast(wet) else null));
        return routing;
    }
    const slots = slotsFor(module);
    const count = reaper.TrackFX_GetCount(track);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const slot = fxSlot(track, i) orelse continue;
        if (!slotsContain(slots, slot)) continue;
        var name_buf: [512:0]u8 = undefined;
        const base = fxBaseName(track, i, &name_buf) orelse continue;
        const mapping = globals.map_store.get(io, module, base) orelse continue;
        // The dry/wet parameter has a different number in each FX, so REAPER is asked for the one of this FX.
        const wet = reaper.TrackFX_GetParamFromIdent(track, i, ":wet");
        routing.merge(i, mapping.withWet(if (wet >= 0) @intCast(wet) else null));
    }
    return routing;
}

// The number that ReaEQ stores for a band is named BANDTYPE followed by the band, counted from 0.
fn bandTypeKey(buf: *[16:0]u8, band: u2) [:0]const u8 {
    return std.mem.printSentinel(buf, "BANDTYPE{d}", .{band}, 0) catch unreachable;
}

/// Does what a click on a push asks: steps a parameter, or the shape of a band of the EQ. The text that says what it changed (the new shape,
/// or the new value as the plugin writes it) goes into `note`, which is left empty when nothing changed.
pub fn runPush(track: reaper.MediaTrack, route: PushRoute, note: *[32:0]u8) void {
    note[0] = 0;
    switch (route.action) {
        .param => |param| {
            var stepping = mft_push.Stepping{};
            var step: f64 = 0;
            var small: f64 = 0;
            var large: f64 = 0;
            var toggle = false;
            if (reaper.TrackFX_GetParameterStepSizes(track, route.fx_index, param, &step, &small, &large, &toggle)) {
                stepping = .{ .step = step, .toggle = toggle };
            }
            const current = reaper.TrackFX_GetParamNormalized(track, route.fx_index, param);
            if (std.math.isNan(current) or current < 0) return;
            _ = reaper.TrackFX_SetParamNormalized(track, route.fx_index, param, mft_push.nextParamValue(current, stepping));
            // The plugin writes its own text for the new value, which is the percentage when it has none.
            if (!reaper.TrackFX_GetFormattedParamValue(track, route.fx_index, param, note, note.len + 1) or note[0] == 0) {
                const now = reaper.TrackFX_GetParamNormalized(track, route.fx_index, param);
                _ = std.mem.printSentinel(note, "{d:.0}%", .{now * 100.0}, 0) catch {};
            }
        },
        .band => |band| {
            var key_buf: [16:0]u8 = undefined;
            const key = bandTypeKey(&key_buf, band);
            var value_buf: [16:0]u8 = undefined;
            if (!reaper.TrackFX_GetNamedConfigParm(track, route.fx_index, key, &value_buf, value_buf.len)) return;
            const current = std.fmt.parseInt(u8, std.mem.sliceTo(&value_buf, 0), 10) catch return;
            var next_buf: [16:0]u8 = undefined;
            const next = std.mem.printSentinel(&next_buf, "{d}", .{mft_push.nextBandType(current)}, 0) catch return;
            if (reaper.TrackFX_SetNamedConfigParm(track, route.fx_index, key, next)) {
                _ = std.mem.printSentinel(note, "{s}", .{mft_push.bandTypeName(mft_push.nextBandType(current))}, 0) catch {};
            }
        },
    }
}

test "SlotRouting.merge: the pushes of the first FX that claims them win" {
    const t = std.testing;
    var first = mappings.MftModuleMapping{};
    first.setPush(0, .{ .band = 1 });
    var second = mappings.MftModuleMapping{};
    second.setPush(0, .{ .param = 3 });
    second.setPush(2, .{ .param = 4 });
    var routing = SlotRouting{};
    routing.merge(1, first);
    routing.merge(2, second);
    try t.expectEqual(@as(?PushRoute, .{ .fx_index = 1, .action = .{ .band = 1 } }), routing.pushes[0]);
    try t.expectEqual(@as(?PushRoute, .{ .fx_index = 2, .action = .{ .param = 4 } }), routing.pushes[2]);
    try t.expectEqual(@as(?PushRoute, null), routing.pushes[1]);
}

test "parseSlot: reads the C1 suffix char" {
    const t = std.testing;
    try t.expectEqual(@as(?ModuleSlot, .input), parseSlot("JS: Vol (C1-I)"));
    try t.expectEqual(@as(?ModuleSlot, .eq), parseSlot("VST: ReaEQ (Cockos) (C1-E)"));
    try t.expectEqual(@as(?ModuleSlot, .output), parseSlot("JS: Saturation (C1-O)"));
    try t.expectEqual(@as(?ModuleSlot, null), parseSlot("VST: ReaEQ (Cockos)"));
    try t.expectEqual(@as(?ModuleSlot, null), parseSlot("Plugin (C1-"));
    // A channel strip has the suffix X, and is not one of the module slots.
    try t.expectEqual(@as(?ModuleSlot, .strip), parseSlot("JS: Lumina Channel Strip (C1-X)"));
    try t.expectEqual(@as(u8, 'X'), ModuleSlot.strip.suffixChar());
}

test "ModuleSlot: canonical rank order" {
    const t = std.testing;
    try t.expect(ModuleSlot.input.rank() < ModuleSlot.gate.rank());
    try t.expect(ModuleSlot.gate.rank() < ModuleSlot.eq.rank());
    try t.expect(ModuleSlot.eq.rank() < ModuleSlot.comp.rank());
    try t.expect(ModuleSlot.comp.rank() < ModuleSlot.output.rank());
}

test "SlotRouting.merge: two plugins on one page combine without collision" {
    const t = std.testing;
    // Two plugins of one page, one on knobs 1-3 and the other on knobs 5-6.
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

test "the chain key hides a visible chain, focused or not, and shows a hidden one" {
    try std.testing.expectEqual(@as(c_int, 1), chainShowFlag(CHAIN_HIDDEN));
    // The chain is visible with an effect selected, or with none selected.
    try std.testing.expectEqual(@as(c_int, 0), chainShowFlag(0));
    try std.testing.expectEqual(@as(c_int, 0), chainShowFlag(3));
    try std.testing.expectEqual(@as(c_int, 0), chainShowFlag(-2));
}

test "ModuleSlot.rankIn: the modules follow the order, between the input and the output" {
    const t = std.testing;
    try t.expect(ModuleSlot.eq.rankIn(.eq_s_c) < ModuleSlot.gate.rankIn(.eq_s_c));
    try t.expect(ModuleSlot.gate.rankIn(.s_c_eq) < ModuleSlot.comp.rankIn(.s_c_eq));
    try t.expect(ModuleSlot.comp.rankIn(.s_c_eq) < ModuleSlot.eq.rankIn(.s_c_eq));
    try t.expect(ModuleSlot.input.rankIn(.eq_s_c) < ModuleSlot.eq.rankIn(.eq_s_c));
    try t.expect(ModuleSlot.comp.rankIn(.s_eq_c) < ModuleSlot.output.rankIn(.s_eq_c));
    try t.expectEqual(@as(?mft_order.Dyn, null), ModuleSlot.input.dyn());
}
