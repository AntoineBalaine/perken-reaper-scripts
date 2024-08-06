PERKEN CONSOLE1

A control surface to integrate the console 1 MKII into Reaper. I’d gotten frustrated with being locked into using Softube’s plugins, the ilok, and the absence of a linux version. 
If anyone’s interested in trying this thing, bear in mind it is still at the experimental phase. 
### If you want to try it
This is for the tech-inclined. You’ll have to compile the project yourself. 
- pull WDL  and reaper’s SDK into the root of the project folder.
- install Zig. 
- run `zig build` from the project folder’s root
- move the resulting build’s `reaper-zig.so` into `REAPER/UserPlugins/`
- move the project’s `resources` folder to `REAPER/Data/Perken/Console1/resources/`
- start reaper
- de-activate the console’s midi input in `settings => midi devices`
- map the console’s in/out to `softube console1` in `settings => control/osc/web => add`
### Features:
- FX control 
	- Upon selecting a track, Console1 loads a container that wraps 5 FX, each corresponding to the sections of the console (input/gate/eq/compressor/output). The container represents your channel strip The mappings that match the knobs with the FX params are contained in the config files (`REAPER/Data/Perken/Console1/resources`). 
	- It’s possible to create your own mapping files and try them out.  To do that, you have to annotate it in the `defaults.ini` file, restart reaper, and re-set the console’s connection in reaper’s `settings => control/osc/web`.
	- It’s not possible to swap FX mappings mid-session atm. 
	- Only one channel strip’s map is available: HBJ highpass/lowpass (input), reagate, reaeq, reacomp, and reaanalog (output)
- track controls: change tracks’ phase, volume, pan, solo, mute
- track synchronization: 
	- any changes on the track will (should?) be reflected in the controller. 
	- on track selection, the console’s knobs sync with the track’s channel strip.
	- clicking the track-number buttons will select the corresponding tracks
- FX display: 
	- `Display On` button will toggle the selected track’s fx chain. It also follows track selection, so when you select a new track the previous fxchain gets closed and the new one gets opened
	- When the fxchain is open, whatever fx you’re tweaking from the console will get focused.
- Fx order: change the position of the EQ inside of the container, relative to the Gate and compressor. Gate is always placed before the container
- External Side chain: set pin mappings for channels 3-4 to route into FX’s inputs 3-4. The console does NOT set the FX’s detection mode to side chain - you’ll have to do that manually.
- Meters: Compressor and output meters work. Output meter is NOT accurate. Gate and input meter do NOT work. Gate meter will probably happen, input meter will probably NOT happen.

### Limitations:
- UNTESTED ON WINDOWS - will most likely not work. MacOS and Linux are good to go.
- can’t change FX mid-session from the console.
- can’t save presets
- Button `Filters to compressor` does not work.
- Buttons `Dupl Track All/Group` do not work either.
### Know issues:
- going back and forth between multiple project tabs crashes reaper when the console is active
- small memory leak that I’m still chasing
- `Page Up/Down` crashes reaper

### Some features I’d like to build
- multiple modes for the console - besides controlling FX, this could be «transport control» or «sample edit controls»
- swapping fx mappings mid-session
- A GUI window to display visual feedback
- Creating more fx mappings
