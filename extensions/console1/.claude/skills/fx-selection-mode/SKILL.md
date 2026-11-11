---
name: fx-selection-mode
description: Understand the FX selection mode in the REAPER Console1 extension. Use when working with plugin browsing, FX assignment, or module selection UI in src/fx_sel_actions.zig or src/fx_sel_panel.zig.
---

# FX Selection Mode

This skill explains how the FX selection mode works in the REAPER Console1 extension. The FX selection mode allows users to browse and select plugin effects to assign to specific Console1 modules.

## Overview

The FX selection mode provides an interface for browsing available FX plugins and assigning them to Console1 modules. When a plugin is selected, the extension adds it to the current track at the appropriate position in the FX chain and assigns it to the selected module. If the plugin does not have a predefined parameter mapping, the extension transitions to the mapping panel mode to allow the user to create custom mappings.

## Module Categories

The Console1 controller has five module slots that can be assigned to different FX plugins:

- INPUT: Typically used for input processing effects like gain, filters, and phase inversion.
- GATE: Used for gate and transient shaping effects.
- EQ: Used for equalization effects.
- COMP: Used for compression effects.
- OUTPT: Used for output processing effects like saturation and limiting.

Each module category has its own list of available plugins with predefined mappings. These lists are maintained in the mappings list structure.

## State Structure

The FxSelectionState structure is defined in src/statemachine.zig and contains three fields:

- current_category: The currently selected module category being browsed.
- scroll_position_abs: The absolute MIDI CC value from the controller scroll knob.
- scroll_position_rel: The relative index in the plugin list corresponding to the scroll position.

## Plugin Discovery

The extension discovers available plugins through two mechanisms:

FX parser:
The fx_parser module in src/fx_parser.zig scans REAPER's plugin configuration files and builds lists of available plugins organized by type (VST, VST3, JS, AU, CLAP, LV2), by category tags, and by developer tags. The parser also discovers FX chains and track templates stored in the REAPER resource directory.

Mappings list:
The mappings_list module in src/mappings_list.zig scans the extension's resource directory for saved parameter mapping files. For each module category, it reads the INI files in the maps subdirectory and extracts the FX names. These are the plugins that have predefined parameter mappings and appear at the top of the selection list.

## GUI Components

The FX selection panel is implemented in src/fx_sel_panel.zig and provides the following interface:

Module browser popup:
A popup window displays the list of available plugins for the currently selected module category. The list is divided into two sections: plugins with existing mappings appear first, followed by a separator and then all available plugins from the FX parser.

Highlighted selection:
The currently selected plugin is highlighted with inverted colors using a draw list splitter. The background is drawn with the foreground color and the text is drawn with the background color.

Nested menus:
The unmapped plugins section includes nested menus for browsing by plugin type, by category tags, by developer tags, and for accessing FX chains and track templates. These menus are populated from the fx_parser data.

Scroll navigation:
The user can scroll through the plugin list using either the Console1 controller knob or mouse input. The scroll position is synchronized between the GUI and the controller.

## Actions

FX selection mode actions are defined in src/fx_sel_actions.zig as the FxSelActions union. The mode supports six actions:

toggle_module_browser:
Toggles the FX browser for the specified module category. If the browser is already open for that category, this action closes it and returns to fx_ctrl mode. Otherwise, it resets the scroll position and opens the browser for the new category.

scroll:
Updates the scroll position within the current plugin list. The action uses the calculateNewScrollPosition utility function to convert absolute MIDI CC values into relative list indices.

plugin:
Selects a plugin to add to the current track. This action performs several steps: it determines the correct insertion index based on existing module assignments, adds the plugin to the track using the REAPER API, appends a module identifier suffix to the plugin name, removes any existing plugin in that module slot, validates the track state, and either enters mapping mode for unmapped plugins or returns to fx_ctrl mode for plugins with existing mappings.

fx_chain:
Loads an FX chain file from the REAPER resource directory and adds all plugins in the chain to the current track. After loading, the extension transitions back to fx_ctrl mode.

track_template:
Opens a track template file in REAPER. This creates new tracks with the template's configuration. After loading, the extension transitions back to fx_ctrl mode.

close_browser:
Closes the FX browser and returns to fx_ctrl mode without making any changes.

## Insertion Logic

When a plugin is added to a track, the extension determines the correct insertion index to maintain a consistent FX chain order. The determineInsertionIndex function in src/fx_sel_actions.zig implements the following logic:

If no modules exist on the track, the plugin is added at the end of the FX chain.

For INPUT modules, the plugin is inserted before the first existing module or at the end if no modules exist.

For GATE modules, the plugin is inserted before the COMP module if it exists, otherwise before the last module or at the end.

For EQ modules, the plugin is inserted after the INPUT module if it exists, otherwise before the first module or at the end.

For COMP modules, the plugin is inserted after the GATE module if it exists, otherwise after the EQ module if it exists, otherwise before the last module or at the end.

For OUTPT modules, the plugin is inserted after the last existing module or at the end.

## Empty Mapping Creation

When a plugin without predefined mappings is selected, the extension creates an empty mapping structure in the MapStore before entering mapping mode. The createEmptyMapping function in src/fx_sel_actions.zig allocates an empty mapping structure appropriate for the current module category and stores it in the map store with the plugin name as the key.

## Module Suffix

When a plugin is added to the track, the extension appends a module identifier suffix to the plugin name. The suffix format is the plugin name followed by a space and the module prefix in parentheses. For example, a compressor assigned to the COMP module would be named like "ReaComp (C1-C)". This suffix helps identify which plugins are controlled by the Console1 extension and which module they are assigned to.

## Integration with Mapping Mode

If a selected plugin does not have predefined parameter mappings, the extension automatically transitions to the mapping_panel mode. The enterMappingMode function in src/fx_sel_actions.zig initializes the mapping panel with the track and FX index, loads the plugin's parameter list, and prepares the interface for the user to create custom parameter mappings.
