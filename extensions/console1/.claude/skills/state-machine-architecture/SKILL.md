---
name: state-machine-architecture
description: Understand the state machine architecture of the REAPER Console1 extension, including modes, event flow, and dispatch system. Use when working with mode transitions or event handling.
---

# State Machine Architecture

This skill explains how the state machine works in the REAPER Console1 extension. The extension controls a Console1 MIDI controller and manages different operational modes through a centralized state machine.

## Overview

The application uses a mode-based state machine where each mode represents a distinct operational context. The state machine enforces valid transitions between modes and routes events to mode-specific handlers. The central state is defined in src/statemachine.zig and all events flow through a single dispatch function in src/actions.zig.

## Modes

The application supports eight modes:

- fx_ctrl: The main operational mode where the controller manipulates FX parameters on the currently selected track.
- transport: Controls playback and transport functions in REAPER.
- fx_sel: Allows browsing and selecting FX plugins to assign to controller modules.
- mapping_panel: Configures parameter mappings for FX plugins that do not have predefined mappings.
- settings: Manages user preferences and global configuration.
- default_fx_sel: Selects default FX assignments within the settings context.
- midi_learn: Dedicated mode for MIDI learning operations (if implemented separately).
- suspended: The extension is toggled off and does not process events.

## State Structure

The central State structure in src/statemachine.zig holds three categories of data:

Mode-specific state:
- fx_ctrl: An FxControlState instance tracking the current track state, module locations, and parameter values.
- fx_sel: An FxSelectionState instance tracking the current category and scroll position.
- default_fx_sel: Another FxSelectionState instance for default FX selection.
- transport: A TransportState instance managing transport controls.
- mapping: A MappingState instance holding the target FX name, current mappings, and MIDI learn status.

Shared state:
- current_tr_id: The ID of the currently selected track being controlled.
- selectedTracks: A hash map of all selected tracks in REAPER.
- fx_ctrl_gui_visible: Whether the GUI window is visible.

Mode transitions:
- current_mode: The currently active mode.
- valid_transitions: A compile-time map defining which mode transitions are allowed.

## Event Flow

Events enter the system through three entry points and converge on a single dispatch function:

### MIDI Events

MIDI input from the Console1 controller arrives through the REAPER control surface API. The handler is defined in src/csurf/midi_events.zig in the OnMidiEvent function. This function decodes the CC message and dispatches it to the appropriate mode-specific handler based on the current mode.

### DAW Events

REAPER notifies the extension of DAW state changes through control surface callbacks. These events are handled in src/csurf_actions.zig in the csurfActions function. Examples include track selection changes, FX parameter changes, FX chain modifications, and playback state changes.

### GUI Events

User interactions with the ImGui interface generate events. The GUI runs on a timer registered in src/imgui_loop.zig. The main GUI logic is in src/gui_lib.zig, which renders mode-specific panels and returns optional ModeAction values when the user interacts with controls.

### Central Dispatch

All events are converted to ModeAction unions and sent to the actions.dispatch function in src/actions.zig. This function performs the following steps:

1. If the action is a mode change request, it validates the transition using the valid_transitions map.
2. If the transition is valid, it updates the current mode and manages GUI lifecycle (registering or unregistering the GUI timer).
3. If the action is mode-specific, it routes to the appropriate handler function.
4. After processing, it may send MIDI feedback to the controller to update LED states.

## Mode-Specific Handlers

Each mode has its own action handler that processes mode-specific logic:

- src/fx_ctrl_actions.zig: Handles parameter changes, module browsing, and track entry in fx_ctrl mode.
- src/fx_sel_actions.zig: Manages FX plugin browsing and selection in fx_sel mode.
- src/mapping_actions.zig: Handles parameter mapping configuration in mapping_panel mode.
- src/settings_actions.zig: Processes preference updates in settings mode.
- src/transport_actions.zig: Manages playback controls in transport mode.
- src/default_fx_sel_actions.zig: Handles default FX selection in default_fx_sel mode.

Each handler receives the Globals instance and a mode-specific action union. The handler mutates the appropriate state and may dispatch additional actions or send MIDI feedback.

## GUI Rendering

The GUI system is based on Dear ImGui and runs on a timer callback. The rendering flow is:

1. The timer callback in src/imgui_loop.zig invokes the main function in src/gui_lib.zig.
2. The main function checks the current mode and renders the appropriate panel.
3. Each panel is defined in its own file (src/fx_ctrl_panel.zig, src/fx_sel_panel.zig, src/mapping_panel.zig, src/settings_panel.zig).
4. If the user interacts with a control, the panel returns an optional ModeAction.
5. The action is dispatched through the central dispatch function.

The GUI window is docked at the bottom of the REAPER interface and persists across mode changes unless the user closes it or the extension is suspended.

## Mode Transitions

Mode transitions are validated using the valid_transitions map in src/statemachine.zig. This map defines the allowed transitions for each mode. For example, from fx_ctrl mode, the application can transition to settings, fx_sel, mapping_panel, suspended, or transport modes, but not directly to default_fx_sel or midi_learn modes.

When a mode change is requested, the dispatch function checks if the transition is valid. If it is not, the function logs an error and returns without changing the mode. This ensures the state machine remains in a consistent state.

## Reentrancy Protection

The extension uses reentrancy guards to prevent infinite loops when actions trigger DAW callbacks that in turn trigger more actions. The implementation is in src/reentrancy.zig and is used in critical sections where REAPER API calls might trigger callbacks.

## MIDI Feedback

The extension sends MIDI feedback to the Console1 controller to update LED states on knobs and buttons. This happens in response to parameter changes from both the controller and the DAW. The MIDI output logic is in src/midi_out.zig and is invoked through the dispatch system.
