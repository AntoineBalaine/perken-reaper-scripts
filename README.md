Scripts for the Reaper DAW.

[Scripts list](#scripts-list) 

### Scripts list
#### Realearn - Midi Fighter Twister utilities
<details>
 <summary>MFT map selected fx in visible fx chain</summary> 

`$REAPERPATH/Scripts/perken/realearn/lua_mapper/MFT_map_selected_fx_in_visible_fx_chain.lua`
##### HOW TO USE: 
  - have a realearn instance on the current track with the Midi fighter's preset loaded in the controller compartment.
  - open the FXchain
  - select some FX in current chain, 
  - focus the arrange view, 
  - call the script
  - focus realearn
  - click button «import from clipboard» 
##### What it does: 
  Each parameter of the selected FX gets assigned a knob on the Midi Fighter Twister.
  Paging is done with side-buttons. 
  Only basic jsfx seem to work correctly atm.
</details>

#### Drums utilities
<details>
 <summary>Flam: create a flam for selected items</summary> 

`$REAPERPATH/Scripts/perken/main/drum_actions/flam.lua`
##### HOW TO USE: 
- in arrange view, select an item and call the action
##### What it does: 
- creates a flam right before the selected items, at a lower volume
- works with midi, too
![Drum Flam script demo](./gifs/drums_flam.gif)
</details>

<details>
 <summary>5 stroke: create a drum 4 stroke-flush on the selected item</summary> 

`$REAPERPATH/Scripts/perken/main/drum_actions/5stroke.lua`
##### HOW TO USE: 
- in arrange view, select an item and call the action
##### What it does: 
- creates a 4stroke right before the selected items, at a lower volume
- works with midi, too
![Drum 5stroke script demo](./gifs/drums_5stroke.gif)
</details>

<details>
 <summary>3 stroke: create a drum 2 stroke-flush on the selected item</summary> 

`$REAPERPATH/Scripts/perken/main/drum_actions/3stroke.lua`
##### HOW TO USE: 
- in arrange view, select an item and call the action
##### What it does: 
- creates a 2stroke right before the selected items, at a lower volume
- works with midi, too
![Drum 3stroke script demo](./gifs/drums_3stroke.gif)
</details>

<details>
 <summary>Crescendo selected items's volumes</summary> 

`$REAPERPATH/Scripts/perken/main/drum_actions/crescendo_items_volumes.lua`
##### HOW TO USE: 
- in arrange view, select some items (preferably next to each other) and call the action
##### What it does: 
- Tweaks the volume of the selected items to create a crescendo
![Drum Crescendo script demo](./gifs/drums_cresc.gif)
</details>

<details>
 <summary>Decrescendo selected items's volumes</summary> 

`$REAPERPATH/Scripts/perken/main/drum_actions/crescendo_items_volumes.lua`
##### HOW TO USE: 
- in arrange view, select some items (preferably next to each other) and call the action
##### What it does: 
- Tweaks the volume of the selected items to create a decrescendo
![Drum Crescendo script demo](./gifs/drums_decresc.gif)
</details>