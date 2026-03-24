const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const constants = @import("constants.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.fx_sel_actions);
const TrackState = @import("track_state.zig");
const Globals = @import("globals.zig").Globals;
const utils = @import("utils.zig");
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;

pub const FxSelActions = @import("action_types.zig").FxSelActions;

pub fn fxSelActions(globals: *Globals, sel_action: FxSelActions) void {
    switch (sel_action) {
        .fx_chain => |fx| {
            const track = reaper.GetSelectedTrack(@as(c_int, 0), @as(c_int, 0));
            if (track) |tr| {
                _ = reaper.TrackFX_AddByName(
                    tr,
                    @as([*:0]const u8, @ptrCast(fx.path)),
                    false,
                    -1000 - reaper.TrackFX_GetCount(tr),
                );
            }
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
        .track_template => |template| {
            reaper.Main_openProject(template.path);
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
        .plugin => |plugin| {
            if (globals.state.current_tr_id == null) {
                dispatch(globals, .{ .change_mode = .fx_ctrl });
                return;
            }
            const current_module = globals.state.fx_sel.current_category;

            if (current_module == .STRIP) {
                handleStripPlugin(globals, plugin.name, plugin.mapping_name);
                return;
            }

            const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id.?, constants.g_csurf_mcpmode);
            const track_state = &globals.state.fx_ctrl.track_state;

            // If the track is in channel strip mode, we revert to multi-fx by
            // removing the channel strip FX first. Auto-insertion will fill
            // the missing modules after validateTrack runs.
            switch (track_state.mode) {
                .channel_strip => |strip| {
                    _ = pReaper.TrackFX_Delete(.{ track, strip.fx_index });
                    // Reset to multi_fx so determineInsertionIndex works correctly
                    track_state.mode = .{ .multi_fx = TrackState.ModuleLocations.initFill(null) };
                },
                .multi_fx => {},
            }

            const phys_module: PhysicalModule = @enumFromInt(@intFromEnum(current_module));
            const insert_idx = determineInsertionIndex(&globals.state, track, phys_module, globals.preferences.preferred_module_order);

            // Check if we need to load a specific mapping or determine if mapping exists
            var needs_mapping = false;
            if (plugin.mapping_name) |map_name| {
                // Load specific mapping (don't change preferred setting)
                _ = globals.map_store.getMap(plugin.name, current_module, map_name, &globals.mappings_list) catch |err| {
                    log.err("Failed to load mapping {s} for {s}: {}", .{ map_name, plugin.name, err });
                    needs_mapping = true;
                };
            } else {
                // Check if any mapping exists for this FX
                needs_mapping = (globals.map_store.get(plugin.name, current_module, &globals.mappings_list) == null);
            }

            // Add new FX
            const new_fx_index = pReaper.TrackFX_AddByName(.{ track, plugin.name, false, insert_idx });
            if (new_fx_index < 0) {
                log.err("Failed to add new FX: {s}", .{plugin.name});
                dispatch(globals, .{ .change_mode = .fx_ctrl });
                return;
            }

            // Append C1 suffix
            {
                const module_char = current_module.toModulePrefix();
                var name_buf: [512:0]u8 = undefined;
                const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-{s})", .{ plugin.name, module_char }) catch {
                    log.err("Failed to format FX name with suffix", .{});
                    _ = pReaper.TrackFX_Delete(.{ track, new_fx_index });
                    dispatch(globals, .{ .change_mode = .fx_ctrl });
                    return;
                };
                _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, new_fx_index, "renamed_name", new_name });
            }

            // If replacing existing module FX, remove it.
            // Because the new FX may have been inserted before or after the old one,
            // we need to check whether the old FX's index shifted due to the insertion.
            const old_loc_opt = switch (current_module) {
                .STRIP => null,
                inline else => |phys| switch (track_state.mode) {
                    .multi_fx => |locs| locs.get(@as(PhysicalModule, @enumFromInt(@intFromEnum(phys)))),
                    .channel_strip => null,
                },
            };
            if (old_loc_opt) |old_loc| {
                const delete_idx = if (new_fx_index <= old_loc.fx_index)
                    old_loc.fx_index + 1
                else
                    old_loc.fx_index;
                if (!pReaper.TrackFX_Delete(.{ track, delete_idx })) {
                    var buf: [512:0]u8 = undefined;
                    const fx_name = if (reaper.TrackFX_GetNamedConfigParm(track, delete_idx, "original_name", &buf, buf.len))
                        std.mem.span(@as([*:0]const u8, &buf))
                    else
                        "unknown";
                    log.err("Failed to remove old FX: {s}", .{fx_name});
                }
            }

            // Because validateTrack needs to be called after adding the FX, we call it here
            _ = track_state.validateTrack(
                track,
                globals.preferences.default_fx,
                &globals.map_store,
                globals.preferences,
                globals.arena,
                &globals.mappings_list,
            );
            track_state.getLabels(track);

            // Because FX parameter loading now happens in enter_assign action,
            // we enter mapping mode if needed, otherwise return to fx_ctrl
            if (needs_mapping) {
                dispatch(globals, .{ .change_mode = .mapping_panel });
            } else {
                dispatch(globals, .{ .change_mode = .fx_ctrl });
            }
        },
        .close_browser => {
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
        .rescan => {
            const fxp = @import("fx_parser.zig");
            fxp.deinit(globals.arena);
            fxp.init(globals.arena) catch {};
        },
        .toggle_module_browser => |module| {
            if (globals.state.current_mode == .fx_sel and module == globals.state.fx_sel.current_category) {
                dispatch(globals, .{ .change_mode = .fx_ctrl });
            } else {
                globals.state.fx_sel.scroll_position_abs = 0;
                globals.state.fx_sel.scroll_position_rel = 0;
                globals.state.fx_sel.sub_mode = .browse_fx;
                globals.state.fx_sel.current_category = module;
                dispatch(globals, .{ .change_mode = .fx_sel });
            }
        },
        .confirm => {
            const category = globals.state.fx_sel.current_category;
            const mappings = globals.mappings_list.list.get(category);

            switch (globals.state.fx_sel.sub_mode) {
                .browse_fx => {
                    if (mappings.count() == 0) return;
                    const fx_offset = mappings.keys()[globals.state.fx_sel.scroll_position_rel];
                    const mapping_offsets = mappings.get(fx_offset) orelse return;
                    const fx_name = globals.mappings_list.strings.get(fx_offset);

                    if (mapping_offsets.items.len == 1) {
                        const mapping_name = globals.mappings_list.strings.get(mapping_offsets.items[0].name_offset);
                        fxSelActions(globals, .{ .plugin = .{ .name = fx_name, .mapping_name = mapping_name } });
                    } else {
                        globals.state.fx_sel.sub_mode = .{ .select_mapping = .{
                            .fx_name = fx_name,
                            .fx_string_pool_offset = fx_offset,
                        } };
                    }
                },
                .select_mapping => |sel| {
                    const mapping_offsets = mappings.get(sel.fx_string_pool_offset) orelse return;
                    if (sel.scroll_position_rel >= mapping_offsets.items.len) return;
                    const mapping_name = globals.mappings_list.strings.get(mapping_offsets.items[sel.scroll_position_rel].name_offset);
                    fxSelActions(globals, .{ .plugin = .{ .name = sel.fx_name, .mapping_name = mapping_name } });
                },
            }
        },
        .back => {
            globals.state.fx_sel.sub_mode = .browse_fx;
        },
        .scroll => |new_pos| {
            globals.state.fx_sel.scroll_changed = true;
            const scroll_mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
            switch (globals.state.fx_sel.sub_mode) {
                .browse_fx => {
                    _ = utils.calculateNewScrollPosition(
                        i32,
                        &globals.state.fx_sel.scroll_position_abs,
                        &globals.state.fx_sel.scroll_position_rel,
                        new_pos,
                        @intCast(scroll_mappings.count()),
                        1,
                    );
                },
                .select_mapping => |*sel| {
                    const mapping_offsets = scroll_mappings.get(sel.fx_string_pool_offset) orelse return;
                    _ = utils.calculateNewScrollPosition(
                        i32,
                        &sel.scroll_position_abs,
                        &sel.scroll_position_rel,
                        new_pos,
                        @intCast(mapping_offsets.items.len),
                        1,
                    );
                },
            }
        },
        .select_fx => {},
    }
}

fn handleStripPlugin(globals: *Globals, name: [:0]const u8, mapping_name: ?[:0]const u8) void {
    const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id.?, constants.g_csurf_mcpmode);
    const track_state = &globals.state.fx_ctrl.track_state;

    // When switching from multi-fx to channel strip, we must remove the
    // existing module FX first. Otherwise they remain on the track as
    // duplicates alongside the new strip FX.
    switch (track_state.mode) {
        .multi_fx => |locs| {
            // Collect indices and delete in descending order so that
            // earlier deletions don't shift the indices of later ones.
            var indices: [5]?i32 = .{ null, null, null, null, null };
            inline for (comptime std.enums.values(PhysicalModule), 0..) |module, i| {
                if (locs.get(module)) |loc| {
                    indices[i] = loc.fx_index;
                }
            }
            std.mem.sort(?i32, &indices, {}, struct {
                fn f(_: void, a: ?i32, b: ?i32) bool {
                    // Because nulls should sort last, we treat them as
                    // less-than any value so they end up at the tail.
                    return (a orelse return false) > (b orelse return true);
                }
            }.f);
            for (indices) |maybe_idx| {
                const idx = maybe_idx orelse break;
                _ = pReaper.TrackFX_Delete(.{ track, idx });
            }
            track_state.mode = .{ .multi_fx = TrackState.ModuleLocations.initFill(null) };
        },
        .channel_strip => |strip| {
            _ = pReaper.TrackFX_Delete(.{ track, strip.fx_index });
        },
    }

    const new_fx_index = pReaper.TrackFX_AddByName(.{ track, name, false, -1000 - reaper.TrackFX_GetCount(track) });
    if (new_fx_index < 0) {
        log.err("Failed to add channel strip FX: {s}", .{name});
        dispatch(globals, .{ .change_mode = .fx_ctrl });
        return;
    }

    {
        var name_buf: [512:0]u8 = undefined;
        const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-X)", .{name}) catch {
            _ = pReaper.TrackFX_Delete(.{ track, new_fx_index });
            dispatch(globals, .{ .change_mode = .fx_ctrl });
            return;
        };
        _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, new_fx_index, "renamed_name", new_name });
    }

    _ = track_state.validateTrack(track, globals.preferences.default_fx, &globals.map_store, globals.preferences, globals.arena, &globals.mappings_list);
    track_state.getLabels(track);

    if (mapping_name) |map_name| {
        _ = globals.map_store.getMap(name, .STRIP, map_name, &globals.mappings_list) catch {};
    }

    const needs_mapping = (globals.map_store.get(name, .STRIP, &globals.mappings_list) == null);
    if (needs_mapping) {
        dispatch(globals, .{ .change_mode = .mapping_panel });
    } else {
        dispatch(globals, .{ .change_mode = .fx_ctrl });
    }
}

fn countModuleLocations(track_state: *const TrackState) usize {
    const locs = switch (track_state.mode) {
        .multi_fx => |l| l,
        .channel_strip => return 0,
    };
    var count: usize = 0;
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        if (locs.get(module) != null) {
            count += 1;
        }
    }
    return count;
}

// Because the insertion position depends on the user's preferred module
// order, we build the full 5-module sequence and find the first existing
// module that comes after the target in that sequence. We insert before
// that successor. If no successor exists, we insert after the last
// existing module (or at the end of the FX chain if nothing exists).
fn determineInsertionIndex(state: *State, track: reaper.MediaTrack, module: PhysicalModule, order: ModulesOrder) i32 {
    const track_state = &state.fx_ctrl.track_state;

    if (countModuleLocations(track_state) == 0) {
        return -1000 - reaper.TrackFX_GetCount(track);
    }

    const full_order = getFullModuleOrder(order);

    const locs = track_state.getModuleLocations() orelse return -1000 - reaper.TrackFX_GetCount(track);

    // Find the target module's position in the canonical sequence
    var target_pos: usize = 0;
    for (full_order, 0..) |m, i| {
        if (m == module) {
            target_pos = i;
            break;
        }
    }

    // Because we want to maintain the preferred order, we look for the
    // first existing module that comes after the target in the sequence
    // and insert before it.
    for (full_order[target_pos + 1 ..]) |successor| {
        if (locs.get(successor)) |loc| {
            return -1000 - loc.fx_index;
        }
    }

    // Because no successor module exists, we insert after the last
    // existing module in the chain.
    if (track_state.getLastModuleIndex()) |last_idx| {
        return -1000 - (last_idx + 1);
    }

    return -1000 - reaper.TrackFX_GetCount(track);
}

fn getFullModuleOrder(order: ModulesOrder) [5]PhysicalModule {
    return switch (order) {
        .@"S-EQ-C" => .{ .INPUT, .GATE, .EQ, .COMP, .OUTPT },
        .@"S-C-EQ" => .{ .INPUT, .GATE, .COMP, .EQ, .OUTPT },
        .@"EQ-S-C" => .{ .INPUT, .EQ, .GATE, .COMP, .OUTPT },
    };
}
