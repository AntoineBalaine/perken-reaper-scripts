# Manual tests

Everything the build and `zig build test` can check is checked. This list is for what only the real keyboard, a cable, a screen or another operating system can show. Each item says what to do and what should happen. If one fails, the notes after it say where to look.

The automated tests and the checks made in REAPER 7.69 on macOS arm64 with a stand-in keyboard (`tools/fakevr09.swift`) are described in the README under "What was checked, and what was not".

## Before starting

- The keyboard is in MIDI IN Mode 2, connected over USB.
- ReaImGui is installed (ReaPack).
- REAPER is started from a terminal, to see the plugin's log lines (`/Applications/REAPER.app/Contents/MacOS/REAPER` on macOS). The lines start with `info(plugin)`, `info(ui)` and `info(discovery)`.

## 1. The real keyboard

1. Add "VR-09 (Perken)" to a new track.
   - About a second later the track's MIDI output is the VR-09, and the track is armed (the log says "MIDI output set" and "the track is armed").
   - Within a few seconds the panel header reads "Keyboard connected (MIDI IN mode 2)", and the Controls tab shows the keyboard's current drawbars and levels.
   - If the header says the keyboard does not answer, open the MIDI tab: "SysEx events from the host" should count up. If it stays at 0, the replies do not reach the plugin (is the track armed and monitoring?). If it counts but nothing is read, look at "First received".
2. Move a drawbar on the keyboard.
   - The matching slider in the Controls tab follows within a moment.
3. Move a slider in the Controls tab.
   - The keyboard's drawbar LEDs and sound follow.
4. Set the "Upper organ drawbar 8'" parameter from REAPER's own FX window, and then record automation for it (touch mode) while moving the plugin's slider.
   - The automation lane records the move.
5. Repeat step 3 with a CC control (for example "Upper synth cutoff (CC74)").
   - The synth sound changes. These controllers were never verified on the unit (`docs/cc-modulation-table.md`).
6. Replace the cable with the keyboard off, then switch it on.
   - Within about three seconds of it showing up as a MIDI device, the header turns green and the knobs fill in. "Look for the keyboard again" in the MIDI tab forces the search.

## 2. Patches

1. In the Patches tab, press "Read the keyboard", type a name, press "Save as preset".
   - A file `<name>.vr09` appears in `<REAPER resource folder>/Data/Perken/vr09/presets`, and the list shows it.
2. Recall a Registration on the keyboard's panel, read it, and save it under another name. Load the first preset again with a double click.
   - The keyboard sounds like the first Registration again within about a second. The display still shows the second Registration's title, which is expected.
3. Run `extensions/build-install.sh vr09`, open the Patches tab, and look at the Registrations section.
   - Banks 1 to 18 are listed (18 has two slots) with their names. Typing `12-3` or part of a name filters the list and opens the matching banks.
   - A double click on one sends it: the keyboard sounds like that Registration within about a second, and the header reads `Patch: <bank>-<slot> <Name>`.
   - Running the script again copies nothing, and a file you edited in the registrations folder stays as it is.
4. Copy a dump from the roland-vr09 project (`dumps/1-1_MassiveOrgDF.json`) into the preset folder, or use "Import a file".
   - It loads and the keyboard follows.
5. Type an absolute path in the Export field and press "Export".
   - The file exists, and `python3 vr09.py diff` against a dump of the same state shows no difference.
6. Save the project, close it, and open it again with the keyboard on and set to a different patch.
   - Within a few seconds of opening, the keyboard is back in the project's patch. Switch off "Send the patch to the keyboard when the project opens" and repeat: the keyboard is left alone.
7. Open the project with the keyboard off, then switch it on a minute later.
   - The patch is sent once the keyboard answers.

## 3. Notes and the track layout

1. On the plugin's track, with "Pass this track's MIDI through" off, play the keyboard.
   - No doubled notes. The MIDI tab says how many messages were not passed on.
2. On a second MIDI track (input: the keyboard, output: the keyboard, no plugin), record a few notes and play them back.
   - They record and play back normally while the plugin's track stays armed.
3. Put a MIDI item on the plugin's track and play it, with "Pass this track's MIDI through" on and the keyboard's Local Control off.
   - The keyboard plays the item. With the option off, it stays silent.
4. While the transport plays, change parameters from the panel.
   - No stuck notes, and the sound keeps playing.

## 4. The audio loop

Wire an interface output to the keyboard's audio input, and the keyboard's output to an interface input. Turn the keyboard's volume down.

1. In the Audio loop tab, choose the output pair and the input pair, and turn the loop on.
   - The status reads "The loop is running", and the dropout counters stay at 0 while the transport plays.
2. Press "Measure the round trip".
   - A click goes out, and the tab shows a number of samples and milliseconds, close to the interface's round-trip latency plus a block or two. Without the cable, it says no click came back.
3. Put the plugin on a track playing an audio file, and another track with the same file and no plugin. Solo both and compare.
   - With the loop on and the latency measured, the two files line up (a polarity flip between them cancels to near silence). If they are late by a constant amount, REAPER ignored the reported latency: check the track's PDC in the FX chain.
4. Change the project's sample rate or the interface's buffer size, and open the project again.
   - The plugin reports no latency until it is measured again, and the Audio loop tab says "not measured yet".
5. Render the project (File, Render).
   - The render completes, and the audio of the plugin's track passes through unchanged (the status says the audio device is not running).
6. Turn the loop off.
   - The track's audio passes through, and the track's anticipative FX processing setting comes back to what it was before (check "Track performance options" for the track).

## 5. The panel

1. Open the plugin's window from the FX chain several times, and close it with the title bar's close button.
   - It opens next to the mouse, draws all four tabs without a "ReaImGui reported" line in the log, and closes cleanly.
2. Open two plugin instances on two tracks.
   - Each has its own window with its own track number in the title, and their states do not mix.
3. Look at the layout: the drawbars should read as drawbars with their labels under them (16', 5 1/3', 8', 4', 2 2/3', 2', 1 3/5', 1 1/3', 1'), the groups should be collapsible, and the text should be readable.
4. Resize the window.
   - The content follows, the preset list scrolls.

## 6. REAPER's own integration

1. In the FX window's preset menu, look for the presets from the plugin's folder.
   - If they are listed, loading one moves the keyboard (the log then shows "metadata asked for ..."). If they are not, REAPER did not create the preset discovery provider; the log shows only "the host counts the providers" and "the host asks for the descriptor 0". The panel's list still works.
2. Save a preset with REAPER's own "Save preset" and load it again.
   - The patch comes back (the plugin's state is the preset).
3. Duplicate the track.
   - The copy has the same patch and settings, and the track's MIDI output is the copy of the original's.
4. Delete the plugin from the track while the panel is open.
   - REAPER does not crash, and the window closes.
5. Quit REAPER with the plugin loaded.
   - It exits normally (the timer and the audio hook are removed at unload).

## 7. Other systems

Linux and Windows build but have not been run.

1. Install the plugin (`extensions/build-install.sh vr09` on Linux, or copy `vr09.clap` to a CLAP folder on Windows) and repeat sections 1, 2 and 5.
2. On Windows, check that the preset folder is created under `%APPDATA%\REAPER\Data\Perken\vr09\presets` (it uses kernel32 calls directly, to avoid the stack overflow that `std.fs` caused in the other extensions).
3. On Linux, check that the ReaImGui window opens next to the FX window, and that the keyboard shows up as a MIDI device named "VR-09".

## 8. Scenes and actions

These need a project with a VR-09 on a track and a few scenes (the lab's Scenes tab adds them). `zig build test` covers the rules (stepping, marker matching, value scaling) and the scene commands, not REAPER itself.

1. Load the plugin and open the action list.
   - "VR-09: next scene", "VR-09: previous scene" and "VR-09: put a scene point at each marker named like a scene" are listed.
2. Run "next scene" repeatedly with the track selected.
   - The Scene parameter moves one scene each time, stops at the last scene, and "previous scene" stops at the first. Bind the two actions to the keys a page-turner pedal sends, and press them with REAPER in the background.
3. Add markers named like some scenes, and one named something else, then run the markers action.
   - The Scene lane appears with a square point at each matching marker, and the console counts the markers that did not match, without a dialog that would stop REAPER. Hover a point: its text is the scene's name. Run the action again: no points are stacked.
4. Look at the values of the lane's points.
   - A lane point holds the parameter's value in the units that REAPER reports for it. If a point reads `0`, or a fraction of the scene number, the scaling assumes the wrong unit: see `laneValue` in `src/actions.zig` and `value_of` in `ui-lab/scene_link.lua`.
5. Drag a scene to another position in the lab with a lane in the project.
   - The lane's points move with it, so that the song still plays the same scenes; Cmd+Z undoes the points.

## 9. When something does not work

- The keyboard ignores the plugin's messages: in the MIDI tab, try "Send SysEx without its F0 and F7 bytes".
- Nothing arrives from the keyboard: the track must be record-armed and monitoring. The MIDI tab says which is missing.
- The log lines to send along with a bug report: everything starting with `info(plugin)`, `info(ui)`, `info(entry)` and `info(discovery)`, and the "First received" and "First sent" lines of the MIDI tab.
