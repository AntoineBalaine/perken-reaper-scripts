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
    assign_add_mapping: struct { param: u8, control: c1.CCs },
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
            var browse_state = statemachine.BrowseState{};

            // Because we need to populate available_modules from track_state.module_locations,
            // we iterate through the ModuleLocations and build the available_modules array
            inline for (std.meta.fields(ModulesList), 0..) |field, i| {
                const module = @field(ModulesList, field.name);
                if (globals.state.fx_ctrl.track_state.module_locations.get(module)) |_| {
                    // Because we have a location for this module, we get the FX name
                    // For now, we use a simple placeholder - the actual implementation
                    // would need to query REAPER for the FX name at the FX index
                    browse_state.available_modules[i] = @tagName(module);
                } else {
                    browse_state.available_modules[i] = null;
                }
            }

            globals.state.mapping_panel.mode = .{ .browse = browse_state };
        },

        .enter_assign => |module| {
            var assign_state = statemachine.AssignState{
                .current_mappings = switch (module) {
                    .INPUT => .{ .INPUT = mappings.Inpt{} },
                    .GATE => .{ .GATE = mappings.Shp{} },
                    .EQ => .{ .EQ = mappings.Eq{} },
                    .COMP => .{ .COMP = mappings.Comp{} },
                    .OUTPT => .{ .OUTPT = mappings.Outpt{} },
                },
            };

            // Because we need to load FX parameters and initialize assign_state with current mappings,
            // we get the FX from the track_state module_locations
            if (globals.state.fx_ctrl.track_state.module_locations.get(module)) |location| {
                // Query FX name from REAPER
                const track = reaper.CSurf_TrackFromID(globals.state.current_tr_id orelse return, constants.g_csurf_mcpmode);
                var fx_name_buf: [256:0]u8 = undefined;
                _ = reaper.TrackFX_GetFXName(track, location.fx_index, &fx_name_buf, fx_name_buf.len);
                const fx_name_z = std.mem.sliceTo(&fx_name_buf, 0);
                const fx_name = globals.arena.dupeZ(u8, fx_name_z) catch return;
                assign_state.target_fx = fx_name;
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
            // Because we need assign_state data to initialize save mode, we get it from the current mode
            const assign_state = globals.state.mapping_panel.mode.assign;

            var save_state = statemachine.SaveState.init(globals.arena);

            // Because we need to preserve assign_state data for save_confirm, we copy it
            save_state.target_fx = assign_state.target_fx;
            save_state.current_mappings = assign_state.current_mappings;

            // Because we need to load existing preset names, we use mapping_browser.getMappingNames
            const module = std.meta.activeTag(assign_state.current_mappings);
            const fx_name = assign_state.target_fx;

            // Because getMappingNames requires a null-terminated string, we need to convert fx_name
            const fx_name_z = globals.arena.dupeZ(u8, fx_name) catch |err| {
                log.warn("Failed to allocate null-terminated FX name: {}", .{err});
                return;
            };

            const preset_names = mapping_browser.getMappingNames(
                globals.arena,
                globals.resource_path,
                fx_name_z,
                module,
            ) catch |err| {
                log.warn("Failed to load existing preset names: {}", .{err});
                return;
            };

            // Because getMappingNames returns owned strings, we add them to the list
            for (preset_names) |name| {
                save_state.existing_presets.append(name) catch |err| {
                    log.warn("Failed to append preset name: {}", .{err});
                };
            }

            globals.state.mapping_panel.mode = .{ .save = save_state };
        },

        .exit_to_fx_ctrl => {
            // Clean up mapping panel
            if (globals.mapping_panel) |*panel| {
                panel.deinit();
                globals.mapping_panel = null;
            }
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
            globals.state.mapping_panel.mode.assign.selected_control = maybe_control;
        },

        .assign_toggle_midi_learn => {
            log.debug("MIDI learn {s}", .{if (globals.state.mapping_panel.mode.assign.midi_learn_active) "disabled" else "enabled"});
            globals.state.mapping_panel.mode.assign.midi_learn_active = !globals.state.mapping_panel.mode.assign.midi_learn_active;
            if (!globals.state.mapping_panel.mode.assign.midi_learn_active) {
                globals.state.mapping_panel.mode.assign.selected_control = null;
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
                    .Inpt_phase_inv => input.Inpt_phase_inv = mapping.param,
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
                    .Inpt_phase_inv => input.Inpt_phase_inv = null,
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
            globals.state.mapping_panel.mode.assign.current_mappings = switch (new_module) {
                .INPUT => .{ .INPUT = mappings.Inpt{} },
                .GATE => .{ .GATE = mappings.Shp{} },
                .EQ => .{ .EQ = mappings.Eq{} },
                .COMP => .{ .COMP = mappings.Comp{} },
                .OUTPT => .{ .OUTPT = mappings.Outpt{} },
            };
        },

        .assign_request_save => {
            mappingPanelActions(globals, .enter_save);
        },

        .assign_cancel => {
            mappingPanelActions(globals, .exit_to_fx_ctrl);
        },

        // SAVE sub-mode actions
        .save_update_name => |name| {
            // Because we need to update the name buffer, we copy the name
            const copy_len = @min(name.len, globals.state.mapping_panel.mode.save.name_buffer.len - 1);
            @memcpy(globals.state.mapping_panel.mode.save.name_buffer[0..copy_len], name[0..copy_len]);
            globals.state.mapping_panel.mode.save.name_buffer[copy_len] = 0;
            globals.state.mapping_panel.mode.save.name_len = copy_len;
        },

        .save_confirm => |mapping_name| {
            const fx_name = globals.state.mapping_panel.mode.save.target_fx;
            log.debug("Saved mappings for FX: {s}", .{fx_name});

            // Because saveToFile requires null-terminated strings, we need to convert fx_name
            const fx_name_z = globals.arena.dupeZ(u8, fx_name) catch |err| {
                log.warn("Failed to allocate null-terminated FX name: {}", .{err});
                return;
            };

            // Because we need to save the mapping to disk, we extract the module and convert to TaggedMapping
            const module = std.meta.activeTag(globals.state.mapping_panel.mode.save.current_mappings);
            const tagged_mapping: TaggedMapping = switch (globals.state.mapping_panel.mode.save.current_mappings) {
                .INPUT => |m| .{ .INPUT = m },
                .GATE => |m| .{ .GATE = m },
                .EQ => |m| .{ .EQ = m },
                .COMP => |m| .{ .COMP = m },
                .OUTPT => |m| .{ .OUTPT = m },
            };

            globals.map_store.saveToFile(
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
