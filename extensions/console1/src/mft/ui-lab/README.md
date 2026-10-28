# The MFT design lab

The MFT panel drawn from Lua, with mock data, so that its look can be worked on without recompiling and without the controller. It is a dummy: nothing in it talks to REAPER or to the plugin. Saving a file changes the open window at once.

The lab is a development tool, so every Lua file of this folder starts with `-- @noindex`: the repository's ReaPack index is built by scanning the whole repository, and without that line the lab would be published. A file added here needs the line too.

## Running it

Load `mft_lab.lua` once with "ReaScript: Load" in REAPER's Actions list, which registers it as "Script: mft_lab.lua". Run that action to open the lab, and run it again to close it.

It needs ReaImGui. It uses the same ReaImGui API version as the plugin (0.9.3), so that what is written here ports to Zig call for call.

## Using it

- Click an encoder of the bottom two rows to switch to its mode (IO, GATE, EQ, COMP, SETTINGS, TRANSPORT). The last two encoders are reserved.
- Drag an encoder of the top eight up or down to turn it, in the modes that map parameters.
- The right keys (mute, solo, phase) stay lit once clicked. The left keys are momentary.
- The settings mode shows the settings form under the device, with the drop-downs of plugins.
- The "Lab" window can make the encoders turn by themselves, reload every file, and reset the mock.

## What reloads

The runner watches these files, and reloads one as soon as it changes:

- `mft_panel.lua`: the device, the encoders, the keys, and the cards under it;
- `mft_icons.lua`: the icons of the transport mode, drawn with geometry;
- `theme.lua` and `widgets.lua` of `../../../../vr09/ui-lab`, which the MFT panel shares with the VR-09 panel.

`mft_model.lua` (the modes, their parameter names, the hues and the transport functions) is read once, when the lab starts.

## What the device shows

- Each encoder is a round rubber cap in a well, ringed by eleven white LEDs that light up to the value.
- The lettering under an encoder sits where the controller's color LED is. The LED lights it in the color of the mode, and that color is the accent of the knobs of the mode in use.
- In the transport mode, the caps carry an icon for the function of their rotation, and the lettering gives its name and the function of the press.
- The fonts are the ones that `reaziglib/assets/fonts` ships.
