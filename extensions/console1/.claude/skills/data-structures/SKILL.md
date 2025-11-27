---
name: data-structures
description: Understand key data structures in the REAPER Console1 extension, including action unions, state structures, and mapping types. Use when working with src/statemachine.zig, src/actions.zig, or any state-related code.
---

# Data Structures

This skill explains the key data structures used throughout the REAPER Console1 extension. These structures form the foundation of the event handling system, state management, and communication between different parts of the application.

## Console1 Control Enumeration

The CCs enumeration in src/c1.zig defines all the MIDI continuous controller numbers used by the Console1 hardware. The enumeration includes compressor controls (Comp_Attack, Comp_DryWet, Comp_Ratio, Comp_Release, Comp_Thresh, Comp_comp), EQ controls (Eq_HiFrq, Eq_HiGain, Eq_HiMidFrq, Eq_HiMidGain, Eq_HiMidQ, Eq_LoFrq, Eq_LoGain, Eq_LoMidFrq, Eq_LoMidGain, Eq_LoMidQ, Eq_eq, Eq_hp_shape, Eq_lp_shape), input controls (Inpt_Gain, Inpt_HiCut, Inpt_LoCut, Inpt_disp_mode, Inpt_disp_on, Inpt_filt_to_comp, Inpt_phase_inv, Inpt_preset), output controls (Out_Drive, Out_DriveChar, Out_Pan, Out_Vol, Out_mute, Out_solo), gate controls (Shp_Gate, Shp_GateRelease, Shp_Punch, Shp_hard_gate, Shp_shape, Shp_sustain), and track controls (Tr_ext_sidechain, Tr_order, Tr_pg_dn, Tr_pg_up, Tr_tr1 through Tr_tr20, Tr_tr_copy, Tr_tr_grp).

Each enumeration value corresponds to a specific MIDI CC number that the Console1 hardware sends when a control is manipulated.

## Mode Action Unions

The ModeAction union in src/actions.zig serves as the top-level action type for the dispatch system. This union contains variants for each mode-specific action set as well as cross-cutting actions. The variants include fx_ctrl for FX control actions, fx_sel for FX selection actions, transport for transport control actions, mapping for mapping panel actions, settings for settings actions, default_fx_sel for default FX selection actions, Csurf for control surface callback actions, change_mode for mode transitions, set_fx_ctrl_gui for GUI visibility control, track_list for track list actions, and midi_out for MIDI feedback actions.

Each mode-specific variant contains its own action union that defines the available actions for that mode. For example, FxCtrlAction in src/fx_ctrl_actions.zig defines actions like midi_input for handling MIDI CC messages, on_track_entry for track selection changes, toggle_fx_window for showing plugin UIs, and panel_input for GUI interactions.

## State Structures

The State structure in src/statemachine.zig contains the global application state. This structure holds the current_mode field indicating which mode is active, mode-specific state structures for each mode, and shared state accessible across modes.

The FxControlState structure in src/fx_ctrl_state.zig maintains the state for FX control mode. It contains a track_state field holding information about the current track's FX chain, a values field storing current parameter values for all Console1 controls, and a last_focus field tracking which parameter was last touched.

The TrackState structure in src/track_state.zig represents the state of a single track in REAPER. It includes module_locations mapping each module to its FX index and parameter mapping, routing information for sidechain configuration, and order information for the FX processing chain.

## Parameter Value Types

The FxControlState.values field uses a C1Value union to represent different types of control values. The union has four variants: param for continuous parameters with normalized and display values, button for toggle controls with boolean state, meter for level meters with current level and peak values, and unavailable for controls that are not currently mapped to any parameter.

This union structure allows the same Console1 control to represent different types of parameters depending on the assigned FX plugin.

## Event Logging Structures

The logger module in src/logger.zig defines structures for logging and debugging events. The Event union contains variants for different event types: state_change for mode transitions, midi_input for incoming MIDI messages, and parameter_update for FX parameter changes.

Each variant includes relevant data for that event type. The state_change variant stores the old mode and new mode. The midi_input variant stores the CC number and value. The parameter_update variant stores the module, parameter index, and new value.

The Event union implements a format function that renders events as human-readable strings for logging output. This allows events to be easily logged to the console or written to log files.

## Mapping Structures

The mapping structures in src/mappings.zig define how Console1 controls map to FX parameters. For each module category, there is a corresponding structure with optional u8 fields. For example, the Comp structure has fields for Comp_Attack, Comp_DryWet, Comp_Ratio, Comp_Release, Comp_Thresh, and Comp_comp, each representing the FX parameter index assigned to that control.

The optional nature of these fields allows for partial mappings where only some controls are assigned. A null value indicates that a control is not mapped to any parameter for that plugin.

The TaggedMapping union wraps these module-specific mapping structures and tags them with the module type. This allows the application to store and pass around mappings without losing information about which module they belong to.

## Control Surface Event Structures

The CsurfAction union in src/csurf_actions.zig defines events that arrive from the REAPER control surface API. These events notify the extension of changes in the DAW state. The variants include track_selected for track selection changes, last_touched_track for focus changes, play_state_changed for transport state changes, fx_chain_changed for FX addition or removal, fx_param_changed for parameter automation changes, and fx_window_state for plugin window open/close events.

The ParamChg and WinChg helper structures contain detailed information about parameter changes and window state changes respectively. These structures include the track pointer, FX index, and relevant values for the change.

## Module Location Structure

The ModuleLocation structure in src/track_state.zig represents the location and mapping information for a module on a track. It contains the fx_index field indicating where in the FX chain the module's plugin is located, and the mapping field containing the parameter mapping for that plugin.

The track_state structure maintains an EnumMap of ModuleLocation values keyed by module type, allowing quick lookup of where each module's plugin is located on the current track.

## GUI Return Types

Many GUI functions return optional action unions to indicate user interactions. For example, the mapping panel GUI functions return optional MappingAction values when the user clicks buttons or selects items. This pattern allows GUI code to remain decoupled from the action dispatch system. The GUI simply returns what the user did, and the caller is responsible for dispatching the appropriate action.

## Enumerations for Configuration

Several enumerations define configuration options throughout the application. The ModulesList enumeration in src/statemachine.zig lists the five module categories. The Mode enumeration lists all operational modes. The AutomationMode enumeration in src/transport_actions.zig defines REAPER's automation modes.

These enumerations use Zig's compile-time reflection capabilities to enable generic iteration and mapping. For example, the code can iterate over all module types using std.enums.values(ModulesList) to perform operations on each module category.
