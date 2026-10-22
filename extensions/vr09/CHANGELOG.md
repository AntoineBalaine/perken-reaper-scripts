# Changelog

## Unreleased

First version.

- Parameters of the VR-09 as automatable CLAP parameters, written with DT1 messages (and 20 controllers sent as MIDI CC), 2 ms apart.
- Reading the keyboard (Identity Request, then RQ1 for the 22 memory blocks), following panel changes, and writing only what differs when a patch is recalled.
- The patch saved in the REAPER project, and sent to the keyboard when the project opens.
- Presets as the dump JSON of `vr09.py`, a preset folder under REAPER's resource folder, import and export, and a preset discovery factory.
- A Registrations library in the Patches tab: the roland-vr09 dumps named `<bank>-<slot>_<Name>.json`, browsed by bank with a filter, and installed by `build-install.sh vr09` without overwriting existing files.
- A ReaImGui panel with Controls, Patches, Audio loop and MIDI tabs.
- The panel opens where it fits on the screen, and a closed panel's ImGui context is dropped to be collected, with a name of its own for each context. A panel that stuck out of the screen was moved by the window manager without ImGui knowing, which offset the mouse.
- The track's MIDI passes to the keyboard by default, with the notes sent to the Upper part (channel 4), or split at middle C between the Lower (3) and Upper parts for the patches marked as split.
- A Program Change on channel 16 selects a registration (program 0 is 1-1, four slots per bank), and the notes after it follow that registration's split at once. Registration and Split at middle C parameters do the same from automation.
- Automatic choice of the keyboard's MIDI device for the track, with record arm and input monitoring.
- An audio loop through the audio interface, with a latency ping reported to REAPER.
- A ReaScript function, `VR09_Command`, that returns the plugin's state, log and devices as JSON and changes its settings, for debugging from a Lua script (see the README).
- Builds for macOS (arm64 and x86_64), Linux and Windows from any host.
