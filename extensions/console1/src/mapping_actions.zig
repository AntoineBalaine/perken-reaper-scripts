const std = @import("std");
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const Globals = @import("globals.zig").Globals;
const mappings = @import("mappings.zig");
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.mapping_actions);
const TaggedMapping = mappings.TaggedMapping;
const mapping_browser = @import("mapping_browser.zig");
const reaper = @import("reaper.zig").reaper;
const constants = @import("constants.zig");

pub const MappingPanelAction = union(enum) {
    // Sub-mode transitions
    enter_browse: void,
    enter_assign: ModulesList,
    enter_save: void,
    exit_to_fx_ctrl: void,

    // BROWSE sub-mode actions
    browse_scroll: u8,
    browse_select_module: ModulesList,
    browse_confirm: void,
    browse_cancel: void,

    // ASSIGN sub-mode actions
    assign_select_parameter: ?u32,
    assign_select_control: ?c1.CCs,
    assign_toggle_midi_learn: void,
    assign_add_mapping: struct { param: u16, control: c1.CCs },
    assign_midi_learned_param: u32,
    assign_remove_mapping: c1.CCs,
    assign_change_module: ModulesList,
    assign_request_save: void,
    assign_cancel: void,

    // SAVE sub-mode actions
    save_update_name: []const u8,
    save_confirm: [:0]const u8,
    save_cancel: void,
};

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
                const module_name = @tagName(module);

                if (globals.state.fx_ctrl.track_state.module_locations.get(module)) |location| {
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

            const initial_mappings = switch (module) {
                .INPUT => statemachine.ModuleMappings{ .INPUT = mappings.Inpt{} },
                .GATE => statemachine.ModuleMappings{ .GATE = mappings.Shp{} },
                .EQ => statemachine.ModuleMappings{ .EQ = mappings.Eq{} },
                .COMP => statemachine.ModuleMappings{ .COMP = mappings.Comp{} },
                .OUTPT => statemachine.ModuleMappings{ .OUTPT = mappings.Outpt{} },
            };

            var assign_state = statemachine.AssignState.init(globals.state.mapping_panel.gpa_int.allocator(), initial_mappings);
            const assign_allocator = assign_state.arena.allocator();

            // Because we need to load FX parameters and initialize assign_state with current mappings,
            // we get the FX from the track_state module_locations
            if (globals.state.fx_ctrl.track_state.module_locations.get(module)) |location| {
                // Query FX name from REAPER
                const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id orelse return, constants.g_csurf_mcpmode);
                var fx_name_buf: [256:0]u8 = undefined;
                const success = reaper.TrackFX_GetFXName(track, location.fx_index, &fx_name_buf, fx_name_buf.len);
                if (!success) {
                    log.warn("Failed to get FX name for module {s}, fx_index: {d}", .{ @tagName(module), location.fx_index });
                    return;
                }
                const fx_name_z = std.mem.span(@as([*:0]const u8, &fx_name_buf));
                const fx_name = assign_allocator.dupeZ(u8, fx_name_z) catch return;
                assign_state.target_fx = fx_name;

                // Because we need to load FX parameters for the panel, we query them from REAPER
                const params_length: usize = @intCast(reaper.TrackFX_GetNumParams(track, location.fx_index));
                assign_state.param_store.clear(); // reuse capacity from previous load
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

                // Load the mapping if it exists
                if (location.mapping) |tagged_mapping| {
                    assign_state.current_mappings = switch (tagged_mapping) {
                        .INPUT => |m| .{ .INPUT = m },
                        .GATE => |m| .{ .GATE = m },
                        .EQ => |m| .{ .EQ = m },
                        .COMP => |m| .{ .COMP = m },
                        .OUTPT => |m| .{ .OUTPT = m },
                    };
                }
            }

            globals.state.mapping_panel.mode = .{ .assign = assign_state };
        },

        .enter_save => {
            const assign_state = globals.state.mapping_panel.mode.assign;
            const module = std.meta.activeTag(assign_state.current_mappings);
            const fx_name = assign_state.target_fx; // Still a pointer, but we'll use it immediately
            const current_mappings = assign_state.current_mappings;

            // Create new save state with new arena
            var save_state = statemachine.SaveState.init(globals.state.mapping_panel.gpa_int.allocator(), current_mappings);
            const save_allocator = save_state.arena.allocator();

            // Copy string data WHILE assign_state is still valid
            save_state.target_fx = save_allocator.dupeZ(u8, fx_name) catch return;

            // Initialize name_buffer
            _ = std.fmt.bufPrintZ(&save_state.name_buffer, "default", .{}) catch return;

            // Get preset names (using the copied fx_name would be safer, but we do it before deinit)
            const fx_name_z = save_allocator.dupeZ(u8, fx_name) catch |err| {
                log.warn("Failed to allocate null-terminated FX name: {}", .{err});
                return;
            };

            const preset_names = mapping_browser.getMappingNames(
                save_allocator,
                globals.resource_path,
                fx_name_z,
                module,
            ) catch |err| {
                log.warn("Failed to load existing preset names: {}", .{err});
                return;
            };

            for (preset_names) |name| {
                save_state.existing_presets.append(save_allocator, name) catch |err| {
                    log.warn("Failed to append preset name: {}", .{err});
                };
            }

            globals.state.mapping_panel.deinitCurrentSubMode();

            globals.state.mapping_panel.mode = .{ .save = save_state };
        },

        .exit_to_fx_ctrl => {
            dispatch(globals, .{ .change_mode = .fx_ctrl });
        },

        // BROWSE sub-mode actions
        .browse_scroll => |encoder_val| {
            globals.state.mapping_panel.mode.browse.scroll_position_abs = encoder_val;
            // Update relative position (simplified, actual implementation may vary)
            globals.state.mapping_panel.mode.browse.scroll_position_rel = encoder_val;
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
            // Because the CC was captured from hardware during MIDI learn,
            // we transition from listening-for-CC to listening-for-param.
            if (assign.midi_learn == .listening_cc) {
                assign.midi_learn = .listening_param;
            }
        },

        .assign_toggle_midi_learn => {
            var assign = &globals.state.mapping_panel.mode.assign;
            log.debug("MIDI learn {s}", .{if (assign.midi_learn == .listening_cc) "disabled" else "enabled"});
            switch (assign.midi_learn) {
                .idle, .listening_param => {
                    // Because we're either starting fresh or restarting after
                    // a CC capture, we enter listening-for-CC mode.
                    assign.midi_learn = .listening_cc;
                    assign.selected_control = null;
                },
                .listening_cc => {
                    // Because the user toggled off while listening, we cancel.
                    assign.midi_learn = .idle;
                    assign.selected_control = null;
                },
            }
        },

        .assign_midi_learned_param => |param_index| {
            var assign = &globals.state.mapping_panel.mode.assign;
            // Because this action should only fire during the listening-for-param
            // phase, we guard on both the phase and having a captured CC.
            if (assign.midi_learn == .listening_param) {
                if (assign.selected_control) |control| {
                    log.debug("MIDI learn complete: {s} -> param {d}", .{ @tagName(control), param_index });
                    mappingPanelActions(globals, .{ .assign_add_mapping = .{
                        .param = @intCast(param_index),
                        .control = control,
                    } });
                    assign.selected_control = null;
                    assign.midi_learn = .idle;
                }
            }
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
            }
            // Clear selections after mapping
            globals.state.mapping_panel.mode.assign.selected_parameter = null;
            globals.state.mapping_panel.mode.assign.selected_control = null;
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
            }
        },

        .assign_change_module => |new_module| {
            var assign_state = &globals.state.mapping_panel.mode.assign;
            // Because changing module invalidates the current learn context,
            // we reset the MIDI learn state.
            assign_state.midi_learn = .idle;
            assign_state.selected_control = null;
            assign_state.current_mappings = switch (new_module) {
                .INPUT => .{ .INPUT = mappings.Inpt{} },
                .GATE => .{ .GATE = mappings.Shp{} },
                .EQ => .{ .EQ = mappings.Eq{} },
                .COMP => .{ .COMP = mappings.Comp{} },
                .OUTPT => .{ .OUTPT = mappings.Outpt{} },
            };

            // Reload parameters for the new module
            if (globals.state.fx_ctrl.track_state.module_locations.get(new_module)) |location| {
                if (globals.state.current_tr_id) |track_id| {
                    const track = reaper.CSurf_TrackFromID(track_id, constants.g_csurf_mcpmode);
                    const params_length: usize = @intCast(reaper.TrackFX_GetNumParams(track, location.fx_index));

                    assign_state.param_store.clear(); // clear previous module's params
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
            mappingPanelActions(globals, .enter_save);
        },

        .assign_cancel => {
            mappingPanelActions(globals, .exit_to_fx_ctrl);
        },

        // SAVE sub-mode actions
        .save_update_name => |name| {
            _ = std.fmt.bufPrintZ(&globals.state.mapping_panel.mode.save.name_buffer, "{s}", .{name}) catch return;
        },

        .save_confirm => |mapping_name| {
            const save_state = &globals.state.mapping_panel.mode.save;
            const fx_name = save_state.target_fx;
            log.debug("Saved mappings for FX: {s}", .{fx_name});

            // Because saveToFile requires null-terminated strings, we need to convert fx_name
            const save_allocator = save_state.arena.allocator();
            const fx_name_z = save_allocator.dupeZ(u8, fx_name) catch |err| {
                log.warn("Failed to allocate null-terminated FX name: {}", .{err});
                return;
            };

            // Because we need to save the mapping to disk, we extract the module and convert to TaggedMapping
            const module = std.meta.activeTag(save_state.current_mappings);
            const tagged_mapping: TaggedMapping = switch (save_state.current_mappings) {
                .INPUT => |m| .{ .INPUT = m },
                .GATE => |m| .{ .GATE = m },
                .EQ => |m| .{ .EQ = m },
                .COMP => |m| .{ .COMP = m },
                .OUTPT => |m| .{ .OUTPT = m },
            };

            globals.map_store.saveToFile(
                globals.fs_ops,
                module,
                fx_name_z,
                tagged_mapping,
                mapping_name,
            ) catch {
                log.warn("Failed to save mapping {s} to file", .{fx_name});
                // Continue with cleanup even if save failed
            };

            // Because saveToFile only writes to disk, we need to add the mapping to cache manually
            // We use getMap to load it from disk which will also update the cache
            _ = globals.map_store.getMap(fx_name_z, module, mapping_name) catch |err| {
                log.warn("Failed to load saved mapping into cache: {}", .{err});
            };

            // Update module_locations so FX control mode uses the new mapping immediately
            if (globals.state.fx_ctrl.track_state.module_locations.get(module)) |existing_loc| {
                globals.state.fx_ctrl.track_state.module_locations.set(module, .{
                    .fx_index = existing_loc.fx_index,
                    .mapping = tagged_mapping,
                });
            }

            // Exit to FX control mode
            mappingPanelActions(globals, .exit_to_fx_ctrl);
        },

        .save_cancel => {
            // Because we want to return to assign mode, we get the current module from save_state
            const current_module = std.meta.activeTag(globals.state.mapping_panel.mode.save.current_mappings);
            mappingPanelActions(globals, .{ .enter_assign = current_module });
        },
    }
}
