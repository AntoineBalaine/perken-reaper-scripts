const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const SCRouting = fx_ctrl_state.SCRouting;
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const SettingsPanel = @import("settings_panel.zig");
const mappings = @import("mappings.zig");
const MappingPanel = @import("mapping_panel.zig").MappingPanel;
const ModulesList = statemachine.ModulesList;
const constants = @import("constants.zig");
const MappingAction = @import("mapping_actions.zig").MappingAction;
const mappingActions = @import("mapping_actions.zig").mappingActions;
const settings_actions = @import("settings_actions.zig");
const SettingsActions = settings_actions.SettingsActions;
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.fx_sel_actions);

pub const FxSelActions = union(enum) {
    select_fx: [:0]const u8,
    scroll: u8,
    toggle_module_browser: ModulesList, // Which module's browser to show
    fx_chain: struct {
        path: []const u8,
    },
    track_template: struct {
        path: [:0]const u8,
    },
    plugin: struct {
        name: [:0]const u8,
    },
    close_browser: void,
};

pub fn fxSelActions(state: *State, sel_action: FxSelActions) void {
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
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .track_template => |template| {
            reaper.Main_openProject(template.path);
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .plugin => |plugin| {
            if (state.current_tr_id == null) dispatch(state, .{ .change_mode = .fx_ctrl });
            const track = reaper.CSurf_TrackFromID(state.current_tr_id.?, constants.g_csurf_mcpmode);

            const current_module = state.fx_sel.current_category;
            if (state.fx_ctrl.track_state.module_locations.get(current_module)) |module_loc| {
                const current_fx_index = module_loc.fx_index;

                // Add new FX at same position
                const new_fx_index = pReaper.TrackFX_AddByName(.{ track, plugin.name, false, -1000 - current_fx_index });

                if (new_fx_index >= 0) {
                    { // append C1 suffix
                        const module_char = current_module.toModulePrefixChar();
                        var name_buf: [512:0]u8 = undefined;
                        const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-{s})", .{ plugin.name, module_char }) catch {
                            log.err("Failed to format FX name with suffix", .{});
                            _ = pReaper.TrackFX_Delete(.{ track, current_fx_index }); // Undo insertion.
                            return;
                        };
                        _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, new_fx_index, "renamed_name", new_name });
                    }

                    // Remove old FX (index has shifted by +1 due to insertion)
                    if (!pReaper.TrackFX_Delete(.{ track, current_fx_index + 1 })) {
                        var buf: [512:0]u8 = undefined;
                        const fx_name = if (reaper.TrackFX_GetNamedConfigParm(track, current_fx_index + 1, "original_name", &buf, buf.len))
                            std.mem.span(@as([*:0]const u8, &buf))
                        else
                            "unknown";
                        log.err("Failed to remove old FX: {s}", .{fx_name});
                    }

                    // Validate track to update module locations - will consolidate if needed
                    state.fx_ctrl.track_state.validateTrack(track);
                } else {
                    log.err("Failed to add new FX: {s} at position {d}", .{ plugin.name, current_fx_index });
                }
            } else {
                log.err("No FX found for module {s}", .{@tagName(current_module)});
            }
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .close_browser => {
            dispatch(state, .{ .change_mode = .fx_ctrl });
        },
        .toggle_module_browser => |module| {
            if (state.current_mode == .fx_sel and module == state.fx_sel.current_category) {
                dispatch(state, .{ .change_mode = .fx_ctrl });
            } else {
                state.fx_sel.current_category = module;
                dispatch(state, .{ .change_mode = .fx_sel });
            }
        },
        // .select_category_fx => |selection| {
        //     if (!hasMappingFor(selection.module, selection.fx_name)) {
        //         state.mapping.target_fx = selection.fx_name;
        //         state.mapping.current_mappings = switch (selection.module) {
        //             .COMP => .{ .COMP = mappings.Comp{} },
        //             .EQ => .{ .EQ = mappings.Eq{} },
        //             .GATE => .{ .GATE = mappings.Shp{} },
        //             .OUTPT => .{ .OUTPT = mappings.Outpt{} },
        //             .INPUT => .{ .INPUT = mappings.Inpt{} },
        //         };
        //         dispatch(state, .{ .change_mode = .mapping_panel });
        //     } else {
        //         try loadModuleMapping(selection.module, selection.fx_name);
        //         try updateTrackFx(selection.module, selection.fx_name);
        //         dispatch(state, .{ .change_mode = .fx_ctrl });
        //     }
        // },
        .select_fx => |fx_name| {
            // Check if mapping exists
            if (globals.map_store.get(fx_name, state.fx_sel.current_category) == null) {
                createEmptyMapping(state, fx_name) catch return;
                // Open mapping panel
                switch (state.fx_sel.current_category) {
                    inline else => |variant| {
                        const fxMap = state.fx_ctrl.track_state.module_locations.get(variant);

                        if (fxMap) |map| {
                            if (state.current_tr_id) |tr_id| {
                                enterMappingMode(tr_id, map.fx_index) catch {};
                                dispatch(state, .{ .change_mode = .mapping_panel });
                            } else {
                                dispatch(state, .{ .change_mode = .fx_ctrl });
                            }
                        } else {
                            dispatch(state, .{ .change_mode = .fx_ctrl });
                        }
                    },
                }
            }
        },
        .scroll => |new_pos| {
            const old_pos_abs = globals.state.fx_sel.scroll_position_abs;
            state.fx_sel.scroll_position_abs = new_pos;

            var delta: i16 = undefined;
            if ((old_pos_abs == 127 or old_pos_abs == 0) and new_pos == old_pos_abs) {
                if (old_pos_abs == 127) delta = 1 else delta = -1;
            } else {
                delta = @as(i16, @intCast(new_pos)) - @as(i16, @intCast(old_pos_abs));
            }

            const fx_count: i32 = @intCast(switch (state.fx_sel.current_category) {
                inline else => |impl| globals.mappings_list.list.get(impl).count(),
            });

            if (fx_count == 0) return; // Guard against empty list
            // Update scroll position with wrapping
            // Calculate new position with wrapping
            const new_pos_rel = @as(i32, @intCast(state.fx_sel.scroll_position_rel)) + delta;

            // Wrap around using modulo
            // Add max_pos before taking modulo to handle negative numbers correctly
            if (new_pos_rel >= fx_count) {
                // Wrap forward using remainder
                state.fx_sel.scroll_position_rel = @intCast(@rem(new_pos_rel, fx_count));
            } else if (new_pos_rel < 0) {
                // Wrap backward
                const wrapped = fx_count - @rem(@as(i32, @intCast(@abs(new_pos_rel))), fx_count);
                state.fx_sel.scroll_position_rel = @intCast(if (wrapped == fx_count) 0 else wrapped);
            } else {
                state.fx_sel.scroll_position_rel = @intCast(new_pos_rel);
            }

            // Log scroll action
            log.debug("Scroll: abs={d} delta={d} rel={d}/{d}", .{ state.fx_sel.scroll_position_abs, delta, state.fx_sel.scroll_position_rel, fx_count });
        },
    }
}

fn loadModuleMapping(module: ModulesList, fx_name: []const u8) !void {
    _ = module;
    _ = fx_name;
    unreachable;
}

fn updateTrackFx(module: ModulesList, fx_name: []const u8) !void {
    _ = module;
    _ = fx_name;
    unreachable;
}

fn hasMappingFor(module: ModulesList, fx_name: []const u8) bool {
    _ = module;
    _ = fx_name;
    unreachable;
}

/// Create empty mapping in MapStore
fn createEmptyMapping(state: *State, fx_name: [:0]const u8) !void {
    switch (state.fx_sel.current_category) {
        .INPUT => try globals.map_store.INPUT.put(globals.arena, try globals.arena.dupeZ(u8, fx_name), mappings.Inpt{}),
        .GATE => try globals.map_store.GATE.put(globals.arena, try globals.arena.dupeZ(u8, fx_name), mappings.Shp{}),
        .EQ => try globals.map_store.EQ.put(globals.arena, try globals.arena.dupeZ(u8, fx_name), mappings.Eq{}),
        .COMP => try globals.map_store.COMP.put(globals.arena, try globals.arena.dupeZ(u8, fx_name), mappings.Comp{}),
        .OUTPT => try globals.map_store.OUTPT.put(globals.arena, try globals.arena.dupeZ(u8, fx_name), mappings.Outpt{}),
    }
}

pub fn enterMappingMode(track_id: c_int, fx_number: i32) !void {
    const media_track =
        reaper.CSurf_TrackFromID(track_id, false);
    if (globals.mapping_panel == null) {
        globals.mapping_panel = MappingPanel.init(globals.arena);
    }
    try globals.mapping_panel.?.loadParameters(media_track, fx_number);
}
