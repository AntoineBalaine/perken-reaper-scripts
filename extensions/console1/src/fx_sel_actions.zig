const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const SCRouting = fx_ctrl_state.SCRouting;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const SettingsPanel = @import("settings_panel.zig");
const mappings = @import("mappings.zig");
const MappingPanel = @import("mapping_panel.zig").MappingPanel;
const ModulesList = statemachine.ModulesList;
const constants = @import("constants.zig");
const onMidiEvent_FxCtrl = @import("csurf/midi_events_fxctrl.zig").onMidiEvent_FxCtrl;
const MappingAction = @import("mapping_actions.zig").MappingAction;
const mappingActions = @import("mapping_actions.zig").mappingActions;
const settings_actions = @import("settings_actions.zig");
const SettingsActions = settings_actions.SettingsActions;
const dispatch = @import("actions.zig").dispatch;

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
            const track = reaper.GetSelectedTrack(@as(c_int, 0), @as(c_int, 0));
            if (track) |tr| {
                _ = reaper.TrackFX_AddByName(
                    tr,
                    plugin.name,
                    false,
                    -1000 - reaper.TrackFX_GetCount(tr),
                );
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
            if (switch (globals.map_store.get(fx_name, state.fx_sel.current_category)) {
                inline else => |impl| impl == null,
            }) {
                createEmptyMapping(state, fx_name) catch return;
                // Open mapping panel
                switch (state.fx_sel.current_category) {
                    inline else => |variant| {
                        const fxMap = @field(state.fx_ctrl.fxMap, @tagName(variant));

                        if (fxMap == null) return;
                        if (fxMap) |map| {
                            enterMappingMode(state.last_touched_tr_id, map[0]) catch {};
                            dispatch(state, .{ .change_mode = .mapping_panel });
                        }
                    },
                }
            }
        },
        .scroll => |new_pos| {
            const old_pos = globals.state.fx_sel.scroll_position_abs;
            var delta: i16 = undefined;
            if (new_pos == old_pos and (old_pos == 127 or old_pos == 0)) {
                if (old_pos == 127) delta = 1 else delta = -1;
            } else {
                delta = @as(i16, @intCast(new_pos)) - @as(i16, @intCast(old_pos));
            }

            state.fx_sel.scroll_position_abs = new_pos;

            const max_pos = switch (state.fx_sel.current_category) {
                inline else => |impl| @field(globals.map_store, @tagName(impl)).count(),
            };

            if (max_pos == 0) return; // Guard against empty list
            // Update scroll position with wrapping
            // Calculate new position with wrapping
            const current_pos = @as(i32, @intCast(state.fx_sel.scroll_position_rel));
            const new_pos_rel = current_pos + delta;

            // Wrap around using modulo
            // Add max_pos before taking modulo to handle negative numbers correctly
            state.fx_sel.scroll_position_rel = @intCast(@mod(@as(u32, @intCast(new_pos_rel)) + max_pos, max_pos));

            // const new_val = @as(i32, @intCast(state.fx_sel.scroll_position_rel)) + delta;
            // var new_delta: usize = undefined;
            // if (new_val > max_pos) {
            //     new_delta = new_val - max_pos;
            // } else if (new_val < 0) {
            //     new_delta = max_pos - @abs(new_val);
            // }
            // Log scroll action
            logger.log(
                .debug,
                "Scroll: abs={d} delta={d} rel={d}/{d}",
                .{ state.fx_sel.scroll_position_abs, delta, state.fx_sel.scroll_position_rel, max_pos },
                null,
                globals.allocator,
            );
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
        .INPUT => try globals.map_store.INPUT.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Inpt{}),
        .GATE => try globals.map_store.GATE.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Shp{}),
        .EQ => try globals.map_store.EQ.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Eq{}),
        .COMP => try globals.map_store.COMP.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Comp{}),
        .OUTPT => try globals.map_store.OUTPT.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Outpt{}),
    }
}

pub fn enterMappingMode(track_id: c_int, fx_number: i32) !void {
    const media_track =
        reaper.CSurf_TrackFromID(track_id, false);
    if (globals.mapping_panel == null) {
        globals.mapping_panel = MappingPanel.init(globals.allocator);
    }
    try globals.mapping_panel.?.loadParameters(media_track, fx_number);
}
