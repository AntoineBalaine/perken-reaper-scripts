---
name: mapping-panel-mode
description: Understand the mapping panel mode in the REAPER Console1 extension. Use when working with custom parameter mappings, MIDI learn, or mapping UI in src/mapping_actions.zig or src/mapping_panel.zig.
---

# Mapping Panel Mode

This skill explains how the mapping panel mode works in the REAPER Console1 extension. The mapping panel mode allows users to create custom parameter mappings for FX plugins that do not have predefined mappings.

## Overview

The mapping panel mode is entered automatically when a user selects an FX plugin that does not have predefined parameter mappings. The mode provides an interface for assigning FX parameters to Console1 controls. Mappings are stored in a temporary structure and only committed to the MapStore when the user explicitly saves them. The user can cancel without saving to discard all changes.

## State Structure

The MappingState structure is defined in src/statemachine.zig and contains five fields:

- target_fx: The name of the FX plugin being mapped.
- current_mappings: A tagged union containing the mapping structure for the currently selected module.
- selected_parameter: The index of the currently selected FX parameter, or null if none is selected.
- selected_control: The Console1 control currently selected for mapping, or null if none is selected.
- midi_learn_active: A boolean indicating whether MIDI learn mode is currently active.

## Panel Structure

The MappingPanel structure is defined in src/mapping_panel.zig and contains two fields:

- fx_params: An ArrayList of FxParameter structures representing all parameters of the target FX plugin.
- allocator: The memory allocator used for managing the parameter list.

Each FxParameter contains an index and a name string. The panel loads these parameters from the target FX using the REAPER API when entering mapping mode.

## Initialization

The enterMappingMode function in src/fx_sel_actions.zig initializes the mapping panel when a plugin without mappings is selected. The function retrieves the track and FX index, creates a MappingPanel instance if one does not exist, and calls the loadParameters method to populate the parameter list. The loadParameters method queries the REAPER API for the number of parameters and their names, allocating memory for each parameter name and storing them in the ArrayList.

## GUI Components

The mapping panel GUI is implemented in src/mapping_panel.zig and provides the following interface:

Module selector:
A combo box at the top allows the user to switch between different module categories (INPUT, GATE, EQ, COMP, OUTPT). Changing the module resets the current mappings to an empty structure for that module type.

Control assignment interface:
For each module, the panel displays the available Console1 controls as buttons. Next to each button is a combo box showing the currently assigned FX parameter or "none" if unassigned. Clicking a button selects that control. The combo box allows direct selection of a parameter to assign to that control.

Visual knob interface:
For the INPUT module, the panel provides a visual representation using knob widgets that mirror the Console1 layout. Each knob displays the assigned parameter name or "none" if unassigned. The user can interact with knobs to select controls and assign parameters.

Parameter list:
A scrollable list displays all available FX parameters. The user can click a parameter to select it. Parameters that are already mapped to a control show a "mapped" indicator next to their name.

MIDI Learn button:
A button toggles MIDI learn mode on and off. The button label changes to indicate when MIDI learn is active. In MIDI learn mode, the user can turn a knob on the Console1 controller to automatically assign it to the currently selected parameter.

Save and Cancel buttons:
The save button commits the current mappings to the MapStore and writes them to disk, then exits to fx_ctrl mode. The cancel button discards all changes and exits to fx_ctrl mode without saving.

## Actions

Mapping panel actions are defined in src/mapping_actions.zig as the MappingAction union. The mode supports eight actions:

select_parameter:
Selects or deselects an FX parameter by its index. When a parameter is selected in MIDI learn mode, the extension waits for MIDI input to determine which control to map.

select_control:
Selects or deselects a Console1 control. When both a parameter and a control are selected, the user can create a mapping between them.

toggle_midi_learn:
Toggles MIDI learn mode on and off. When exiting MIDI learn mode, the selected control is cleared.

add_mapping:
Creates a mapping between an FX parameter and a Console1 control. The action updates the current_mappings structure by setting the appropriate field to the parameter index. After adding the mapping, both selections are cleared.

remove_mapping:
Removes an existing mapping for the specified Console1 control. The action updates the current_mappings structure by setting the control's field to null.

save_mapping:
Commits the current mappings to the MapStore by writing them to the appropriate module-specific hashmap. The function then calls saveToFile to write the mapping to an INI file in the maps directory. After saving, the mapping panel is cleaned up and the extension transitions back to fx_ctrl mode.

cancel_mapping:
Discards all changes by clearing the mapping state and destroying the mapping panel. The extension transitions back to fx_ctrl mode without writing any changes to disk or the MapStore.

change_module:
Switches the current module category and resets the current_mappings to an empty structure for the new module type. This allows the user to create mappings for multiple modules for the same FX plugin.

## Mapping Storage

When mappings are saved, they are written to two locations:

MapStore:
The MapStore structure in src/mappings.zig maintains in-memory hashmaps for each module category. The save_mapping action writes the current_mappings to the appropriate hashmap using the target FX name as the key.

Disk files:
The saveToFile method writes the mapping to an INI file in the maps subdirectory of the resource path. The file is organized by module category with each control field written as a key-value pair where the value is the FX parameter index.

## Helper Functions

The mapping panel implementation includes several helper functions:

isParamMapped:
Checks whether a given parameter index is currently mapped to any control. This function iterates through all fields in the current_mappings structure and returns true if the parameter index matches any assigned value.

getControlMapping:
Retrieves the parameter index assigned to a specific Console1 control. The function searches the current_mappings structure for a field matching the control's name and returns its value if set.

Module-specific control lists:
The implementation defines constant arrays for each module (compressor_controls, eq_controls, input_controls, output_controls, gate_controls) listing the relevant Console1 controls for that module. These arrays determine which controls are displayed in the interface for each module category.

## MIDI Learn Workflow

The MIDI learn feature allows users to create mappings by physically interacting with the Console1 controller. The workflow is:

1. The user selects an FX parameter from the list.
2. The user clicks the MIDI Learn button to activate MIDI learn mode.
3. The user turns a knob or presses a button on the Console1 controller.
4. The extension receives the MIDI input, identifies the control, and creates a mapping between the selected parameter and that control.
5. The extension exits MIDI learn mode automatically and the new mapping is displayed in the interface.
