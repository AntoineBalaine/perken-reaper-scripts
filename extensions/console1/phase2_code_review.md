# Phase 2 Code Review - Preset Browser System

[tpbreviewed] mappings: phase2

- /Users/antoine/Documents/personnel/experiments/zigwrap2/src/save_preset_dialog.zig 
Draw function can’t be part of the  SavePresetDialog struct. In our codebase, UI draw functions are pure. They don’t need to be methods of any class or struct.

- the flow of the program is not correct, I realize I described it wrong.

First of all when the user clicks the preset button, we need to
open a window in which user is going to select, which of the the effects he wants to edit.


```
Preset window

Module Selection

Eq      <current_fx_name_on_track>  <- can scroll selection on these items 
COMP    <current_fx_name_on_track>
SHP     <current_fx_name_on_track>
INPT    <current_fx_name_on_track>
OUTPT   <current_fx_name_on_track>
```

The options for the effects that are available to edit are those of the effects that are loaded on the current track and no other
When the user selects one of the effects we switch over into the mapping panel. I expect that we are going to reuse the same window as the module browser for this.
```
Mapping Panel

fxParam <-> Assignment
fxParam <-> Assignment

---
SaveBtn CancelBtn
```
In the mapping panel there is the list of effect parameters for
the effect selected by the user with the current assignments. At the bottom of the window, there's the save and the cancel button.
When user hit save, we switch the window to displaying the save menu. The save menu is similar to a file finder GUI, except it ONLY displays the list of files from the directory of the `<maps>/<module>/<fx_name>/`. 

```
Save Preset Panel

<maps>/<module>/<fx_name/

- Preset1
- Preset2
- Preset3

---

TextInput

SaveBtn CancelBtn

```

---

Should the preset browser mode be a separate mode? 
Well, So far I expected to have only the mapping panel mode for this story.

If we were to use only the mapping panel mode, then we would be in the situation in which we need also a second state machine to
 designate, which of the three sub windows we want to be displaying while in mapping panel mode: a hierarchical state machine.
The three modes would be:
- BROWSE
- ASSIGN
- SAVE

Other problem: those data should not be included as methods of any UI classes. 
We should have a state in the MAIN state for those, that contains everything we need.

--- 
- what needs to be done, 
- a pseudo-code schematic of the state of the mapping mode and sub-modes, 
- a pseudo-code schematic of all the actions that can be sent through the dispatcher, 
- a list of the new UI panels that we need to implement (or pre-existing ones that we can remove or
modify.)
