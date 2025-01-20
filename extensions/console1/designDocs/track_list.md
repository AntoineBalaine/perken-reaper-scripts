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
  When there are multiple selected tracks and some of them correspond to the current page offset, Softube’s original console1 software has those track’s button’s LEDs blinking. Should we be doing the same? Here are three possible avenues:
  - blink LEDs of selected, light up but don’t blink the last touched track if it’s on current page.
    requires keeping a counter that’s incremented from csurf’s run().
    List of selected tracks is already up to date, I believe.
  - light up all LEDs of selected tracks
  - only light up the LED of the last touched track

Let’s go with the first option, «blink LEDs of selected…».

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
Let’s save this for later - this is not vital to this feature

# state and data
## Memory
In terms of memory management, we could use a fixed-size buffer which contains 20 track names, each of a fixed-size.
If a track name is longer than the pre-set fixed size, we can do something similar to safePrint: just replace the overflowing characters with a `…` character.
```zig
const track_name = [:0]const u8;
```
Or, maybe if we want to specify the size in advance:
```zig
const track_name = [TrackNameSz:0]const u8;
```
The advantage of fixed size strings is that it becomes easy to re-use the allocations when switching pages: we can just re-use the buffers at each page change.
All the track names need to be null-terminated: they’re going to be passed to the C++ GUI api, which expects null-terminated strings.
## Lifecycle
What should be the lifecycle of the fixed-size buffer?
Either we choose to make the allocation at the startup of the application, or we choose to make it only when the controller is instantiated.
When it comes to the de-allocation, same principle: if we want the allocation at the startup, de-alloc should be done at close-up.

## Where to store the data
We could store the track names in the fx_ctrl state, or in the globals.
Whether to display the track list should be done using a flag. Should it be in the preferences or the fx_ctrl_state or the globals?
