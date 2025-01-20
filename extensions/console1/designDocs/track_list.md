TRACK LIST
I want to implement the track list feature for the console.

The track list is a list of 20 track names.
The fx_ctrl state has a page_offset variable called 
```zig
current_page: u8 = 0, // 0-based page number
```

# hardware:
## midi input:
The console has a pgup and pgdn down button which modifies the current_page offset.

When the page offset gets modified, 
if the user increments the page number (with pgup) and the new page offset corresponds to tracks numbers which are superior to the total track numbers in the project, then we should revert to page 0. That’s page folding.
If the user decrements the page number (with pg_up) and the new page offset is inferior to zero, then we should revert to the last page in the project. Caveat this: we’re using unsigned integers to store the page offset, so we’ll have to handle this with careful logic. This is also page folding logic.

Once we have the new page number, we should query the API for the track numbers for which we want to get the names. 
I have an initial implementation which could serve as inspiration, though it’s a bit broken.

## midi feedback:
1. when multiple tracks are selected
  When there are multiple selected tracks and some of them correspond to the current page offset, Softube’s original console1 software has those track’s button’s LEDs blinking. Should we be doing the same?

2. when the user selects a track
  - by clicking in the track list panel
  - by clicking on the hardware buttons 
We should light up the LED of that track button, and turn off the LEDs of all the other track buttons.
Light up an LED means: send feedback to the controller with value 127.
Turn off an LED means: send feedback to the controller with value 0.

# Queries:
these are some the queries we should use, from the reaper API:
```zig
pub var CountTracks: *fn (projOptional: ReaProject) callconv(.C) c_int = undefined; //  (proj=0 for active project) 
pub var GetTrackName: *fn (track: MediaTrack, bufOut: [*:0]const u8, bufOut_sz: c_int) callconv(.C) bool = undefined;
```

# track list GUI panel:
displays a list of 20 tracks in the session which corresponds to the current_page offset.
The format for each element in the list is:
`<offset number> <track name>`
By offset number I mean: display the number which, if clicked on the hardware console, would trigger the selection of the track.
This means that the user gets to see the offset numbers, but does not actually see reaper’s track numbers

Clicking one of the elements in the list selects the track.
Since my gui framework doesn’t allow rotated text, the list has to be vertical. 
Which means that the list has to be docked vertically, in a window other than the fx_ctrl’s.
To do: figure out the correct dock number for this. 

Should the track list be displayed only in fx ctrl mode? This would probably be the simplest approach.
If the user chooses to hide the fx_ctrl gui but still wants to see the track list, how should we go about implementing this?
This might require a refactor, because of the way I have set up the GUI windows currently.

# preferences
we should implement some preferences which allows to:
- toggle the display of the track list
- focus page’s tracks in the tcp when paginating
  When this is enabled, when the user selects a track, reaper’s TCP (track control panel) should focus the 20 tracks which correspond to the page offset.
  «Focus» here means: focus them in reaper’s UI, adjust the track heights (zoom level?) to fit all 20 tracks in the TCP.


# What if some of the tracks in the track list have children?
We shouldn’t have to worry about that: reaper’s track number remain sequential, even for children.
However, we might want to provide the possibility for the user to convert their parent/children tracks into busses/sends.
This would have to be done with an action in the actions list.
I have a lua script that does this - though its logic breaks on edge cases or past certain levels of nesting, we could use it as inspiration.
