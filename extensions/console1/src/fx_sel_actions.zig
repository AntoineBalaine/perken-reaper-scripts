const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const ModulesList = statemachine.ModulesList;
const constants = @import("constants.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.fx_sel_actions);
const TrackState = @import("track_state.zig").TrackState;
const Globals = @import("globals.zig").Globals;

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
            const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id.?, constants.g_csurf_mcpmode);
            const current_module = globals.state.fx_sel.current_category;
            const track_state = &globals.state.fx_ctrl.track_state;

            // Use existing determineInsertionIndex function
            const insert_idx = determineInsertionIndex(&globals.state, track, current_module);

            // Check if we need to load a specific mapping or determine if mapping exists
            var needs_mapping = false;
            if (plugin.mapping_name) |map_name| {
                // Load specific mapping (don't change preferred setting)
                _ = globals.map_store.getMap(plugin.name, current_module, map_name) catch |err| {
                    log.err("Failed to load mapping {s} for {s}: {}", .{ map_name, plugin.name, err });
                    needs_mapping = true;
                };
            } else {
                // Check if any mapping exists for this FX
                needs_mapping = (globals.map_store.get(plugin.name, current_module) == null);
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
            if (track_state.module_locations.get(current_module)) |old_loc| {
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
            _ = track_state.validateTrack(track, globals.preferences.default_fx, &globals.map_store, globals.preferences);

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
        .toggle_module_browser => |module| {
            if (globals.state.current_mode == .fx_sel and module == globals.state.fx_sel.current_category) {
                dispatch(globals, .{ .change_mode = .fx_ctrl });
            } else {
                globals.state.fx_sel.scroll_position_abs = 0;
                globals.state.fx_sel.scroll_position_rel = 0;
                globals.state.fx_sel.current_category = module;
                dispatch(globals, .{ .change_mode = .fx_sel });
            }
        },
        .scroll => |new_pos| {
            const fx_count: i32 = @intCast(switch (globals.state.fx_sel.current_category) {
                inline else => |impl| globals.mappings_list.list.get(impl).count(),
            });

            if (@import("utils.zig").calculateNewScrollPosition(
                i32,
                &globals.state.fx_sel.scroll_position_abs,
                &globals.state.fx_sel.scroll_position_rel,
                new_pos,
                @intCast(fx_count),
                1,
            )) |delta| {
                log.debug("FxSel scroll: abs={d} delta={d} rel={d}/{d}", .{
                    globals.state.fx_sel.scroll_position_abs,
                    delta,
                    globals.state.fx_sel.scroll_position_rel,
                    fx_count,
                });
            }
        },
        else => {},
    }
}

fn countModuleLocations(track_state: *const TrackState) usize {
    var count: usize = 0;
    inline for (comptime std.enums.values(ModulesList)) |module| {
        if (track_state.module_locations.get(module) != null) {
            count += 1;
        }
    }
    return count;
}

fn determineInsertionIndex(state: *State, track: reaper.MediaTrack, module: ModulesList) i32 {
    const track_state = &state.fx_ctrl.track_state;

    // If no modules exist, add at end
    if (countModuleLocations(track_state) == 0) {
        return -1000 - reaper.TrackFX_GetCount(track);
    }

    // For each module type, determine correct position based on other modules
    return switch (module) {
        .INPUT => if (track_state.getFirstModuleIndex()) |first_idx|
            -1000 - first_idx
        else
            -1000 - reaper.TrackFX_GetCount(track),

        .GATE => if (track_state.module_locations.get(.COMP)) |comp_loc|
            -1000 - comp_loc.fx_index
        else if (track_state.getLastModuleIndex()) |last_idx|
            -1000 - last_idx
        else
            -1000 - reaper.TrackFX_GetCount(track),

        .EQ => if (track_state.module_locations.get(.INPUT)) |input_loc|
            -1000 - (input_loc.fx_index + 1)
        else if (track_state.getFirstModuleIndex()) |first_idx|
            -1000 - first_idx
        else
            -1000 - reaper.TrackFX_GetCount(track),

        .COMP => if (track_state.module_locations.get(.GATE)) |gate_loc|
            -1000 - (gate_loc.fx_index + 1)
        else if (track_state.module_locations.get(.EQ)) |eq_loc|
            -1000 - (eq_loc.fx_index + 1)
        else if (track_state.getLastModuleIndex()) |last_idx|
            -1000 - last_idx
        else
            -1000 - reaper.TrackFX_GetCount(track),

        .OUTPT => if (track_state.getLastModuleIndex()) |last_idx|
            -1000 - (last_idx + 1)
        else
            -1000 - reaper.TrackFX_GetCount(track),
    };
}
