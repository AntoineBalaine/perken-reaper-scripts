# Getting Started with Console1

This guide walks you through the first launch and basic usage of the Console1 REAPER extension.

## First launch

After installing the extension and configuring the control surface in REAPER's preferences (see the README), the Console1 GUI window should appear automatically. If it doesn't, go to `Extensions > Console1` in REAPER's menu bar.

The GUI shows the currently selected track's channel strip: the five module sections (Input, Gate, EQ, Compressor, Output) with their assigned plugins and parameter values.

## Modes

The Console1 operates in several modes. You switch between them using the hardware buttons or the GUI.

### FX Control mode

This is the default mode. The Console1 knobs and buttons control the parameters of the plugins assigned to each module on the currently selected track.

- Turning a knob adjusts the mapped parameter.
- The GUI shows the current parameter values and names for each knob.
- Selecting a different track in REAPER automatically syncs the Console1 to that track's plugins.

### Transport mode

Press `Display Mode` on the Console1 hardware to toggle between FX Control and Transport mode. In Transport mode, the knobs and buttons control REAPER's transport and navigation:

- Play, Stop, Record via the track select buttons (Tr17, Tr18, Tr19).
- Jog through the timeline, navigate markers, and navigate media items via the EQ gain knobs.
- Zoom horizontally and vertically via the Output Drive and Drive Character knobs.
- Adjust grid size, toggle snap, toggle loop, and set loop boundaries.
- Select tracks via the Output Volume knob.

Press `Display Mode` again to return to FX Control mode.

## Assigning plugins to modules

To assign a plugin to a Console1 module:

1. Press one of the five module buttons on the Console1 (the track select buttons Tr1-Tr5 correspond to Input, Gate, EQ, Compressor, Output).
2. The FX Selection panel opens, showing plugins that have predefined parameter mappings at the top, followed by all available plugins organized by type and category.
3. Scroll through the list using the Console1's scroll knob, or click directly in the GUI.
4. Select a plugin. If it has a single mapping, it gets inserted immediately. If it has multiple mappings (e.g., the SumChannel S2 has separate mappings for each compressor style), a sub-menu appears to choose the specific mapping.
5. The plugin is added to the track's FX chain at the appropriate position and the Console1 returns to FX Control mode.

If the selected plugin has no predefined mapping, the extension enters the Mapping Panel where you can create a custom mapping by assigning Console1 CCs to plugin parameters.

## Channel strip mode

Some plugins (like Tukan SumChannel S2) contain an entire channel strip in a single plugin: EQ, compressor, gate, and output processing all in one. When you assign such a plugin, the extension enters channel strip mode, where all five Console1 modules control different sections of the same plugin.

The SumChannel S2 ships with several mapping variants, one per compressor style (Strip Compressor, Vari Compressor, VCA, LA-2Kan, NC76). Each variant includes a preset that automatically configures the plugin to use the corresponding compressor type.

## Settings

Press `Tr20` on the Console1 hardware (or click the wrench icon in the GUI) to open the Settings panel. From here you can:

- Set the preferred module order (the sequence in which modules appear in the FX chain).
- Choose default plugins for each module (used when auto-inserting FX on new tracks).
- Toggle whether the track list syncs with REAPER's arrange view.
- Toggle auto-insertion of default FX when selecting a track with no Console1 modules.

## Track selection

Select tracks by clicking them in the track list panel on the left side of the GUI, or by using the Console1's track select buttons (Tr1-Tr10 in FX Control mode). The Console1 syncs to the selected track's plugins automatically.

## Creating custom mappings

When you select a plugin that has no predefined mapping, the Mapping Panel opens:

1. Each Console1 CC (knob or button) is listed with a dropdown of the plugin's parameters.
2. Select which plugin parameter each CC should control.
3. Save the mapping. It gets written to the maps directory and will be available for future use.

You can also enter the Mapping Panel manually from the FX Control mode (when built with the dev flag) using the plus button in the GUI's button bar.

## Tips

- The Console1 LEDs update to reflect the current parameter values when you switch tracks or modes.
- The GUI overlay shows parameter names and values in real time as you turn knobs.
- Multiple tracks can have different plugin assignments. The Console1 loads the correct configuration when you switch tracks.
- Map files are plain INI files in `Data/Perken/Console1/maps/` inside your REAPER resource path. You can edit them with a text editor if needed.
