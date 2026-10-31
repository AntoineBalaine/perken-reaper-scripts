//! The screen that loads and saves the presets of the FX of the modules. It has four stages: the modules with their
//! FX, then the presets of the chosen FX (to load one) or a name to save under, and a question when that name is taken.
//! The unit drives it as it drives the browsers: Volume scrolls, Solo confirms and Mute cancels.
const std = @import("std");
const reaper = @import("reaper").reaper;
const utils = @import("utils");
const Globals = @import("globals.zig").Globals;
const statemachine = @import("statemachine.zig");
const PresetsState = statemachine.PresetsState;
const PresetsRow = statemachine.PresetsRow;
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const actions = @import("actions.zig");
const constants = @import("constants.zig");
const fx_presets = @import("fx_presets.zig");
const preset_store = @import("preset_store.zig");
const step = @import("unit/step.zig");
const log = std.log.scoped(.presets);

pub const PresetsAction = @import("action_types.zig").PresetsAction;

pub fn presetsActions(globals: *Globals, action: PresetsAction) void {
    switch (action) {
        .enter => |purpose| enter(globals, purpose),
        .scroll => |new_pos| {
            // Because the legacy knob reports a position, the direction comes from where it was.
            const state = &globals.state.presets;
            const delta = utils.calculateDelta(i32, state.scroll_position_abs, new_pos);
            state.scroll_position_abs = new_pos;
            if (delta != 0) scrollBy(globals, if (delta > 0) 1 else -1);
        },
        .scroll_by => |delta| scrollBy(globals, delta),
        .pick => |index| {
            const state = &globals.state.presets;
            switch (state.stage) {
                .modules => {
                    if (index >= state.rows.len or state.rows[index].fx_index == null) return;
                    state.module_cursor = index;
                },
                .presets => {
                    if (index >= state.names.len) return;
                    state.preset_cursor = index;
                },
                else => return,
            }
            confirm(globals);
        },
        .confirm => confirm(globals),
        .cancel => cancel(globals),
    }
}

fn currentTrack(globals: *Globals) ?reaper.MediaTrack {
    const id = globals.state.current_tr_id orelse return null;
    return reaper.CSurf_TrackFromID(id, constants.g_csurf_mcpmode);
}

fn physicalOf(module: ModulesList) ?PhysicalModule {
    return switch (module) {
        .INPUT => .INPUT,
        .GATE => .GATE,
        .EQ => .EQ,
        .COMP => .COMP,
        .OUTPT => .OUTPT,
        .STRIP => null,
    };
}

fn fxName(allocator: std.mem.Allocator, track: reaper.MediaTrack, fx_index: c_int) ![:0]const u8 {
    var buffer: [256:0]u8 = undefined;
    buffer[0] = 0;
    if (!reaper.TrackFX_GetFXName(track, fx_index, &buffer, buffer.len)) return "";
    return allocator.dupeSentinel(u8, std.mem.sliceTo(&buffer, 0), 0);
}

/// The modules of the track with the FX that each one has: the five modules, or the strip when the track has one.
fn buildRows(globals: *Globals, track: reaper.MediaTrack) ![]const PresetsRow {
    const allocator = globals.state.presets.arena.allocator();
    var rows: std.ArrayList(PresetsRow) = .empty;
    switch (globals.state.fx_ctrl.track_state.mode) {
        .multi_fx => |locations| {
            inline for (comptime std.enums.values(ModulesList)) |module| {
                if (comptime physicalOf(module)) |physical| {
                    const location = locations.get(physical);
                    try rows.append(allocator, .{
                        .module = module,
                        .fx_index = if (location) |loc| loc.fx_index else null,
                        .fx_name = if (location) |loc| try fxName(allocator, track, loc.fx_index) else "",
                    });
                }
            }
        },
        .channel_strip => |strip| try rows.append(allocator, .{
            .module = .STRIP,
            .fx_index = strip.fx_index,
            .fx_name = try fxName(allocator, track, strip.fx_index),
        }),
    }
    return rows.toOwnedSlice(allocator);
}

fn enter(globals: *Globals, purpose: statemachine.PresetsPurpose) void {
    if (globals.state.current_mode != .fx_ctrl) return;
    const track = currentTrack(globals) orelse return;
    const state = &globals.state.presets;
    state.reset(purpose);
    state.rows = buildRows(globals, track) catch {
        log.err("could not list the modules of the track", .{});
        return;
    };
    // The cursor starts on the first module that has an FX.
    for (state.rows, 0..) |row, i| {
        if (row.fx_index != null) {
            state.module_cursor = i;
            break;
        }
    }
    state.scroll_changed = true;
    actions.dispatch(globals, .{ .change_mode = .presets });
}

/// Moves the cursor of the stage by a row, wrapping around, and skipping the modules that have no FX.
fn scrollBy(globals: *Globals, delta: i8) void {
    const state = &globals.state.presets;
    switch (state.stage) {
        .modules => {
            if (state.rows.len == 0) return;
            var tries: usize = 0;
            while (tries < state.rows.len) : (tries += 1) {
                step.wrap(&state.module_cursor, delta, state.rows.len);
                if (state.rows[state.module_cursor].fx_index != null) break;
            }
        },
        .presets => step.wrap(&state.preset_cursor, delta, state.names.len),
        .name, .overwrite => return,
    }
    state.scroll_changed = true;
}

fn confirm(globals: *Globals) void {
    const state = &globals.state.presets;
    const track = currentTrack(globals) orelse return;
    state.message = .none;
    switch (state.stage) {
        .modules => {
            if (state.module_cursor >= state.rows.len) return;
            const fx_index = state.rows[state.module_cursor].fx_index orelse return;
            state.fx_index = fx_index;
            switch (state.purpose) {
                .load => {
                    const names = fx_presets.listNames(state.arena.allocator(), Globals.hostIo(), track, fx_index) catch &.{};
                    if (names.len == 0) {
                        state.message = .no_presets;
                        return;
                    }
                    state.names = names;
                    state.preset_cursor = 0;
                    state.stage = .presets;
                    state.scroll_changed = true;
                },
                .save => {
                    // The name of the preset that the FX shows is the one to start from.
                    var buffer: [256:0]u8 = undefined;
                    state.name_buffer = @splat(0);
                    if (fx_presets.currentName(track, fx_index, &buffer)) |current| {
                        const length = @min(current.len, state.name_buffer.len - 1);
                        @memcpy(state.name_buffer[0..length], current[0..length]);
                    }
                    state.stage = .name;
                    state.scroll_changed = true;
                },
            }
        },
        .presets => {
            if (state.preset_cursor >= state.names.len) return;
            if (!fx_presets.load(track, state.fx_index, state.names[state.preset_cursor])) {
                log.warn("REAPER did not load the preset '{s}'", .{state.names[state.preset_cursor]});
                return;
            }
            finish(globals, track);
        },
        .name => {
            const name = std.mem.trim(u8, state.nameSlice(), " \t");
            if (name.len == 0) return;
            const names = fx_presets.listNames(state.arena.allocator(), Globals.hostIo(), track, state.fx_index) catch &.{};
            for (names) |existing| {
                if (std.mem.eql(u8, existing, name)) {
                    state.stage = .overwrite;
                    return;
                }
            }
            save(globals, track);
        },
        .overwrite => save(globals, track),
    }
}

fn save(globals: *Globals, track: reaper.MediaTrack) void {
    const state = &globals.state.presets;
    const name_text = std.mem.trim(u8, state.nameSlice(), " \t");
    var name_buffer: [256:0]u8 = undefined;
    @memcpy(name_buffer[0..name_text.len], name_text);
    name_buffer[name_text.len] = 0;
    const name: [:0]const u8 = name_buffer[0..name_text.len :0];
    fx_presets.save(std.heap.page_allocator, Globals.hostIo(), track, state.fx_index, name) catch |err| {
        log.warn("could not save the preset '{s}': {s}", .{ name, @errorName(err) });
        state.message = if (err == error.UnsupportedFx) .unsupported_fx else .save_failed;
        state.stage = .name;
        return;
    };
    finish(globals, track);
}

/// Back to the controls, with what the FX shows read again.
fn finish(globals: *Globals, track: reaper.MediaTrack) void {
    actions.dispatch(globals, .{ .change_mode = .fx_ctrl });
    actions.dispatch(globals, .{ .fx_ctrl = .{ .on_track_entry = track } });
}

fn cancel(globals: *Globals) void {
    const state = &globals.state.presets;
    state.message = .none;
    switch (state.stage) {
        .modules => actions.dispatch(globals, .{ .change_mode = .fx_ctrl }),
        .presets, .name => {
            state.stage = .modules;
            state.scroll_changed = true;
        },
        .overwrite => state.stage = .name,
    }
}

test {
    std.testing.refAllDecls(@This());
}
