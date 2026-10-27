# Changelog

## Unreleased

First version.

- Parameters of the VR-09 as automatable CLAP parameters, written with DT1 messages (and 20 controllers sent as MIDI CC), 2 ms apart.
- Reading the keyboard (Identity Request, then RQ1 for the 22 memory blocks), following panel changes, and writing only what differs when a patch is recalled.
- The patch saved in the REAPER project, and sent to the keyboard when the project opens.
- Presets as the dump JSON of `vr09.py`, a preset folder under REAPER's resource folder, import and export, and a preset discovery factory.
- A Registrations library, in the table of the Scenes tab: the roland-vr09 dumps named `<bank>-<slot>_<Name>.json`, browsed by bank with a filter, and installed by `build-install.sh vr09` without overwriting existing files.
- A ReaImGui panel with Controls, Scenes, Patches, Audio loop and MIDI tabs, drawn with the look of the design lab: cards, knobs, drawbars and screens, in fonts that are embedded in the plugin.
- A design lab for the panel in Lua (`ui-lab/`): the panel drawn with a mock keyboard, reloading its theme, components and layout as they are saved.
- The effects as parameters: reverb (type, level, variation), vibrato / chorus type, MFX (type, level), delay (type, level) and the compressor level, with their type names shown in the panel. The reverb type and level are written together, as the unit requires.
- The panel opens where it fits on the screen, and a closed panel's ImGui context is dropped to be collected, with a name of its own for each context. A panel that stuck out of the screen was moved by the window manager without ImGui knowing, which offset the mouse.
- The track's MIDI passes to the keyboard by default, with the notes sent to the Upper part (channel 4), or split at middle C between the Lower (3) and Upper parts for the patches marked as split.
- Scenes: a list of named patches in the project state, a fixed-range Scene parameter that selects one by position (replacing the Registration parameter), and `VR09_Command` commands to add, list, move, rename, select and remove them.
- `save_preset` (which reads the keyboard first, then writes the preset), `save_status`, `load_preset`, `delete_preset` and `load_tone` commands, so a script or the lab can save the keyboard as a patch and send patches to it.
- Actions registered by the plugin: next scene, previous scene, and scene points from the project's markers.
- A Split at middle C parameter, to override the current patch's split from automation.
- Automatic choice of the keyboard's MIDI device for the track, with record arm and input monitoring.
- An audio loop through the audio interface, with a latency ping reported to REAPER.
- A ReaScript function, `VR09_Command`, that returns the plugin's state, log and devices as JSON and changes its settings, for debugging from a Lua script (see the README).
- Builds for macOS (arm64 and x86_64), Linux and Windows from any host.
