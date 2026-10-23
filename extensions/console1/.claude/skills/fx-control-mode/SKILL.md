---
name: fx-control-mode
description: Understand the FX Control mode in the REAPER Console1 extension. Use when working with parameter control, MIDI input handling, or FX Control UI components in src/fx_ctrl_actions.zig or src/fx_ctrl_panel.zig.
---

# FX Control Mode

This skill explains how the FX Control mode works in the REAPER Console1 extension. The FX Control mode is the primary operational state where the hardware controller directly manipulates audio effect parameters on the currently selected track in REAPER.

## Purpose

The FX Control mode is the primary operational state of this application. When this mode is active, the user can directly manipulate the parameters of audio effects on the currently selected track in Reaper using the hardware controller. It serves as the central hub for real-time interaction between the hardware and the digital audio workstation.

## Core Responsibilities

This mode is responsible for three main tasks. First, it translates incoming MIDI messages from the hardware into corresponding parameter changes within Reaper. Second, it listens for parameter change notifications from Reaper to ensure the hardware's LED indicators and the plugin's internal state remain synchronized. Third, it drives the user interface, which provides a visual representation of the hardware controls.

## Event Handling Flow

The logic of this mode is event-driven and follows two primary paths.

### MIDI Input from Hardware

When the user adjusts a control on the hardware, a MIDI message is sent to the plugin. This event is first received by the control surface module, located in `src/csurf/midi_events.zig`. Because the application is in FX Control mode, this module dispatches a mode-specific action. This action is then processed by the `dispatch` function in `src/actions.zig`, which in turn calls the dedicated handler in `src/fx_ctrl_actions.zig`. This handler looks up the correct mapping for the control, determines which Reaper parameter to change, and makes the API call through the `src/pReaper.zig` module.

### Notifications from Reaper

When a parameter is changed directly within Reaper, for instance by the user moving a knob with the mouse, Reaper sends a notification to the plugin. The `src/csurf/control_surface.zig` module receives this notification and dispatches a control surface action. This action updates the plugin's internal state to reflect the new parameter value. The change in state then triggers a MIDI message to be sent from `src/midi_out.zig` back to the hardware controller to update the corresponding LED display, ensuring everything stays in sync.

## User Interface

The visual component for this mode is defined in `src/fx_ctrl_panel.zig`. It renders a graphical schematic of the hardware controller, complete with knobs and buttons. This interface is not just a static image; it is an active display that reads its values directly from the plugin's central state. When a parameter's value changes, the state is updated, and the user interface re-renders to show the new position of the corresponding knob.

## State Management

All of the data required for this mode to function is held within the `FxControlState` struct, which is defined in `src/fx_ctrl_state.zig`. This structure maintains all necessary information, such as the FX mappings that are currently loaded for the selected track, the last known values of all controlled parameters, and the status of any toggle buttons. By keeping this information in a dedicated struct, we ensure a clean separation between the mode's data and its logic.
