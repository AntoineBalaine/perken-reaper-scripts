const std = @import("std");
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const Globals = @import("globals.zig").Globals;
const mappings = @import("mappings.zig");
const dispatch = @import("actions.zig").dispatch;
const step = @import("unit/step.zig");
const log = std.log.scoped(.mapping_actions);
const TaggedMapping = mappings.TaggedMapping;
const reaper = @import("reaper").reaper;
const constants = @import("constants.zig");
const utils = @import("utils");
const pReaper = @import("pReaper.zig");
const TrackState = @import("track_state.zig");
const swell = @import("swell.zig");
const tr = @import("translations.zig").tr;
const preset_file_reader = @import("preset_file_reader");

pub const MappingPanelAction = @import("action_types.zig").MappingPanelAction;

pub fn mappingPanelActions(globals: *Globals, action: MappingPanelAction) void {
    const io = Globals.hostIo();
    switch (action) {
        // Sub-mode transitions
        .enter_browse => {
            // Because we need to deinitialize the previous sub-state before entering browse,
            globals.state.mapping_panel.deinitCurrentSubMode();

            var browse_state = statemachine.BrowseState.init(globals.state.mapping_panel.gpa_int.allocator());
            const browse_allocator = browse_state.arena.allocator();

            inline for (@typeInfo(ModulesList).@"enum".field_names, 0..) |field_name, i| {
                const module = @field(ModulesList, field_name);
                const module_name = @tagName(module);

                // Because STRIP resolves its FX from channel_strip state
                // while physical modules resolve from multi_fx locations,
                // we branch on the module type within the same loop.
                const fx_index_opt: ?c_int = if (module == .STRIP)
                    switch (globals.state.fx_ctrl.track_state.mode) {
                        .channel_strip => |strip| strip.fx_index,
                        .multi_fx => null,
                    }
                else blk: {
                    const phys: PhysicalModule = @fromBackingInt(@intCast(@backingInt(module)));
                    break :blk switch (globals.state.fx_ctrl.track_state.mode) {
                        .multi_fx => |locs| if (locs.get(phys)) |loc| loc.fx_index else null,
                        .channel_strip => null,
                    };
                };

                if (fx_index_opt) |fx_index| {
                    if (globals.state.current_tr_id) |track_id| {
                        const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
                        var fx_name_buf: [512:0]u8 = undefined;
                        if (reaper.TrackFX_GetFXName(track, fx_index, &fx_name_buf, fx_name_buf.len)) {
                            const fx_name = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                            browse_state.available_modules[i] = std.fmt.allocPrintSentinel(browse_allocator, "{s}    [{s}]", .{ module_name, fx_name }, 0) catch null;
                        } else {
                            browse_state.available_modules[i] = null;
                        }
                    } else {
                        browse_state.available_modules[i] = null;
                    }
                } else {
                    browse_state.available_modules[i] = null;
                }
            }

            globals.state.mapping_panel.mode = .{ .browse = browse_state };
        },

        .create_mapping => {
            dispatch(globals, .{ .change_mode = .mapping_panel });
            if (globals.state.current_mode == .mapping_panel) mappingPanelActions(globals, .{ .enter_assign = firstModuleWithFx(&globals.state.fx_ctrl.track_state) });
        },

        .enter_assign => |module| {
            // Because every module that has an FX is assigned at once, the state of each one is built here, and the module that
            // was asked for is built even when it has no FX.
            globals.state.mapping_panel.deinitCurrentSubMode();
            var set: statemachine.AssignSet = .empty;
            inline for (comptime std.enums.values(ModulesList)) |candidate| {
                if (candidate == module or globals.state.fx_ctrl.track_state.fxIndexOf(candidate) != null) {
                    if (buildAssignState(globals, candidate)) |state| set.states.set(candidate, state);
                }
            }
            if (set.getConst(module) == null) {
                set.deinit();
                globals.state.mapping_panel.mode = .{ .browse = statemachine.BrowseState.init(globals.state.mapping_panel.gpa_int.allocator()) };
                return;
            }
            set.focus = module;
            globals.state.mapping_panel.mode = .{ .assign = set };
        },

        .assign_swap_fx => |module| {
            dispatch(globals, .{ .fx_sel = .{ .toggle_module_browser = module } });
            // Because every other way into the browser clears it, it is set once the browser is open.
            if (globals.state.current_mode == .fx_sel) globals.state.fx_sel.return_to_mapping = true;
        },

        .assign_open_fx_ui => |module| {
            const fx_index = globals.state.fx_ctrl.track_state.fxIndexOf(module) orelse return;
            const track_id = globals.state.current_tr_id orelse return;
            const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
            // Because the window is a toggle, a plugin whose window is open has it closed (2), and otherwise shown (3).
            const open = pReaper.TrackFX_GetFloatingWindow(.{ track, fx_index }) != null;
            const show_flag: c_int = if (open) 2 else 3;
            pReaper.TrackFX_Show(.{ track, fx_index, show_flag });
        },

        .exit_to_fx_ctrl => {
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },

        // BROWSE sub-mode actions
        .browse_scroll => |new_pos| {
            const module_count: i32 = @intCast(comptime std.enums.values(ModulesList).len);
            var browse = &globals.state.mapping_panel.mode.browse;

            if (utils.calculateNewScrollPosition(
                i32,
                &browse.scroll_position_abs,
                &browse.scroll_position_rel,
                new_pos,
                module_count,
                1,
            )) |_| {
                const module_values = comptime std.enums.values(ModulesList);
                browse.selected_module = module_values[browse.scroll_position_rel];
            }
        },

        .browse_scroll_by => |delta| {
            var browse = &globals.state.mapping_panel.mode.browse;
            step.wrap(&browse.scroll_position_rel, delta, comptime std.enums.values(ModulesList).len);
            const module_values = comptime std.enums.values(ModulesList);
            browse.selected_module = module_values[browse.scroll_position_rel];
        },

        .browse_select_module => |module| {
            globals.state.mapping_panel.mode.browse.selected_module = module;
        },

        .browse_confirm => {
            const selected = globals.state.mapping_panel.mode.browse.selected_module;
            mappingPanelActions(globals, .{ .enter_assign = selected });
        },

        .browse_cancel => {
            mappingPanelActions(globals, .exit_to_fx_ctrl);
        },

        // ASSIGN sub-mode actions
        .assign_select_parameter => |maybe_param| {
            log.debug("Selected parameter: {?}", .{maybe_param});
            assignOf(globals).selected_parameter = maybe_param;
        },

        .assign_select_control => |maybe_control| {
            log.debug("Selected control: {s}", .{if (maybe_control) |cc| @tagName(cc) else "none"});
            if (maybe_control) |cc| focusControl(globals, cc);
            var assign = assignOf(globals);
            assign.selected_control = maybe_control;
            // Because CC and param can arrive in any order, we check
            // whether both inputs are present and create the assignment.
            if (assign.midi_learn_active) {
                tryCompleteLearnAssignment(globals);
            }
        },

        .assign_toggle_midi_learn => {
            // Because the modules are learned at the same time, the learn mode is the same for all of them.
            const set = assignSet(globals);
            const on = !set.active().midi_learn_active;
            log.debug("MIDI learn {s}", .{if (on) "enabled" else "disabled"});
            inline for (comptime std.enums.values(ModulesList)) |each| {
                if (set.get(each)) |state| {
                    state.midi_learn_active = on;
                    state.selected_control = null;
                    state.learned_param = null;
                }
            }
        },

        .assign_midi_learned_param => |param_index| {
            var assign = assignOf(globals);
            if (assign.midi_learn_active) {
                assign.learned_param = param_index;
                log.debug("MIDI learn: param {d} captured", .{param_index});
                tryCompleteLearnAssignment(globals);
            }
        },

        .assign_update_knob => |knob| {
            const set = assignSet(globals);
            const owner = if (set.moduleOf(knob.cc)) |module| set.get(module).? else set.active();
            owner.knob_values[@backingInt(knob.cc)] = knob.value;
        },

        .assign_add_mapping => |mapping| {
            log.debug("Added mapping: {s} -> param {d}", .{ @tagName(mapping.control), mapping.param });
            focusControl(globals, mapping.control);
            // Because we need to add the mapping to current_mappings based on module type,
            // we switch on the current_mappings union
            switch (assignOf(globals).current_mappings) {
                .COMP => |*comp| switch (mapping.control) {
                    .Comp_Attack => comp.Comp_Attack = mapping.param,
                    .Comp_DryWet => comp.Comp_DryWet = mapping.param,
                    .Comp_Ratio => comp.Comp_Ratio = mapping.param,
                    .Comp_Release => comp.Comp_Release = mapping.param,
                    .Comp_Thresh => comp.Comp_Thresh = mapping.param,
                    .Comp_comp => comp.Comp_comp = mapping.param,
                    .Comp_HiCut => comp.Comp_HiCut = mapping.param,
                    .Comp_LoCut => comp.Comp_LoCut = mapping.param,
                    else => {},
                },
                .EQ => |*eq| switch (mapping.control) {
                    .Eq_HiFrq => eq.Eq_HiFrq = mapping.param,
                    .Eq_HiGain => eq.Eq_HiGain = mapping.param,
                    .Eq_HiMidFrq => eq.Eq_HiMidFrq = mapping.param,
                    .Eq_HiMidGain => eq.Eq_HiMidGain = mapping.param,
                    .Eq_HiMidQ => eq.Eq_HiMidQ = mapping.param,
                    .Eq_LoFrq => eq.Eq_LoFrq = mapping.param,
                    .Eq_LoGain => eq.Eq_LoGain = mapping.param,
                    .Eq_LoMidFrq => eq.Eq_LoMidFrq = mapping.param,
                    .Eq_LoMidGain => eq.Eq_LoMidGain = mapping.param,
                    .Eq_LoMidQ => eq.Eq_LoMidQ = mapping.param,
                    .Eq_eq => eq.Eq_eq = mapping.param,
                    .Eq_hp_shape => eq.Eq_hp_shape = mapping.param,
                    .Eq_lp_shape => eq.Eq_lp_shape = mapping.param,
                    else => {},
                },
                .INPUT => |*input| switch (mapping.control) {
                    .Inpt_Gain => input.Inpt_Gain = mapping.param,
                    .Inpt_HiCut => input.Inpt_HiCut = mapping.param,
                    .Inpt_LoCut => input.Inpt_LoCut = mapping.param,
                    .Inpt_disp_mode => input.Inpt_disp_mode = mapping.param,
                    .Inpt_disp_on => input.Inpt_disp_on = mapping.param,
                    .Inpt_filt_to_comp => input.Inpt_filt_to_comp = mapping.param,
                    // .Inpt_phase_inv => input.Inpt_phase_inv = mapping.param,
                    .Inpt_preset => input.Inpt_preset = mapping.param,
                    else => {},
                },
                .OUTPT => |*output| switch (mapping.control) {
                    .Out_Drive => output.Out_Drive = mapping.param,
                    .Out_DriveChar => output.Out_DriveChar = mapping.param,
                    .Out_Pan => output.Out_Pan = mapping.param,
                    .Out_Vol => output.Out_Vol = mapping.param,
                    else => {},
                },
                .GATE => |*gate| switch (mapping.control) {
                    .Shp_Gate => gate.Shp_Gate = mapping.param,
                    .Shp_GateRelease => gate.Shp_GateRelease = mapping.param,
                    .Shp_Punch => gate.Shp_Punch = mapping.param,
                    .Shp_hard_gate => gate.Shp_hard_gate = mapping.param,
                    .Shp_shape => gate.Shp_shape = mapping.param,
                    .Shp_sustain => gate.Shp_sustain = mapping.param,
                    else => {},
                },
                .STRIP => |*strip| {
                    const cc_name = @tagName(mapping.control);
                    inline for (@typeInfo(mappings.ChannelStripMapping).@"struct".field_names) |field_name| {
                        if (comptime std.mem.eql(u8, field_name, "version")) continue;
                        if (comptime std.mem.eql(u8, field_name, "fx_preset")) continue;
                        if (std.mem.eql(u8, cc_name, field_name)) {
                            @field(strip, field_name) = mapping.param;
                        }
                    }
                },
            }
            assignOf(globals).selected_parameter = null;
        },

        .assign_remove_mapping => |control| {
            log.debug("Removed mapping for control: {s}", .{@tagName(control)});
            focusControl(globals, control);
            // Because we need to remove the mapping from current_mappings,
            // we switch on the union type
            switch (assignOf(globals).current_mappings) {
                .COMP => |*comp| switch (control) {
                    .Comp_Attack => comp.Comp_Attack = null,
                    .Comp_DryWet => comp.Comp_DryWet = null,
                    .Comp_Ratio => comp.Comp_Ratio = null,
                    .Comp_Release => comp.Comp_Release = null,
                    .Comp_Thresh => comp.Comp_Thresh = null,
                    .Comp_comp => comp.Comp_comp = null,
                    .Comp_HiCut => comp.Comp_HiCut = null,
                    .Comp_LoCut => comp.Comp_LoCut = null,
                    else => {},
                },
                .EQ => |*eq| switch (control) {
                    .Eq_HiFrq => eq.Eq_HiFrq = null,
                    .Eq_HiGain => eq.Eq_HiGain = null,
                    .Eq_HiMidFrq => eq.Eq_HiMidFrq = null,
                    .Eq_HiMidGain => eq.Eq_HiMidGain = null,
                    .Eq_HiMidQ => eq.Eq_HiMidQ = null,
                    .Eq_LoFrq => eq.Eq_LoFrq = null,
                    .Eq_LoGain => eq.Eq_LoGain = null,
                    .Eq_LoMidFrq => eq.Eq_LoMidFrq = null,
                    .Eq_LoMidGain => eq.Eq_LoMidGain = null,
                    .Eq_LoMidQ => eq.Eq_LoMidQ = null,
                    .Eq_eq => eq.Eq_eq = null,
                    .Eq_hp_shape => eq.Eq_hp_shape = null,
                    .Eq_lp_shape => eq.Eq_lp_shape = null,
                    else => {},
                },
                .INPUT => |*input| switch (control) {
                    .Inpt_Gain => input.Inpt_Gain = null,
                    .Inpt_HiCut => input.Inpt_HiCut = null,
                    .Inpt_LoCut => input.Inpt_LoCut = null,
                    .Inpt_disp_mode => input.Inpt_disp_mode = null,
                    .Inpt_disp_on => input.Inpt_disp_on = null,
                    .Inpt_filt_to_comp => input.Inpt_filt_to_comp = null,
                    // .Inpt_phase_inv => input.Inpt_phase_inv = null,
                    .Inpt_preset => input.Inpt_preset = null,
                    else => {},
                },
                .OUTPT => |*output| switch (control) {
                    .Out_Drive => output.Out_Drive = null,
                    .Out_DriveChar => output.Out_DriveChar = null,
                    .Out_Pan => output.Out_Pan = null,
                    .Out_Vol => output.Out_Vol = null,
                    else => {},
                },
                .GATE => |*gate| switch (control) {
                    .Shp_Gate => gate.Shp_Gate = null,
                    .Shp_GateRelease => gate.Shp_GateRelease = null,
                    .Shp_Punch => gate.Shp_Punch = null,
                    .Shp_hard_gate => gate.Shp_hard_gate = null,
                    .Shp_shape => gate.Shp_shape = null,
                    .Shp_sustain => gate.Shp_sustain = null,
                    else => {},
                },
                .STRIP => |*strip| {
                    const cc_name = @tagName(control);
                    inline for (@typeInfo(mappings.ChannelStripMapping).@"struct".field_names) |field_name| {
                        if (comptime std.mem.eql(u8, field_name, "version")) continue;
                        if (comptime std.mem.eql(u8, field_name, "fx_preset")) continue;
                        if (std.mem.eql(u8, cc_name, field_name)) {
                            @field(strip, field_name) = null;
                        }
                    }
                },
            }
        },

        .assign_change_module => |new_module| {
            // Because every module is assigned at once, changing the module focuses it. A module that has no state gets one.
            const set = assignSet(globals);
            if (set.getConst(new_module) == null) {
                const state = buildAssignState(globals, new_module) orelse return;
                set.states.set(new_module, state);
            }
            set.setFocus(new_module);
            // Because the control and the parameter that were learned belong to the module that was focused, they do not carry
            // over (the learn mode stays on, so the user can keep learning on the new module).
            inline for (comptime std.enums.values(ModulesList)) |each| {
                if (set.get(each)) |state| {
                    state.selected_control = null;
                    state.learned_param = null;
                }
            }
        },

        .assign_set_preset => |maybe_offset| {
            assignOf(globals).selected_preset = maybe_offset;
        },

        .assign_toggle_store_preset => |store_module| {
            const set = assignSet(globals);
            if (set.getConst(store_module) == null) return;
            set.setFocus(store_module);
            assignOf(globals).store_preset_data = !assignOf(globals).store_preset_data;
        },

        .assign_request_save => |save_module| {
            const set = assignSet(globals);
            if (set.getConst(save_module) == null) return;
            set.setFocus(save_module);
            const assign_state = set.active();
            assign_state.save_error = null;

            // Build the maps root path for the initial directory
            var maps_root_buf: [std.fs.max_path_bytes:0]u8 = undefined;
            const maps_root = std.mem.printSentinel(&maps_root_buf, "{s}{s}maps", .{
                @as([]const u8, globals.resource_path),
                std.fs.path.sep_str,
            }, 0) catch return;

            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const dialog_title = tr(&globals.translations, .save_dialog_title);
            var initial_name_buf: [160:0]u8 = undefined;
            const initial_name = defaultMapFileName(&initial_name_buf, assign_state.target_fx);
            if (swell.browseForSaveFile(dialog_title, maps_root, initial_name, "INI files\x00*.ini\x00", &path_buf)) |path| {
                if (!isInsideMapsDir(path, maps_root)) {
                    assign_state.save_error = .save_error_outside_maps;
                    return;
                }

                // Perform the save directly from assign state
                const fx_name = assign_state.target_fx;
                const module = std.meta.activeTag(assign_state.current_mappings);

                var save_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
                const save_path: [:0]const u8 = std.mem.printSentinel(&save_path_buf, "{s}", .{path}, 0) catch return;

                const basename = std.fs.path.basename(path);
                const alloc = assign_state.arena.allocator();
                const mapping_name: [:0]const u8 = alloc.dupeSentinel(u8, std.fs.path.stem(basename), 0) catch return;
                const fx_name_z: [:0]const u8 = alloc.dupeSentinel(u8, fx_name, 0) catch return;

                // Because the mapping can store the state of the plugin as it is now, which does not need a named preset, the state is
                // read from the plugin, and the preset that the map file installs is named after the mapping.
                var embedded_preset: ?preset_file_reader.EmbeddedPreset = null;
                var preset_name_offset: ?@import("string_pool").StringPool.StringRef = null;
                if (assign_state.store_preset_data) {
                    embedded_preset = captureFxState(alloc, &globals.state.fx_ctrl.track_state, globals.state.current_tr_id, module);
                    if (embedded_preset == null) {
                        assign_state.save_error = .save_error_no_state;
                        return;
                    }
                    preset_name_offset = globals.map_store.preset_strings.intern(globals.map_store.allocator, mapping_name) catch null;
                }
                switch (assign_state.current_mappings) {
                    inline else => |*m| {
                        m.fx_preset = preset_name_offset;
                    },
                }
                const tagged_mapping = assign_state.current_mappings;

                globals.map_store.saveToFile(io, globals.fs_ops, module, fx_name_z, tagged_mapping, save_path, embedded_preset) catch {
                    assign_state.save_error = .save_error_write_failed;
                    return;
                };

                globals.mappings_list.registerPath(module, fx_name_z, mapping_name, save_path) catch |err| {
                    log.warn("Failed to register saved mapping path: {}", .{err});
                };
                _ = globals.map_store.getMap(io, fx_name_z, module, mapping_name, &globals.mappings_list) catch |err| {
                    log.warn("Failed to load saved mapping into cache: {}", .{err});
                };

                switch (module) {
                    .STRIP => {
                        switch (globals.state.fx_ctrl.track_state.mode) {
                            .channel_strip => |*strip| {
                                strip.mapping = tagged_mapping.STRIP;
                            },
                            .multi_fx => {},
                        }
                    },
                    inline else => |mod| {
                        const phys_module: PhysicalModule = @fromBackingInt(@intCast(@backingInt(mod)));
                        if (globals.state.fx_ctrl.track_state.getModuleLocations()) |locs| {
                            if (locs.get(phys_module)) |existing_loc| {
                                locs.set(phys_module, .{
                                    .fx_index = existing_loc.fx_index,
                                    .mapping = tagged_mapping,
                                });
                            }
                        }
                    },
                }
            }
        },

        .assign_cancel => {
            mappingPanelActions(globals, .exit_to_fx_ctrl);
        },
    }
}

/// The assignment of the focused module, which is where the actions that carry no control go.
fn assignOf(globals: *Globals) *statemachine.AssignState {
    return globals.state.mapping_panel.mode.assign.active();
}

fn assignSet(globals: *Globals) *statemachine.AssignSet {
    return &globals.state.mapping_panel.mode.assign;
}

/// Focuses the module that owns a control, which is where the actions that carry it go.
fn focusControl(globals: *Globals, cc: c1.CCs) void {
    const set = assignSet(globals);
    if (set.moduleOf(cc)) |module| set.setFocus(module);
}

/// The module that opens first: the channel strip when the track has one, and the first module that has an FX otherwise.
fn firstModuleWithFx(track_state: *const TrackState) ModulesList {
    inline for (comptime std.enums.values(ModulesList)) |module| {
        if (track_state.fxIndexOf(module) != null) return module;
    }
    return .INPUT;
}

/// Builds the assignment of a module of the track, which is its parameters, its mapping, its presets, and the names of the FX
/// of the track. It is null when the state cannot be built.
fn buildAssignState(globals: *Globals, module: ModulesList) ?statemachine.AssignState {
    var assign_state = statemachine.AssignState.init(globals.state.mapping_panel.gpa_int.allocator(), TaggedMapping.empty(module));
    if (!fillAssignState(globals, &assign_state, module)) {
        assign_state.deinit();
        return null;
    }
    return assign_state;
}

fn fillAssignState(globals: *Globals, assign_state: *statemachine.AssignState, module: ModulesList) bool {
    const io = Globals.hostIo();
    const assign_allocator = assign_state.arena.allocator();

    // Because the UI needs FX names for all modules (for the dropdown
    // and module headings), we cache them in assign_state so that the
    // rendering code doesn't need to call REAPER APIs.
    if (globals.state.current_tr_id) |track_id| {
        const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
        populateModuleFxNames(assign_state, track, &globals.state.fx_ctrl.track_state, assign_allocator);
    }

    // Because we need to load FX parameters and initialize assign_state with current mappings,
    // we get the FX from the track_state mode
    // Resolve the FX index for loading parameters
    const fx_index: ?c_int = switch (module) {
        .STRIP => switch (globals.state.fx_ctrl.track_state.mode) {
            .channel_strip => |strip| strip.fx_index,
            .multi_fx => null,
        },
        inline else => |phys| switch (globals.state.fx_ctrl.track_state.mode) {
            .multi_fx => |locs| if (locs.get(@as(PhysicalModule, @fromBackingInt(@intCast(@backingInt(phys)))))) |loc| loc.fx_index else null,
            .channel_strip => null,
        },
    };
    assign_state.assign_fx_index = fx_index;
    if (fx_index) |fxi| {
        const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id orelse return false, constants.g_csurf_mcpmode);

        const params_length: usize = @intCast(reaper.TrackFX_GetNumParams(track, fxi));
        assign_state.param_store.clear();
        const param_allocator = assign_state.param_store.allocator;
        assign_state.param_store.params.ensureTotalCapacity(param_allocator, params_length) catch return false;

        var prm_name_buf: [256:0]u8 = undefined;
        for (0..params_length) |i| {
            const prm_idx: i32 = @intCast(i);
            if (reaper.TrackFX_GetParamName(track, fxi, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
                assign_state.param_store.addParam(prm_idx, param_name) catch return false;
            }
        }

        if (module == .STRIP) {
            var fx_name_buf: [512:0]u8 = undefined;
            if (reaper.TrackFX_GetNamedConfigParm(track, fxi, "original_name", &fx_name_buf, fx_name_buf.len)) {
                const fx_name = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                assign_state.target_fx = assign_allocator.dupeSentinel(u8, fx_name, 0) catch return false;
            }
        }

        // Load existing mapping from the module location
        switch (module) {
            .STRIP => switch (globals.state.fx_ctrl.track_state.mode) {
                .channel_strip => |strip| {
                    assign_state.current_mappings = .{ .STRIP = strip.mapping };
                },
                .multi_fx => {},
            },
            inline else => |phys| switch (globals.state.fx_ctrl.track_state.mode) {
                .multi_fx => |locs| {
                    if (locs.get(@as(PhysicalModule, @fromBackingInt(@intCast(@backingInt(phys)))))) |loc| {
                        if (loc.mapping) |tagged_mapping| {
                            assign_state.current_mappings = tagged_mapping;
                        }
                    }
                },
                .channel_strip => {},
            },
        }
    }

    // The assignment panel’s knobs should start at the current
    // FX parameter positions, so we populate knob_values from REAPER.
    if (globals.state.current_tr_id) |track_id| {
        const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
        populateKnobValues(assign_state, track, &globals.state.fx_ctrl.track_state);
    }

    // Set target_fx from the cached name for the selected module.
    if (module != .STRIP) {
        const phys: PhysicalModule = @fromBackingInt(@intCast(@backingInt(module)));
        if (assign_state.module_fx_names.get(phys)) |name| {
            assign_state.target_fx = assign_allocator.dupeSentinel(u8, name, 0) catch return false;
        }
    }

    assign_state.initPresetStrings(globals.state.mapping_panel.gpa_int.allocator());

    // Because the assignment panel needs to show available presets in a dropdown,
    // we load the preset names from the REAPER user preset file on disk.
    if (fx_index) |fxi| {
        if (globals.state.current_tr_id) |track_id| {
            const track_for_preset = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
            var preset_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
            reaper.TrackFX_GetUserPresetFilename(track_for_preset, fxi, @ptrCast(&preset_path_buf), @intCast(preset_path_buf.len));
            const preset_path: [:0]const u8 = std.mem.span(@as([*:0]const u8, &preset_path_buf));
            if (preset_path.len > 0) {
                assign_state.preset_name_offsets = preset_file_reader.readPresetNames(
                    assign_state.arena.allocator(),
                    io,
                    &assign_state.preset_strings,
                    preset_path,
                ) catch &.{};
            }
        }
    }
    return true;
}

// Because the UI rendering code needs FX names for all modules (for the
// module dropdown and panel headings), we fetch them once when entering
// assign mode and store them in AssignState. The strings are allocated on
// the assign arena and freed when leaving the submode.
fn populateModuleFxNames(
    assign_state: *statemachine.AssignState,
    track: reaper.MediaTrack,
    track_state: *const @import("track_state.zig"),
    allocator: std.mem.Allocator,
) void {
    const locs = switch (track_state.mode) {
        .multi_fx => |l| l,
        .channel_strip => return,
    };
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        if (locs.get(module)) |location| {
            var fx_name_buf: [256:0]u8 = undefined;
            if (reaper.TrackFX_GetNamedConfigParm(track, location.fx_index, "original_name", &fx_name_buf, fx_name_buf.len)) {
                const fx_name = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                assign_state.module_fx_names.set(module, allocator.dupeSentinel(u8, fx_name, 0) catch null);
            } else {
                assign_state.module_fx_names.set(module, null);
            }
        } else {
            assign_state.module_fx_names.set(module, null);
        }
    }
}

/// Because CC and param can arrive in any order during MIDI learn, this
/// helper checks whether both inputs are present and creates the assignment.
///
/// if so, then clears both inputs.
fn tryCompleteLearnAssignment(globals: *Globals) void {
    var assign = assignOf(globals);
    if (assign.selected_control) |control| {
        if (assign.learned_param) |param_index| {
            log.debug("MIDI learn complete: {s} -> param {d}", .{ @tagName(control), param_index });
            mappingPanelActions(globals, .{ .assign_add_mapping = .{
                .param = @intCast(param_index),
                .control = control,
            } });
            assign.selected_control = null;
            assign.learned_param = null;
        }
    }
}

fn populateKnobValues(
    assign_state: *statemachine.AssignState,
    track: reaper.MediaTrack,
    track_state: *TrackState,
) void {
    const locs = track_state.getModuleLocations() orelse return;
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        if (locs.get(module)) |location| {
            if (location.mapping) |tagged_mapping| {
                const mapping = @field(tagged_mapping, @tagName(module));
                inline for (@typeInfo(@TypeOf(mapping)).@"struct".field_names) |field_name| {
                    if (comptime std.mem.eql(u8, field_name, "version")) continue;
                    if (comptime std.mem.eql(u8, field_name, "fx_preset")) continue;
                    if (@field(mapping, field_name)) |param_idx| {
                        const cc = @field(c1.CCs, field_name);
                        const val = pReaper.TrackFX_GetParamNormalized(.{ track, location.fx_index, param_idx });
                        if (val >= 0) {
                            assign_state.knob_values[@backingInt(cc)] = @floatCast(val);
                        }
                    }
                }
            }
        }
    }
}

/// The state of the plugin of a module as REAPER holds it now, which is the chunk of a VST, written as the data of a preset
/// of a user preset file: in hexadecimal, with its length in bytes. It is null when the plugin has no chunk (a JS or an AU
/// plugin), or when it cannot be read.
fn captureFxState(
    allocator: std.mem.Allocator,
    track_state: *const TrackState,
    current_tr_id: ?c_int,
    module: statemachine.ModulesList,
) ?preset_file_reader.EmbeddedPreset {
    const fx_index = track_state.fxIndexOf(module) orelse return null;
    const track_id = current_tr_id orelse return null;
    const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);

    // Because the size of a chunk is not known, the buffer grows until the text of the chunk fits in it.
    var size: usize = 1 << 16;
    const max_size: usize = 1 << 27;
    var encoded: []u8 = &.{};
    while (true) {
        if (size > max_size) return null;
        encoded = std.heap.page_allocator.alloc(u8, size) catch return null;
        @memset(encoded, 0);
        if (!reaper.TrackFX_GetNamedConfigParm(track, fx_index, "vst_chunk", @ptrCast(encoded.ptr), @intCast(size))) {
            std.heap.page_allocator.free(encoded);
            return null;
        }
        if (std.mem.indexOfScalar(u8, encoded, 0)) |text_len| {
            if (text_len + 1 < size) {
                encoded = encoded[0..text_len];
                break;
            }
        }
        std.heap.page_allocator.free(encoded.ptr[0..size]);
        size *= 4;
    }
    defer std.heap.page_allocator.free(encoded.ptr[0..size]);

    const converted = chunkToPresetData(allocator, encoded) orelse return null;

    var preset_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    reaper.TrackFX_GetUserPresetFilename(track, fx_index, @ptrCast(&preset_path_buf), @intCast(preset_path_buf.len));
    const preset_full_path: [:0]const u8 = std.mem.span(@as([*:0]const u8, &preset_path_buf));
    if (preset_full_path.len == 0) return null;
    const preset_filename_z: [:0]const u8 = allocator.dupeSentinel(u8, std.fs.path.basename(preset_full_path), 0) catch return null;

    return preset_file_reader.EmbeddedPreset{
        .file = preset_filename_z,
        .data = converted.data,
        .len = converted.len,
    };
}

/// The name that the save dialog proposes for the map file of a plugin: the name of the plugin without its type, in which the
/// characters that a file name cannot have are replaced, with ".ini" at its end.
fn defaultMapFileName(buf: *[160:0]u8, fx_name: []const u8) [:0]const u8 {
    const extension = ".ini";
    const limit = buf.len - extension.len;
    var name = fx_name;
    // Because REAPER writes the type of a plugin before its name ("VST3: ReaComp"), the type is dropped when it is one word.
    if (std.mem.indexOf(u8, name, ": ")) |colon| {
        const type_name = name[0..colon];
        const is_type = colon > 0 and colon <= 6 and for (type_name) |char| {
            if (!std.ascii.isAlphanumeric(char)) break false;
        } else true;
        if (is_type) name = name[colon + 2 ..];
    }
    var length: usize = 0;
    for (name) |char| {
        if (length >= limit) break;
        const invalid = char < 32 or std.mem.indexOfScalar(u8, "/\\:*?\"<>|", char) != null;
        buf[length] = if (invalid) '_' else char;
        length += 1;
    }
    // Because a name cannot start or end with a space or a dot, they are dropped.
    const trimmed = std.mem.trim(u8, buf[0..length], " .");
    if (trimmed.len == 0) {
        @memcpy(buf[0.."default".len], "default");
        length = "default".len;
    } else {
        std.mem.copyForwards(u8, buf[0..trimmed.len], trimmed);
        length = trimmed.len;
    }
    @memcpy(buf[length..][0..extension.len], extension);
    buf[length + extension.len] = 0;
    return buf[0 .. length + extension.len :0];
}

test "defaultMapFileName: the type of the plugin is dropped, and what a file name cannot have is replaced" {
    var buf: [160:0]u8 = undefined;
    try std.testing.expectEqualStrings("ReaComp (Cockos).ini", defaultMapFileName(&buf, "VST: ReaComp (Cockos)"));
    try std.testing.expectEqualStrings("Volume_Pan Smoother v5.ini", defaultMapFileName(&buf, "JS: Volume/Pan Smoother v5"));
    try std.testing.expectEqualStrings("Pro-Q 3.ini", defaultMapFileName(&buf, "VST3: Pro-Q 3"));
    // A colon that is not after a type is part of the name, and is replaced.
    try std.testing.expectEqualStrings("Some Long Name_ v2.ini", defaultMapFileName(&buf, "Some Long Name: v2"));
}

test "defaultMapFileName: a name that has nothing left is default, and a long one is cut" {
    var buf: [160:0]u8 = undefined;
    try std.testing.expectEqualStrings("default.ini", defaultMapFileName(&buf, ""));
    try std.testing.expectEqualStrings("default.ini", defaultMapFileName(&buf, "VST: ..."));
    const long: [400]u8 = @splat('x');
    const name = defaultMapFileName(&buf, &long);
    try std.testing.expect(name.len <= buf.len);
    try std.testing.expect(std.mem.endsWith(u8, name, ".ini"));
}

const PresetData = struct { data: [:0]const u8, len: u32 };

/// Turns the chunk of a plugin as REAPER gives it, which is base64 in lines that may be broken, into the data of a preset of a
/// user preset file: the same bytes in hexadecimal, and their count. It is null when the text is not a chunk.
fn chunkToPresetData(allocator: std.mem.Allocator, encoded: []const u8) ?PresetData {
    var clean: std.ArrayList(u8) = .empty;
    defer clean.deinit(std.heap.page_allocator);
    for (encoded) |char| {
        if (char == '\n' or char == '\r' or char == ' ') continue;
        clean.append(std.heap.page_allocator, char) catch return null;
    }
    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(clean.items) catch return null;
    if (decoded_len == 0) return null;
    const decoded = std.heap.page_allocator.alloc(u8, decoded_len) catch return null;
    defer std.heap.page_allocator.free(decoded);
    decoder.decode(decoded, clean.items) catch return null;

    const hex_digits = "0123456789ABCDEF";
    const data = allocator.allocSentinel(u8, decoded_len * 2, 0) catch return null;
    for (decoded, 0..) |byte, i| {
        data[i * 2] = hex_digits[byte >> 4];
        data[i * 2 + 1] = hex_digits[byte & 0x0F];
    }
    return .{ .data = data, .len = @intCast(decoded_len) };
}

test "chunkToPresetData: the bytes of a chunk are written in hexadecimal with their count, as a preset file has them" {
    // The first bytes of the chunk of ReaComp, which a preset of ReaComp starts with too: "mcer", then 0xFEED5EEF.
    const converted = chunkToPresetData(std.testing.allocator, "bWNlcu9e7f4=").?;
    defer std.testing.allocator.free(converted.data);
    try std.testing.expectEqualStrings("6D636572EF5EEDFE", converted.data);
    try std.testing.expectEqual(@as(u32, 8), converted.len);
}

test "chunkToPresetData: lines of a broken chunk are joined, and text that is not a chunk is refused" {
    const converted = chunkToPresetData(std.testing.allocator, "bWNl\ncg==\n").?;
    defer std.testing.allocator.free(converted.data);
    try std.testing.expectEqualStrings("6D636572", converted.data);
    try std.testing.expect(chunkToPresetData(std.testing.allocator, "") == null);
    try std.testing.expect(chunkToPresetData(std.testing.allocator, "!!!") == null);
}

// Because the native save dialog can return any path on the filesystem, we
// validate that the result is inside the maps directory. A bare startsWith
// check would incorrectly accept paths like "/path/to/maps_backup/file.ini",
// so we also verify that the character after the prefix is a path separator
// (or that the path equals the root exactly).
fn isInsideMapsDir(path: []const u8, maps_root: []const u8) bool {
    std.debug.assert(maps_root.len > 0 and maps_root[maps_root.len - 1] != std.fs.path.sep);
    if (!std.mem.startsWith(u8, path, maps_root)) return false;
    return path.len == maps_root.len or path[maps_root.len] == std.fs.path.sep;
}

test "isInsideMapsDir: path inside maps root is accepted" {
    try std.testing.expect(isInsideMapsDir("/path/to/maps/factory/comp/default.ini", "/path/to/maps"));
}

test "isInsideMapsDir: path outside maps root is rejected" {
    try std.testing.expect(!isInsideMapsDir("/Users/desktop/file.ini", "/path/to/maps"));
}

test "isInsideMapsDir: prefix-but-not-child is rejected" {
    try std.testing.expect(!isInsideMapsDir("/path/to/maps_backup/file.ini", "/path/to/maps"));
}

test "isInsideMapsDir: exact root path is accepted" {
    try std.testing.expect(isInsideMapsDir("/path/to/maps", "/path/to/maps"));
}
