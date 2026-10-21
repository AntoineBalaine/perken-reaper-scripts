# Changelog

## Unreleased

First version.

- Parameters of the VR-09 as automatable CLAP parameters, written with DT1 messages (and 20 controllers sent as MIDI CC), 2 ms apart.
- Reading the keyboard (Identity Request, then RQ1 for the 22 memory blocks), following panel changes, and writing only what differs when a patch is recalled.
- The patch saved in the REAPER project, and sent to the keyboard when the project opens.
- Presets as the dump JSON of `vr09.py`, a preset folder under REAPER's resource folder, import and export, and a preset discovery factory.
- A ReaImGui panel with Controls, Patches, Audio loop and MIDI tabs.
- Automatic choice of the keyboard's MIDI device for the track, with record arm and input monitoring.
- An audio loop through the audio interface, with a latency ping reported to REAPER.
- Builds for macOS (arm64 and x86_64), Linux and Windows from any host.
