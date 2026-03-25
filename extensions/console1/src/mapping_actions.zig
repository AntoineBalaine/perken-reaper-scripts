const std = @import("std");
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const Globals = @import("globals.zig").Globals;
const mappings = @import("mappings.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.mapping_actions);
const TaggedMapping = mappings.TaggedMapping;
const reaper = @import("reaper.zig").reaper;
const constants = @import("constants.zig");
const utils = @import("utils.zig");
const pReaper = @import("pReaper.zig");
const TrackState = @import("track_state.zig");
const swell = @import("swell.zig");
const tr = @import("translations.zig").tr;

pub const MappingPanelAction = @import("action_types.zig").MappingPanelAction;

pub fn mappingPanelActions(globals: *Globals, action: MappingPanelAction) void {
    switch (action) {
        // Sub-mode transitions
        .enter_browse => {
            // Because we need to deinitialize the previous sub-state before entering browse,
            globals.state.mapping_panel.deinitCurrentSubMode();

            var browse_state = statemachine.BrowseState.init(globals.state.mapping_panel.gpa_int.allocator());
            const browse_allocator = browse_state.arena.allocator();

            inline for (std.meta.fields(ModulesList), 0..) |field, i| {
                const module = @field(ModulesList, field.name);
                if (module == .STRIP) continue;
                const module_name = @tagName(module);
                const phys: PhysicalModule = @enumFromInt(@intFromEnum(module));

                const loc_opt = switch (globals.state.fx_ctrl.track_state.mode) {
                    .multi_fx => |locs| locs.get(phys),
                    .channel_strip => null,
                };
                if (loc_opt) |location| {
                    if (globals.state.current_tr_id) |track_id| {
                        const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
                        var fx_name_buf: [512:0]u8 = undefined;
                        const success = reaper.TrackFX_GetFXName(track, location.fx_index, &fx_name_buf, fx_name_buf.len);
                        if (!success) {
                            browse_state.available_modules[i] = null;
                        } else {
                            const fx_name = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                            const formatted = std.fmt.allocPrintZ(browse_allocator, "{s}    [{s}]", .{ module_name, fx_name }) catch module_name;
                            browse_state.available_modules[i] = formatted;
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

        .enter_assign => |module| {
            // Because we need to deinitialize the previous sub-state before entering assign,
            globals.state.mapping_panel.deinitCurrentSubMode();

            const initial_mappings = TaggedMapping.empty(module);

            var assign_state = statemachine.AssignState.init(globals.state.mapping_panel.gpa_int.allocator(), initial_mappings);
            const assign_allocator = assign_state.arena.allocator();

            // Because the UI needs FX names for all modules (for the dropdown
            // and module headings), we cache them in assign_state so that the
            // rendering code doesn't need to call REAPER APIs.
            if (globals.state.current_tr_id) |track_id| {
                const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
                populateModuleFxNames(&assign_state, track, &globals.state.fx_ctrl.track_state, assign_allocator);
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
                    .multi_fx => |locs| if (locs.get(@as(PhysicalModule, @enumFromInt(@intFromEnum(phys))))) |loc| loc.fx_index else null,
                    .channel_strip => null,
                },
            };
            if (fx_index) |fxi| {
                const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id orelse return, constants.g_csurf_mcpmode);

                const params_length: usize = @intCast(reaper.TrackFX_GetNumParams(track, fxi));
                assign_state.param_store.clear();
                const param_allocator = assign_state.param_store.strings.arena.allocator();
                assign_state.param_store.params.ensureTotalCapacity(param_allocator, params_length) catch return;

                var prm_name_buf: [256:0]u8 = undefined;
                for (0..params_length) |i| {
                    const prm_idx: i32 = @intCast(i);
                    if (reaper.TrackFX_GetParamName(track, fxi, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                        const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
                        assign_state.param_store.addParam(prm_idx, param_name) catch return;
                    }
                }

                // Load the FX name for target_fx from REAPER
                if (module == .STRIP) {
                    var fx_name_buf: [512:0]u8 = undefined;
                    if (reaper.TrackFX_GetFXName(track, fxi, &fx_name_buf, fx_name_buf.len)) {
                        const fx_name = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                        assign_state.target_fx = assign_allocator.dupeZ(u8, fx_name) catch return;
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
                            if (locs.get(@as(PhysicalModule, @enumFromInt(@intFromEnum(phys))))) |loc| {
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
                populateKnobValues(&assign_state, track, &globals.state.fx_ctrl.track_state);
            }

            // Set target_fx from the cached name for the selected module.
            if (module != .STRIP) {
                const phys: PhysicalModule = @enumFromInt(@intFromEnum(module));
                if (assign_state.module_fx_names.get(phys)) |name| {
                    assign_state.target_fx = assign_allocator.dupeZ(u8, name) catch return;
                }
            }

            globals.state.mapping_panel.mode = .{ .assign = assign_state };
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
            globals.state.mapping_panel.mode.assign.selected_parameter = maybe_param;
        },

        .assign_select_control => |maybe_control| {
            log.debug("Selected control: {s}", .{if (maybe_control) |cc| @tagName(cc) else "none"});
            var assign = &globals.state.mapping_panel.mode.assign;
            assign.selected_control = maybe_control;
            // Because CC and param can arrive in any order, we check
            // whether both inputs are present and create the assignment.
            if (assign.midi_learn_active) {
                tryCompleteLearnAssignment(globals);
            }
        },

        .assign_toggle_midi_learn => {
            var assign = &globals.state.mapping_panel.mode.assign;
            assign.midi_learn_active = !assign.midi_learn_active;
            log.debug("MIDI learn {s}", .{if (assign.midi_learn_active) "enabled" else "disabled"});
            assign.selected_control = null;
            assign.learned_param = null;
        },

        .assign_midi_learned_param => |param_index| {
            var assign = &globals.state.mapping_panel.mode.assign;
            if (assign.midi_learn_active) {
                assign.learned_param = param_index;
                log.debug("MIDI learn: param {d} captured", .{param_index});
                tryCompleteLearnAssignment(globals);
            }
        },

        .assign_update_knob => |knob| {
            globals.state.mapping_panel.mode.assign.knob_values[@intFromEnum(knob.cc)] = knob.value;
        },

        .assign_add_mapping => |mapping| {
            log.debug("Added mapping: {s} -> param {d}", .{ @tagName(mapping.control), mapping.param });
            // Because we need to add the mapping to current_mappings based on module type,
            // we switch on the current_mappings union
            switch (globals.state.mapping_panel.mode.assign.current_mappings) {
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
                    inline for (std.meta.fields(mappings.ChannelStripMapping)) |field| {
                        if (comptime std.mem.eql(u8, field.name, "version")) continue;
                        if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;
                        if (std.mem.eql(u8, cc_name, field.name)) {
                            @field(strip, field.name) = mapping.param;
                        }
                    }
                },
            }
            globals.state.mapping_panel.mode.assign.selected_parameter = null;
        },

        .assign_remove_mapping => |control| {
            log.debug("Removed mapping for control: {s}", .{@tagName(control)});
            // Because we need to remove the mapping from current_mappings,
            // we switch on the union type
            switch (globals.state.mapping_panel.mode.assign.current_mappings) {
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
                    inline for (std.meta.fields(mappings.ChannelStripMapping)) |field| {
                        if (comptime std.mem.eql(u8, field.name, "version")) continue;
                        if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;
                        if (std.mem.eql(u8, cc_name, field.name)) {
                            @field(strip, field.name) = null;
                        }
                    }
                },
            }
        },

        .assign_change_module => |new_module| {
            var assign_state = &globals.state.mapping_panel.mode.assign;
            // Because changing module invalidates the current learn context,
            // we reset the selected control (but leave learn mode active
            // if it was on, so the user can keep learning on the new module).
            assign_state.selected_control = null;
            assign_state.learned_param = null;
            assign_state.current_mappings = TaggedMapping.empty(new_module);

            // Update target_fx from the cached module names.
            if (new_module == .STRIP) {
                assign_state.target_fx = "";
            } else if (assign_state.module_fx_names.get(@as(PhysicalModule, @enumFromInt(@intFromEnum(new_module))))) |name| {
                const alloc = assign_state.arena.allocator();
                assign_state.target_fx = alloc.dupeZ(u8, name) catch return;
            } else {
                assign_state.target_fx = "";
            }

            // Reload parameters for the new module
            const switch_loc = switch (new_module) {
                .STRIP => null,
                inline else => |phys| switch (globals.state.fx_ctrl.track_state.mode) {
                    .multi_fx => |locs| locs.get(@as(PhysicalModule, @enumFromInt(@intFromEnum(phys)))),
                    .channel_strip => null,
                },
            };
            if (switch_loc) |location| {
                if (globals.state.current_tr_id) |track_id| {
                    const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
                    const params_length: usize = @intCast(reaper.TrackFX_GetNumParams(track, location.fx_index));

                    assign_state.param_store.clear();
                    const param_allocator = assign_state.param_store.strings.arena.allocator();
                    assign_state.param_store.params.ensureTotalCapacity(param_allocator, params_length) catch return;

                    var prm_name_buf: [256:0]u8 = undefined;
                    for (0..params_length) |i| {
                        const prm_idx: i32 = @intCast(i);
                        if (reaper.TrackFX_GetParamName(track, location.fx_index, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                            const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
                            assign_state.param_store.addParam(prm_idx, param_name) catch return;
                        }
                    }
                }
            }
        },

        .assign_request_save => {
            const assign_state = &globals.state.mapping_panel.mode.assign;
            assign_state.save_error = null;

            // Build the maps root path for the initial directory
            var maps_root_buf: [std.fs.max_path_bytes:0]u8 = undefined;
            const maps_root = std.fmt.bufPrintZ(&maps_root_buf, "{s}{s}maps", .{
                @as([]const u8, globals.resource_path),
                std.fs.path.sep_str,
            }) catch return;

            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const dialog_title = tr(&globals.translations, .save_dialog_title);
            if (swell.browseForSaveFile(dialog_title, maps_root, "default.ini", "INI files\x00*.ini\x00", &path_buf)) |path| {
                if (!isInsideMapsDir(path, maps_root)) {
                    assign_state.save_error = .save_error_outside_maps;
                    return;
                }

                // Perform the save directly from assign state
                const fx_name = assign_state.target_fx;
                const module = std.meta.activeTag(assign_state.current_mappings);
                const tagged_mapping = assign_state.current_mappings;

                var save_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
                const save_path: [:0]const u8 = std.fmt.bufPrintZ(&save_path_buf, "{s}", .{path}) catch return;

                const basename = std.fs.path.basename(path);
                const alloc = assign_state.arena.allocator();
                const mapping_name: [:0]const u8 = alloc.dupeZ(u8, std.fs.path.stem(basename)) catch return;
                const fx_name_z: [:0]const u8 = alloc.dupeZ(u8, fx_name) catch return;

                globals.map_store.saveToFile(globals.fs_ops, module, fx_name_z, tagged_mapping, save_path) catch {
                    assign_state.save_error = .save_error_write_failed;
                    return;
                };

                globals.mappings_list.registerPath(module, fx_name_z, mapping_name, save_path) catch |err| {
                    log.warn("Failed to register saved mapping path: {}", .{err});
                };
                _ = globals.map_store.getMap(fx_name_z, module, mapping_name, &globals.mappings_list) catch |err| {
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
                        const phys_module: PhysicalModule = @enumFromInt(@intFromEnum(mod));
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

                mappingPanelActions(globals, .exit_to_fx_ctrl);
            }
        },

        .assign_cancel => {
            mappingPanelActions(globals, .exit_to_fx_ctrl);
        },
    }
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
            if (reaper.TrackFX_GetFXName(track, location.fx_index, &fx_name_buf, fx_name_buf.len)) {
                const fx_name = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                assign_state.module_fx_names.set(module, allocator.dupeZ(u8, fx_name) catch null);
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
    var assign = &globals.state.mapping_panel.mode.assign;
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
                inline for (std.meta.fields(@TypeOf(mapping))) |field| {
                    if (comptime std.mem.eql(u8, field.name, "version")) continue;
                    if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;
                    if (@field(mapping, field.name)) |param_idx| {
                        const cc = @field(c1.CCs, field.name);
                        const val = pReaper.TrackFX_GetParamNormalized(.{ track, location.fx_index, param_idx });
                        if (val >= 0) {
                            assign_state.knob_values[@intFromEnum(cc)] = @floatCast(val);
                        }
                    }
                }
            }
        }
    }
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
