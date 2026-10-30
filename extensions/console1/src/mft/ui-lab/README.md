# The MFT design lab

The MFT panel drawn from Lua, with mock data, so that its look can be worked on without recompiling and without the controller. It is a dummy: nothing in it talks to REAPER or to the plugin. Saving a file changes the open window at once.

The lab is a development tool, so every Lua file of this folder starts with `-- @noindex`: the repository's ReaPack index is built by scanning the whole repository, and without that line the lab would be published. A file added here needs the line too.

## Running it

Load `mft_lab.lua` once with "ReaScript: Load" in REAPER's Actions list, which registers it as "Script: mft_lab.lua". Run that action to open the lab, and run it again to close it.

It needs ReaImGui. It uses the same ReaImGui API version as the plugin (0.9.3), so that what is written here ports to Zig call for call.

## Using it

- The window has no title bar. The close button (X) in the top right corner closes the lab, and the chevron next to it folds the device to its header row, or opens it again. Drag an empty part of the body to move the window.
- Click an encoder of the bottom two rows to switch to its mode (IO, GATE, EQ, COMP, SETTINGS, TRANSPORT). The last two encoders are reserved.
- Drag an encoder of the top eight up or down to turn it, in the modes that map parameters.
- The right keys (mute, solo, phase) stay lit once clicked. The left keys are momentary.
- The settings mode shows the settings form under the device. Click or drag the bars to set the hue of each mode (the device changes color as the bar moves) and the sensitivity, and use the drop-downs to choose the plugins.
- The "Lab" window chooses where the value of a knob is shown (in the label, above the knob, or in a pop-up while the knob is turned), can make the encoders turn by themselves, reload every file, and reset the mock.

## What reloads

The runner watches these files, and reloads one as soon as it changes:

- `mft_panel.lua`: the device, the encoders, the keys, and the cards under it;
- `mft_icons.lua`: the icons of the transport mode, drawn with geometry;
- `theme.lua` and `widgets.lua` of `../../../../vr09/ui-lab`, which the MFT panel shares with the VR-09 panel.

`mft_model.lua` (the modes, their parameter names, the hues and the transport functions) reloads too, and the values that the encoders hold are kept; the "Reset the mock" button of the Lab window starts them again. The runner `mft_lab.lua` is read when the script starts, so a change to it needs the lab to be closed and run again.

## What the device shows

- Each encoder is a round rubber cap in a well, ringed by eleven white LEDs that light up to the value.
- The lettering under an encoder sits where the controller's color LED is. The LED lights it in the color of the mode, and that color is the accent of the knobs of the mode in use.
- In the transport mode, the caps carry an icon for the function of their rotation, and the window under the knob has two lines: what a turn does, with a curved arrow, and under it what a press does, with a ring and a dot, the two separated by a thin line. Dragging a knob lights the turn line, and holding it without moving lights the press line.
- The mode buttons have the press line alone, because a click is all they do, and it lights while the button is held. It stays in the bottom half of the window, under the line, and the top half stays empty: it is where the mapping of a knob is shown.
- The header row has the card of the mode in use on the left, always as wide as the name TRANSPORT, the name of the controller centered with the green lamp next to it, and the fold and close buttons on the right. Hovering over the green lamp tells that the panel mirrors the controller.
- The fonts are the ones that `reaziglib/assets/fonts` ships.
