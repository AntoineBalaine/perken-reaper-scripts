const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("pReaper.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const constants = @import("constants.zig");
const dispatch = @import("actions.zig").dispatch;
const step = @import("unit/step.zig");
const log = std.log.scoped(.fx_sel_actions);
const TrackState = @import("track_state.zig");
const Globals = @import("globals.zig").Globals;
const utils = @import("utils");
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;
const MapStore = @import("mappings.zig");
const fx_browser = @import("fx_browser");
const mapping_actions = @import("mapping_actions.zig");
const StringPool = @import("string_pool").StringPool;
const translate = @import("translations.zig").tr;

pub const FxSelActions = @import("action_types.zig").FxSelActions;

/// The data of the levels of the browser: the plugins that have a mapping for the module, and what the plugin parser found.
fn browserSource(globals: *Globals) fx_browser.Source {
    const fxp = @import("fx_parser");
    const mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
    return .{
        .mapped_count = mappings.count(),
        .fx_chains = &fxp.fx_chains,
        .track_templates = &fxp.track_templates,
        .plugins_by_type = &fxp.pluginsByType,
        .tags = &fxp.fx_tags,
        .hidden_menus = if (globals.state.fx_sel.return_to_mapping) fx_browser.plugins_only_hidden else .{},
        .recent = &globals.recent_plugins,
    };
}

/// The level of the browser that is open, which is the first one when the path no longer leads anywhere.
fn openLevel(globals: *Globals, source: fx_browser.Source) fx_browser.Level {
    return fx_browser.levelAt(source, globals.state.fx_sel.path()) orelse blk: {
        globals.state.fx_sel.menu_depth = 0;
        break :blk .root;
    };
}

pub fn fxSelActions(globals: *Globals, sel_action: FxSelActions) void {
    const io = Globals.hostIo();
    switch (sel_action) {
        .fx_chain => |fx| {
            const track = reaper.GetSelectedTrack(null, @as(c_int, 0));
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
            const current_module = globals.state.fx_sel.current_category;
            if (globals.state.current_tr_id == null) {
                leaveBrowser(globals, current_module);
                return;
            }

            // Because a plugin that comes from a list, from the recent menu or from the search carries no map, and because the
            // store would then take its preferred map without asking, a plugin that has several maps opens the selector of maps
            // instead. The map that is chosen there comes back here with its name, so this does not repeat.
            if (plugin.mapping_name == null) {
                if (globals.mappings_list.findFx(current_module, plugin.name)) |found| {
                    if (found.maps.len > 1) {
                        openMapSelector(globals, globals.mappings_list.strings.get(found.fx_offset), found.fx_offset);
                        return;
                    }
                }
            }

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

            const phys_module: PhysicalModule = @fromBackingInt(@intCast(@backingInt(current_module)));
            const insert_idx = determineInsertionIndex(&globals.state, track, phys_module, globals.preferences.preferred_module_order);

            var loaded_mapping: ?MapStore.TaggedMapping = null;
            if (plugin.mapping_name) |map_name| {
                loaded_mapping = globals.map_store.getMap(io, plugin.name, current_module, map_name, &globals.mappings_list) catch null;
                if (loaded_mapping != null) preferMap(globals, plugin.name, current_module, map_name);
            } else {
                loaded_mapping = globals.map_store.get(io, plugin.name, current_module, &globals.mappings_list);
            }

            // Add new FX
            const new_fx_index = pReaper.TrackFX_AddByName(.{ track, plugin.name, false, insert_idx });
            if (new_fx_index < 0) {
                log.err("Failed to add new FX: {s}", .{plugin.name});
                leaveBrowser(globals, current_module);
                return;
            }

            rememberRecent(globals, plugin.name);

            // Append C1 suffix
            {
                const module_char = current_module.toModulePrefix();
                var name_buf: [512:0]u8 = undefined;
                const new_name = std.mem.printSentinel(&name_buf, "{s} (C1-{s})", .{ plugin.name, module_char }, 0) catch {
                    log.err("Failed to format FX name with suffix", .{});
                    _ = pReaper.TrackFX_Delete(.{ track, new_fx_index });
                    leaveBrowser(globals, current_module);
                    return;
                };
                _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, new_fx_index, "renamed_name", new_name });
            }

            // Apply associated preset, right after insertion
            if (loaded_mapping) |lm| {
                switch (lm) {
                    inline else => |m| {
                        if (m.fx_preset) |offset| {
                            const preset_name = globals.map_store.preset_strings.get(offset);
                            _ = pReaper.TrackFX_SetPreset(.{ track, new_fx_index, preset_name });
                        }
                    },
                }
            }

            // If replacing existing module FX, remove it.
            // Because the new FX may have been inserted before or after the old one,
            // we need to check whether the old FX's index shifted due to the insertion.
            const old_loc_opt = switch (current_module) {
                .STRIP => null,
                inline else => |phys| switch (track_state.mode) {
                    .multi_fx => |locs| locs.get(@as(PhysicalModule, @fromBackingInt(@intCast(@backingInt(phys))))),
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
                globals.arena_int.allocator(),
                io,
                &globals.mappings_list,
            );
            track_state.getLabels(track);

            // Because FX parameter loading now happens in enter_assign action,
            // we enter mapping mode if needed, otherwise return to fx_ctrl
            if (leaveToMapping(globals, current_module)) {
                // The browser was opened from the assignment of this module: the assignment is back, on the new plugin.
            } else if (loaded_mapping == null) {
                dispatch(globals, .{ .change_mode = .mapping_panel });
            } else {
                dispatch(globals, .{ .change_mode = .fx_ctrl });
            }
        },
        .close_browser => {
            if (leaveToMapping(globals, globals.state.fx_sel.current_category)) return;
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },
        .rescan => {
            const fxp = @import("fx_parser");
            fxp.deinit(globals.arena_int.allocator());
            fxp.init(globals.arena_int.allocator(), io) catch {};
        },
        .toggle_module_browser => |module| {
            if (globals.state.current_mode == .fx_sel and module == globals.state.fx_sel.current_category) {
                if (leaveToMapping(globals, module)) return;
                dispatch(globals, .{ .change_mode = .fx_ctrl });
            } else {
                globals.state.fx_sel.return_to_mapping = false;
                globals.state.fx_sel.resetMenus();
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
                    const source = browserSource(globals);
                    const level = openLevel(globals, source);
                    const index = globals.state.fx_sel.cursorPtr().*;
                    var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
                    switch (fx_browser.activate(source, level, index, &path_buf)) {
                        .enter => globals.state.fx_sel.enterMenu(index),
                        .mapped => |mapped_index| {
                            const fx_offset = mappings.keys()[mapped_index];
                            const mapping_offsets = mappings.get(fx_offset) orelse return;
                            const fx_name = globals.mappings_list.strings.get(fx_offset);
                            // Because the controller reaches the default button of a row with shift, confirming a plugin while shift is
                            // held makes it the default of the module, and the browser stays open, as a click on the button does.
                            if (globals.unit.shiftHeld() or globals.state.fx_ctrl.shift_held) {
                                fxSelActions(globals, .{ .set_default_plugin = fx_name });
                                return;
                            }

                            if (mapping_offsets.items.len == 1) {
                                const mapping_name = globals.mappings_list.strings.get(mapping_offsets.items[0].name_offset);
                                fxSelActions(globals, .{ .plugin = .{ .name = fx_name, .mapping_name = mapping_name } });
                            } else {
                                openMapSelector(globals, fx_name, fx_offset);
                            }
                        },
                        .plugin => |name| fxSelActions(globals, .{ .plugin = .{ .name = name, .mapping_name = null } }),
                        .fx_chain => |path| fxSelActions(globals, .{ .fx_chain = .{ .path = path } }),
                        .track_template => |path| fxSelActions(globals, .{ .track_template = .{ .path = path } }),
                        .root_leaf => |leaf| {
                            // The three plugins that have no list are inserted by their name.
                            const name = switch (leaf) {
                                .container => translate(&globals.translations, .fx_sel_container),
                                .video_processor => translate(&globals.translations, .fx_sel_video_processor),
                                else => translate(&globals.translations, .fx_sel_recent),
                            };
                            fxSelActions(globals, .{ .plugin = .{ .name = name, .mapping_name = null } });
                        },
                        .none => {},
                    }
                },
                .select_mapping => |sel| {
                    const mapping_offsets = mappings.get(sel.fx_string_pool_offset) orelse return;
                    if (sel.scroll_position_rel >= mapping_offsets.items.len) return;
                    const mapping_name = globals.mappings_list.strings.get(mapping_offsets.items[sel.scroll_position_rel].name_offset);
                    // Because the controller reaches the default button of a row with shift, confirming a row while shift is held
                    // makes it the default, and the selector stays open, as a click on the button does.
                    if (globals.unit.shiftHeld() or globals.state.fx_ctrl.shift_held) {
                        fxSelActions(globals, .{ .set_default_map = .{ .name = sel.fx_name, .mapping_name = mapping_name } });
                        return;
                    }
                    fxSelActions(globals, .{ .plugin = .{ .name = sel.fx_name, .mapping_name = mapping_name } });
                },
            }
        },
        .enter_menu => |index| {
            const source = browserSource(globals);
            const level = openLevel(globals, source);
            if (fx_browser.isMenu(source, level, index) and globals.state.fx_sel.menu_depth < fx_browser.max_depth) {
                globals.state.fx_sel.enterMenu(index);
            }
        },
        .back => {
            // Leaving goes one step up: from the mappings of a plugin to the list, and from a menu to the level that opened it.
            switch (globals.state.fx_sel.sub_mode) {
                .select_mapping => globals.state.fx_sel.sub_mode = .browse_fx,
                .browse_fx => if (globals.state.fx_sel.menu_depth > 0) globals.state.fx_sel.leaveMenu(),
            }
        },
        .scroll => |new_pos| {
            globals.state.fx_sel.scroll_changed = true;
            const scroll_mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
            switch (globals.state.fx_sel.sub_mode) {
                .browse_fx => {
                    const source = browserSource(globals);
                    const count = fx_browser.entryCount(source, openLevel(globals, source));
                    _ = utils.calculateNewScrollPosition(
                        i32,
                        &globals.state.fx_sel.scroll_position_abs,
                        globals.state.fx_sel.cursorPtr(),
                        new_pos,
                        @intCast(count),
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
        .scroll_by => |delta| {
            globals.state.fx_sel.scroll_changed = true;
            const scroll_mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
            switch (globals.state.fx_sel.sub_mode) {
                .browse_fx => {
                    const source = browserSource(globals);
                    step.wrap(globals.state.fx_sel.cursorPtr(), delta, fx_browser.entryCount(source, openLevel(globals, source)));
                },
                .select_mapping => |*sel| {
                    const mapping_offsets = scroll_mappings.get(sel.fx_string_pool_offset) orelse return;
                    step.wrap(&sel.scroll_position_rel, delta, mapping_offsets.items.len);
                },
            }
        },
        .select_fx => |fx_offset| {
            const fx_name = globals.mappings_list.strings.get(fx_offset);
            openMapSelector(globals, fx_name, fx_offset);
        },
        .set_default_plugin => |name| {
            const module = globals.state.fx_sel.current_category;
            // Because the name that the click carries belongs to the list of the browser, the default keeps a copy of its own.
            const owned = globals.arena_int.allocator().dupeSentinel(u8, name, 0) catch {
                log.err("Failed to make {s} the default of {s}: out of memory", .{ name, @tagName(module) });
                return;
            };
            globals.preferences.default_fx.set(module, owned);
            if (!comptime @import("builtin").is_test) {
                globals.preferences.saveToDisk(io, globals.resource_path) catch {
                    log.err("Failed to save the default of {s}", .{@tagName(module)});
                };
            }
        },
        .set_default_map => |chosen| {
            const module = globals.state.fx_sel.current_category;
            globals.map_store.setDefaultMap(io, module, chosen.name, chosen.mapping_name, &globals.mappings_list) catch |err| {
                log.err("Failed to make {s} the default map of {s}: {s}", .{ chosen.mapping_name, chosen.name, @errorName(err) });
            };
        },
    }
}

/// Opens the selector of the maps of a plugin.
fn openMapSelector(globals: *Globals, fx_name: [:0]const u8, fx_offset: StringPool.StringRef) void {
    globals.state.fx_sel.sub_mode = .{ .select_mapping = .{
        .fx_name = fx_name,
        .fx_string_pool_offset = fx_offset,
    } };
}

/// Leaves the browser when nothing was inserted: back to the assignment when the browser was opened from it, and to the FX
/// controls otherwise.
fn leaveBrowser(globals: *Globals, module: ModulesList) void {
    if (leaveToMapping(globals, module)) return;
    dispatch(globals, .{ .change_mode = .fx_ctrl });
}

/// Makes the map that was chosen the one that the store gives for the plugin. Because the store keeps the first map that it loaded
/// for a plugin as its preferred one, which is its default map, a map that was chosen by name would otherwise be loaded and then
/// ignored when the track is validated.
fn preferMap(globals: *Globals, fx_name: [:0]const u8, module: ModulesList, mapping_name: [:0]const u8) void {
    const path = globals.mappings_list.lookupPath(module, fx_name, mapping_name) orelse return;
    globals.map_store.setPreferredMapping(fx_name, module, path) catch |err| {
        log.err("Failed to prefer the map {s} of {s}: {s}", .{ mapping_name, fx_name, @errorName(err) });
    };
}

/// How many plugins the recent menu keeps.
const recent_capacity = 20;

/// Puts a plugin that was just chosen first in the recent menu, and drops it from where it was.
fn rememberRecent(globals: *Globals, name: [:0]const u8) void {
    const allocator = globals.arena_int.allocator();
    var next: @import("fx_parser_types").FxList = .{};
    // Because the names of the lists are read as strings that end in a zero, the copy keeps one.
    const owned = allocator.dupeSentinel(u8, name, 0) catch return;
    next.put(allocator, owned, {}) catch return;
    for (globals.recent_plugins.keys()) |previous| {
        if (std.mem.eql(u8, previous, name)) continue;
        if (next.count() >= recent_capacity) break;
        next.put(allocator, previous, {}) catch return;
    }
    globals.recent_plugins = next;
}

/// Goes back to the assignment of `module` when the browser was opened from it, and says whether it did.
fn leaveToMapping(globals: *Globals, module: ModulesList) bool {
    if (!globals.state.fx_sel.return_to_mapping) return false;
    globals.state.fx_sel.return_to_mapping = false;
    var target = module;
    // Because a strip that was not chosen leaves the plugins of the modules on the track, the track is validated again, and the
    // assignment opens on the first module.
    if (module == .STRIP and globals.state.fx_ctrl.track_state.mode != .channel_strip) {
        mapping_actions.revalidateTrack(globals);
        target = mapping_actions.firstModuleWithFx(&globals.state.fx_ctrl.track_state);
    }
    dispatch(globals, .{ .change_mode = .mapping_panel });
    if (globals.state.current_mode == .mapping_panel) dispatch(globals, .{ .mapping_panel = .{ .enter_assign = target } });
    return true;
}

fn handleStripPlugin(globals: *Globals, name: [:0]const u8, mapping_name: ?[:0]const u8) void {
    const io = Globals.hostIo();
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
        leaveBrowser(globals, .STRIP);
        return;
    }
    rememberRecent(globals, name);

    {
        var name_buf: [512:0]u8 = undefined;
        const new_name = std.mem.printSentinel(&name_buf, "{s} (C1-X)", .{name}, 0) catch {
            _ = pReaper.TrackFX_Delete(.{ track, new_fx_index });
            leaveBrowser(globals, .STRIP);
            return;
        };
        _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, new_fx_index, "renamed_name", new_name });
    }

    // Load the mapping first so that fx_preset is available for preset application
    if (mapping_name) |map_name| {
        if (globals.map_store.getMap(io, name, .STRIP, map_name, &globals.mappings_list)) |_| {
            preferMap(globals, name, .STRIP, map_name);
        } else |_| {}
    }

    // Apply associated preset after the mapping has been loaded
    if (globals.map_store.getPresetName(name, .STRIP)) |preset_name| {
        _ = pReaper.TrackFX_SetPreset(.{ track, new_fx_index, preset_name });
    }

    _ = track_state.validateTrack(track, globals.preferences.default_fx, &globals.map_store, globals.preferences, globals.arena_int.allocator(), io, &globals.mappings_list);
    track_state.getLabels(track);

    const needs_mapping = (globals.map_store.get(io, name, .STRIP, &globals.mappings_list) == null);
    if (leaveToMapping(globals, .STRIP)) {
        // The browser was opened from the assignment of the strip: the assignment is back, on the new plugin.
    } else if (needs_mapping) {
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
