# The VR-09 design lab

The plugin's panel drawn from Lua, with a mock keyboard, so that its look can be worked on without recompiling and without the keyboard. Saving a file changes the open window at once.

## Running it

Load `ui-lab/vr09_lab.lua` once with "ReaScript: Load" in REAPER's Actions list, which registers it as "Script: vr09_lab.lua". Run that action to open the lab, and run it again to close it.

To have the action registered at every launch, put these two lines in `<resource folder>/Scripts/__startup.lua`:

```
local lab = reaper.GetResourcePath() .. "/Scripts/perken/extensions/vr09/ui-lab/vr09_lab.lua"
if reaper.file_exists(lab) then reaper.AddRemoveReaScript(true, 0, lab, true) end
```

It needs ReaImGui. It uses the same ReaImGui API version as the plugin (0.9.3), so that what is written here ports to Zig call for call.

## What reloads

The runner watches three files, and reloads one as soon as it changes:

- `theme.lua`: the colors and the styles pushed around the window;
- `widgets.lua`: the components (the drawbar, the parameter slider). A new component starts here;
- `panel.lua`: the header, the tabs and what they hold.

`model.lua` (the mock keyboard) and `catalog.lua` are read once, when the lab starts: close and run the lab again after changing them.

A module reads `env.theme`, `env.widgets` and `env.ImGui` when it runs, not when it loads, so that a reloaded theme reaches the components without reloading them.

## When a file does not load

A syntax error, or an error while drawing, shows in the window with the file and the line, and the window stays where it was. The next save loads the file again. After an error the ImGui context is dropped and a new one takes over, because an error in the middle of a frame leaves ImGui's stacks unbalanced.

## The mock keyboard

The lab starts with registration 1-1 loaded: the dumps come from `Data/Perken/vr09/registrations`, and the Patches tab loads any of them, so the drawbars and the sliders move as they would on the keyboard. Without that folder (a computer where `build-install.sh vr09` has not copied the dumps), the lab starts with a built-in demo organ patch, and the Patches tab lists nothing. The Lab window (a second, small window) switches the connection state and the MIDI IN mode, and starts an error notice. Nothing in the lab talks to MIDI.

## Files

| File | Role |
|---|---|
| `vr09_lab.lua` | the runner: the window, the reload, the error view, the Lab window |
| `theme.lua`, `widgets.lua`, `panel.lua` | what we edit |
| `model.lua` | the mock keyboard and the registrations |
| `catalog.lua` | the plugin's parameters, generated |
| `webview-spike.md` | the test that decides whether a webview can replace ReaImGui |

Generate the catalog again after `src/catalog.zig` changes:

```
python3 tools/gen_lua_catalog.py > ui-lab/catalog.lua
```

## From the lab to the plugin

The plugin draws with Zig calls that mirror the Lua ones (`ImGui.SliderInt` here, `imgui.api.SliderInt` in `src/ui.zig`). A component that looks right here is then written in `src/ui.zig`, and the lab's `panel.lua` and the plugin stay alike.

The other way to a better look, a webview in place of ReaImGui, is not built. `webview-spike.md` describes the test that would settle whether it can work, on Linux, macOS and Windows.
