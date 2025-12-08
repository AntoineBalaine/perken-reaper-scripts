const std = @import("std");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const Globals = @import("globals.zig").Globals;
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.preset_browser_actions);
const mapping_browser = @import("mapping_browser.zig");
const reaper = @import("reaper.zig").reaper;
const constants = @import("constants.zig");
const fs_helpers = @import("fs_helpers.zig");

pub const PresetBrowserAction = union(enum) {
    scroll: u8,
    select_preset: struct {
        mapping_name: [:0]const u8,
    },
    close: void,
    open_for_current_fx: void,
};

pub fn presetBrowserActions(globals: *Globals, action: PresetBrowserAction) void {
    switch (action) {
        .open_for_current_fx => {
            // Because we want to browse presets for the currently active FX on the track,
            // we need to determine which module to use. We find the first module with an assigned FX.
            const track_state = &globals.state.fx_ctrl.track_state;

            // Find the first module that has an FX assigned
            const current_module = blk: {
                inline for (std.meta.fields(ModulesList)) |field| {
                    const module = @field(ModulesList, field.name);
                    if (track_state.module_locations.get(module)) |_| {
                        break :blk module;
                    }
                }
                // If no module has an FX, default to COMP
                break :blk ModulesList.COMP;
            };

            if (globals.state.current_tr_id) |track_id| {
                const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);

                if (track_state.module_locations.get(current_module)) |location| {
                    // Because we need to get the FX name from REAPER,
                    // we use TrackFX_GetNamedConfigParm to get the original name.
                    var buf: [512:0]u8 = undefined;
                    const fx_name = if (reaper.TrackFX_GetNamedConfigParm(track, location.fx_index, "original_name", &buf, buf.len))
                        std.mem.span(@as([*:0]const u8, &buf))
                    else
                        "unknown";

                    // Because the FX name from REAPER may contain invalid filesystem characters,
                    // we need to sanitize it before using it for file operations.
                    var sanitize_buf: [512:0]u8 = undefined;
                    const sanitized_fx_name = fs_helpers.sanitizeFxName(&sanitize_buf, fx_name) catch |err| {
                        log.err("Failed to sanitize FX name: {}", .{err});
                        return;
                    };

                    // Because we need to allocate the preset list, we use the arena allocator
                    const fx_name_z = globals.arena.dupeZ(u8, sanitized_fx_name) catch |err| {
                        log.err("Failed to allocate FX name: {}", .{err});
                        return;
                    };

                    // Because we need to allocate the preset list, we use the arena allocator
                    const preset_names = mapping_browser.getMappingNames(
                        globals.arena,
                        globals.resource_path,
                        fx_name_z,
                        current_module,
                    ) catch |err| {
                        log.err("Failed to get mapping names for {s}: {}", .{ fx_name_z, err });
                        // Because getting the preset list failed, we show an empty list
                        globals.state.preset_browser = .{
                            .target_fx = fx_name_z,
                            .target_module = current_module,
                            .available_presets = &.{},
                            .scroll_position_abs = 0,
                            .scroll_position_rel = 0,
                        };
                        dispatch(globals, .{ .change_mode = .preset_browser });
                        return;
                    };

                    globals.state.preset_browser = .{
                        .target_fx = fx_name_z,
                        .target_module = current_module,
                        .available_presets = preset_names,
                        .scroll_position_abs = 0,
                        .scroll_position_rel = 0,
                    };

                    dispatch(globals, .{ .change_mode = .preset_browser });
                } else {
                    log.warn("No FX assigned to current module", .{});
                }
            } else {
                log.warn("No track selected", .{});
            }
        },

        .scroll => |new_pos| {
            const preset_count: i32 = @intCast(globals.state.preset_browser.available_presets.len);

            if (@import("utils.zig").calculateNewScrollPosition(
                i32,
                &globals.state.preset_browser.scroll_position_abs,
                &globals.state.preset_browser.scroll_position_rel,
                new_pos,
                preset_count,
                1,
            )) |delta| {
                log.debug("Preset browser scroll: abs={d} delta={d} rel={d}/{d}", .{
                    globals.state.preset_browser.scroll_position_abs,
                    delta,
                    globals.state.preset_browser.scroll_position_rel,
                    preset_count,
                });
            }
        },

        .select_preset => |selection| {
            // Because we need to apply the selected preset to the current FX,
            // we update the preferred mapping and reload it into the track state.
            const browser_state = globals.state.preset_browser;
            const track_state = &globals.state.fx_ctrl.track_state;

            // Build filepath for the selected mapping using the same logic as MapStore.getMap()
            // Because MapStore keys filepaths with the absolute path and sanitized FX name,
            // we need to construct the filepath in the same format.
            var name_buf: [512:0]u8 = undefined;
            const sanitized_name = fs_helpers.sanitizeFxName(&name_buf, browser_state.target_fx) catch |err| {
                log.err("Failed to sanitize FX name: {}", .{err});
                dispatch(globals, .{ .change_mode = .fx_ctrl });
                return;
            };

            var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const filepath = fs_helpers.joinStrings(&path_buffer, &.{
                std.mem.span(globals.map_store.controller_dir),
                std.fs.path.sep_str,
                "maps",
                std.fs.path.sep_str,
                @tagName(browser_state.target_module),
                std.fs.path.sep_str,
                sanitized_name,
                std.fs.path.sep_str,
                selection.mapping_name,
                ".ini",
            });

            const filepath_z = globals.arena.dupeZ(u8, filepath) catch |err| {
                log.err("Failed to allocate filepath: {}", .{err});
                dispatch(globals, .{ .change_mode = .fx_ctrl });
                return;
            };

            // Because we want to make this the preferred mapping, we update the MapStore
            globals.map_store.setPreferredMapping(
                browser_state.target_fx,
                browser_state.target_module,
                filepath_z,
            ) catch |err| {
                log.err("Failed to set preferred mapping: {}", .{err});
                dispatch(globals, .{ .change_mode = .fx_ctrl });
                return;
            };

            // Because the FX is already loaded on the track, we only need to update the mapping
            // in track_state without reloading the FX instance (to avoid audio glitches).
            if (globals.map_store.get(browser_state.target_fx, browser_state.target_module)) |new_mapping| {
                // Because module_locations is an EnumArray, getPtr always returns a valid pointer
                // (not optional) since every enum value has an entry in the array.
                const opt_location_ptr = track_state.module_locations.getPtr(browser_state.target_module);
                // opt_location_ptr is *?Location (pointer to optional Location)
                if (opt_location_ptr.*) |*loc| {
                    loc.mapping = new_mapping;
                    log.info("Applied preset '{s}' to {s} module", .{ selection.mapping_name, @tagName(browser_state.target_module) });
                } else {
                    log.err("No FX assigned to {s} module", .{@tagName(browser_state.target_module)});
                }
            } else {
                log.err("Failed to load new mapping after setting preferred", .{});
            }

            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },

        .close => {
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
    }
}

test {
    std.testing.refAllDecls(@This());
}
