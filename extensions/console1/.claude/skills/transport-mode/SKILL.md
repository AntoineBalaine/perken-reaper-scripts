---
name: transport-mode
description: Understand the transport mode in the REAPER Console1 extension. Use when working with playback control, transport actions, or REAPER DAW integration in src/transport_actions.zig.
---

# Transport Mode

This skill explains how the transport mode works in the REAPER Console1 extension. The transport mode provides comprehensive control over REAPER's transport, navigation, and global project settings directly from the Console1 hardware controller.

## Overview

The transport mode translates MIDI Control Change messages from the Console1 into specific REAPER actions, leveraging the existing Control Surface API integration and the central dispatch system. The mode aims to expose REAPER functionalities including transport control (play, stop, record, loop toggle, loop start/end setting), navigation (jogging with and without grid/snap, navigating markers, and navigating media items), zoom (horizontal and vertical zooming of the arrange view), global settings (adjusting automation mode, grid size, snap toggle, and play rate), and track selection within the REAPER project.

## State Structure

The TransportState structure is defined in src/transport_actions.zig and stores the current state of various transport-related controls. Since Console1 CCs send absolute values between 0 and 127, these fields typically hold the last received absolute value to calculate a delta for relative actions such as jogging and zooming using the calculateNewScrollPosition utility function.

The structure contains fields for jog (transport position jog), jog_item (media item navigation), jog_marker (marker navigation), zoom_horizontal and zoom_vertical (arrange view zoom controls), rate (playback rate), tr_sel (track selection), and grid (grid size).

## Transport Actions

The TransportAction union is defined in src/transport_actions.zig and enumerates all possible actions that can be performed within the transport mode, triggered by MIDI input from the Console1. The actions include automation_mode for setting REAPER's automation mode, grid for adjusting grid size, snap_tgl for toggling snap on/off, jog for jogging transport position, jog_item for navigating between media items, jog_marker for navigating between markers, loop_end and loop_start for setting loop boundaries, loop_toggle for enabling/disabling loop, marker_set for inserting markers, play for starting playback, rate for adjusting playback rate, rec for starting recording, rec_arm for arming tracks for recording, scrub for audio scrubbing, stop for stopping playback, tr_sel for selecting tracks, and zoom_horizontal and zoom_vertical for zooming the arrange view.

## Module Interactions

MIDI input is handled in src/csurf/midi_events.zig. When the plugin's current_mode is transport, the OnMidiEvent function intercepts incoming Console1 MIDI CC messages. Each recognized CC is mapped to a specific TransportAction variant. The actions.dispatch function is then called with the appropriate TransportAction.

The central dispatch function in src/actions.zig receives the TransportAction and calls the transportAction function from src/transport_actions.zig to execute the specific transport logic. The transportAction function contains a switch statement that handles each TransportAction variant. It updates the internal TransportState, calls the appropriate REAPER API functions via pReaper.zig or reaper.zig to perform the desired action in the DAW, uses utils.calculateNewScrollPosition to determine the delta from the absolute MIDI CC value for actions involving relative changes, and dispatches MidiOutAction values to send feedback to the Console1, updating its LEDs.

The REAPER API interface in src/pReaper.zig provides a Zig-idiomatic wrapper around the raw REAPER C API. The transportAction function uses functions like pReaper.Main_OnCommand for generic REAPER commands, pReaper.CSurf_OnRewFwd, pReaper.CSurf_OnZoom, pReaper.CSurf_OnPlayRateChange, and pReaper.CSurf_OnPlay to interact with REAPER's core functionality.

Utility functions in src/utils.zig, particularly utils.calculateNewScrollPosition, are crucial for translating absolute MIDI CC values into meaningful relative changes for continuous controls like jog, zoom, and rate.

MIDI output in src/midi_out.zig receives MidiOutAction values dispatched by transportAction to send MIDI messages back to the Console1, primarily for updating the LED feedback.

## Console1 Control Mappings

The following Console1 CCs are mapped to Transport mode actions as defined in src/csurf/midi_events.zig:

Inpt_HiCut adjusts play rate. Inpt_disp_mode switches to FX Control mode. Inpt_disp_on toggles FX Control GUI visibility. Tr_tr1 through Tr_tr5 toggle module browsers for INPUT, GATE, EQ, COMP, and OUTPT respectively. Tr_tr6 through Tr_tr10 set automation modes to trim, read, latch, preview, and write. Tr_tr17, Tr_tr18, and Tr_tr19 control play, stop, and record transport functions. Tr_tr20 opens the Settings panel. Eq_eq toggles loop. Eq_lp_shape and Eq_hp_shape set loop start and end points. Eq_LoGain provides scrub functionality (currently commented out in transportAction). Eq_LoMidGain, Eq_HiMidGain, and Eq_HiGain handle jogging of transport position, markers, and media items respectively. Comp_comp inserts markers. Out_Vol selects tracks. Out_Drive and Out_DriveChar control horizontal and vertical zoom. Out_Pan adjusts grid size. Out_solo toggles snap.

## Known Issues and Debugging Areas

The transport mode has been identified as very buggy. The jogging with grid/snap functionality is particularly complex and susceptible to errors. The logic involves saving and restoring snap state, calculating grid durations, and snapping to grid lines. This area is highly susceptible to off-by-one errors in calculations for next_pos or pos when iterating grid lines, floating-point inaccuracies in comparisons and arithmetic with f64 for time positions, edge cases at project start/end, with very small grid divisions, or unusual tempo/time signature changes, and incorrect interaction with PreventUIRefresh where UI refresh suppression and restoration must be correctly balanced.

Track selection requires careful attention to ensure num_tracks correctly accounts for all selectable tracks including the master track, setReaperTrackSelection correctly updates REAPER's selection and keeps globals.state.current_tr_id in sync, and behavior is correct with projects having no tracks or a large number of tracks.

MIDI feedback needs verification that feedback for all controls is being sent correctly via midi_out.sendMidiFeedback and that the Console1's LEDs respond as expected to these feedback messages.

The scrub action is defined in TransportAction and handled in midi_events.zig but is commented out in transportAction, meaning the functionality is incomplete.

All Reaper Command IDs used in Main_OnCommand must be correct and consistently behave as expected across different REAPER versions or configurations. Some commands like _SWS_SAVEALLSELITEMS1 and _SWS_RESTALLSELITEMS1 are SWS extension commands, which implies a dependency on the SWS extension being installed.

Control value handling needs verification that utils.calculateNewScrollPosition correctly translates the absolute 0-127 MIDI CC values into appropriate deltas for each action, especially for continuous controls.

## GUI Component

As noted in the project game plan, a dedicated GUI panel for the Transport mode has not yet been implemented. If this mode is to have a visual representation within the plugin's ImGui interface, this would be a future development task.
