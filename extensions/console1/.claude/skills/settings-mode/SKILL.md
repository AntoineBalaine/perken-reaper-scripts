---
name: settings-mode
description: Understand the settings mode in the REAPER Console1 extension. Use when working with user preferences, default FX assignments, or settings panel UI in src/settings_actions.zig or src/settings_panel.zig.
---

# Settings Mode

This skill explains how the settings mode works in the REAPER Console1 extension. The settings mode allows users to configure application preferences and default plugin assignments through a dedicated interface.

## Overview

The settings mode provides a graphical interface for modifying user preferences. Changes are made to a temporary copy of the settings and only committed to disk when the user explicitly saves. The mode supports two categories of settings: boolean preferences that control application behavior and default FX assignments that determine which plugins are loaded for each module on new tracks.

## Settings Structure

The Preferences structure is defined in src/settings.zig and contains two types of configuration data:

Boolean preferences:
- language: The UI language code (currently supports multiple languages including English and French).
- show_startup_message: Whether to display a startup message in the GUI.
- show_feedback_window: Whether to display the GUI window when in fx_ctrl mode.
- show_plugin_ui: Whether to automatically open plugin UIs when parameters are adjusted.
- manual_routing: Whether to enable manual sidechain routing capabilities.
- log_to_file: Whether to write log messages to a file.
- start_suspended: Whether the extension starts in suspended mode.
- show_track_list: Whether to display the track list panel.
- focus_page_tracks: Whether to focus on tracks within the current page.

Default FX assignments:
- default_fx: An EnumArray mapping each module (INPUT, GATE, EQ, COMP, OUTPT) to an optional plugin name.

## Persistence

Settings are persisted to disk in an INI file located at the resource path. The file is named preferences.ini and uses a simple text format with key-value pairs for boolean settings and section headers for module defaults.

The Preferences.init function loads settings from disk during application startup. If the file does not exist or cannot be read, the application falls back to hardcoded defaults defined in the fallback_defaults map. These defaults are defined in src/settings.zig and include standard REAPER plugins like ReaEQ, ReaComp, and ReaGate.

The Preferences.saveToDisk function writes the current settings to disk. This function is called when the user clicks the save button in the settings panel.

## Temporary Editing

The settings panel uses a temporary copy mechanism to allow users to make changes without immediately affecting the running application. When the settings panel is opened, the SettingsPanel.init function in src/settings_panel.zig creates a copy of the current preferences in the temp_settings field.

All user interactions modify this temporary copy. The dirty flag tracks whether any changes have been made. If the user clicks save, the temporary copy is committed to the main Preferences instance in the Globals structure and written to disk. If the user clicks cancel, the temporary copy is discarded and the original settings remain unchanged.

## GUI Components

The settings panel GUI is implemented in src/settings_panel.zig and renders the following components:

Language selector:
A combo box that displays available languages. The current language display name is shown, and selecting a new language updates the temp_settings.language field. If the language differs from the currently loaded translation, a message indicates that a restart is required.

Boolean settings checkboxes:
Each boolean preference is rendered as a checkbox with a translated label. Clicking a checkbox updates the corresponding field in temp_settings and sets the dirty flag to true.

Default FX selectors:
For each module, a combo box displays the currently selected default FX. The combo lists all available plugins for that module from the mappings list. Selecting a plugin updates the default_fx field for that module in temp_settings.

Save and Cancel buttons:
The save button commits changes and transitions back to fx_ctrl mode. The cancel button discards changes and returns to fx_ctrl mode without saving.

## Actions

Settings mode actions are defined in src/settings_actions.zig as the SettingsActions union. The mode supports five actions:

open:
Creates a new SettingsPanel instance if one does not exist and transitions to settings mode. The panel is stored in the globals.settings_panel optional field.

save:
Calls the SettingsPanel.save function to commit the temporary settings to the main Preferences instance and write them to disk. After saving, the settings panel is destroyed and the application transitions back to fx_ctrl mode. If the log_to_file setting changed, the logger state is updated.

cancel:
Discards the temporary settings by destroying the settings panel without saving. The application transitions back to fx_ctrl mode. The mode change is performed directly rather than through the dispatch function to avoid a UI crash.

update_val:
Updates a specific setting value in the temporary copy. This action is dispatched from the GUI when the user interacts with checkboxes or combo boxes. The action includes either a boolean update or a string update depending on the setting type. After updating, a MIDI feedback message is sent to reflect the change on the controller.

scroll:
Updates the scroll position in the settings list. This is used for controller-based navigation where the user can scroll through settings using a knob. The scroll position is tracked in both absolute (MIDI value) and relative (item index) forms.

toggle:
Toggles the currently selected setting based on the scroll position. For boolean settings, this inverts the value. For default FX settings, this transitions to the default_fx_sel mode where the user can browse and select plugins for that module.

## Default FX Selection Mode

When the user selects a default FX setting from the settings panel, the application can transition to a separate mode called default_fx_sel. This mode reuses the FX selection interface but operates in the context of setting defaults rather than assigning plugins to the current track.

The default_fx_sel mode uses the same FxSelectionState structure and action handlers as the main fx_sel mode but updates the temp_settings in the settings panel rather than the track state. The selected category is stored in globals.state.default_fx_sel.current_category.

When the user selects a plugin in default_fx_sel mode, the selection is written to temp_settings.default_fx for the appropriate module and the application transitions back to settings mode. The user must still click save in the settings panel to commit the change to disk.

## Controller Integration

The settings panel can be navigated using the Console1 controller. The scroll action allows the user to scroll through settings using a knob, and the toggle action allows the user to modify the selected setting using a button. The scroll position determines which setting is highlighted in the GUI, indicated by changing the text color to the TextSelectedBg style color.

## Validation and Error Handling

The settings loading and saving operations use error handling to gracefully degrade when files cannot be accessed. If the preferences file cannot be loaded during startup, the application logs a warning and uses fallback defaults. If saving fails, the error is logged but the application continues running with the settings in memory. This ensures the extension remains functional even if disk operations fail.

## Settings Fields Enumeration

The SettingsFields enum in src/settings.zig provides a compile-time mapping between field indices and field names. This enumeration is used for controller-based navigation where the scroll position corresponds to a specific setting. The enum includes entries for all boolean settings and all default FX assignments (default_INPUT, default_GATE, default_COMP, default_EQ, default_OUTPT).
