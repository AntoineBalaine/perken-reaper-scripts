**Implementation Game Plan**:

**C. Third Phase - Integration**

1. Update existing code:
✓ Remove inline MIDI sends
✓ Replace with feedback actions
✓ Update mode transitions

2. Implement feedback triggers:
✓ State changes
- User actions
✓ DAW updates

3. Add mode-specific handlers:
- FX Control parameter updates
- Settings toggles
- Selection changes

**D. Fourth Phase - Cleanup & Enhancement**

1. Settings UI/Control Rework:
- Map preferences to track buttons
- Design consistent layout
- Implement feedback patterns

2. Add Missing Features:
- MIDI learn feedback
- Mapping panel interaction
- Enhanced visual feedback

Would you like me to:
1. Detail any specific phase?
2. Show implementation examples?
3. Discuss specific mode handling?
4. Show the feedback action handling?

======================

MIDI FDBK
Trying to survey some of the control surface functions:
```
zResetCachedVolPanStates => globals.state.fx_ctrl.vol_lastpos = 0 (inline)
zOnTrackSelection => dispatches to fx_ctrl’s update_console_for_track
zExtended:
.SETFOCUSEDFX => sets globals.state.fx_ctrl.display
.SETFXOPEN => implemented inline
.SETLASTTOUCHEDTRACK => dispatches to csurf
.SETPAN_EX => calls  globals.state.fx_ctrl.validateTrack inline
zSetPlayState => sets globals.playState, sends midi feedback inline
zSetSurfaceSolo => sends midi feedback inline
zSetSurfaceSelected => dispatches to csurf’s track_selected
zSetSurfacePan => sends midi feedback inline
zSetSurfaceVolume => sends midi feedback inline
zSetTrackListChange => dispatches to csurf’s track_list_changed
zRun => sets midi feedback inline, dispatches to midi_evts then dispatches indirectly to track_list’s blink_leds
```

What should I do here?
The inline functionalities might benefit from being moved into the csurf_actions for consistency’s sake.
Some of the actions in fx_ctrl and control surface have to send feedback to the midi side. Is it worth separating that into a midi_feedback module with its own action?
Also, some of the midi feedback we’re sending doesn’t seem to take into account the mode we’re in. When an event comes through the control surface, we want to update state as necessary, but we only want to be sending midi feedback when in fx_ctrl mode. This means that we want to be able to validate tracks, we want to load the correct mappings into state, but we need to check if we’re in fx_ctrl mode to send the feedback.
There’s other modes in which we might want to send midi feedback based on user actions.
This means that we probably want to be able to update the feedback when switching modes. If we choose to implement a midi feedback module, I would need to list the feedback to be set upon mode entry:
.fx_ctrl => update the whole console. Expect the state/mappings to be up to date. Since we’re not storing indivdual param values, we have to query those from the API.
.fx_sel => set all feedback to zero. Only the volume, solo and mute are usable.
.mapping_panel => set all feedback to zero. Then light up the currently-selected module’s corresponding track button (tr1=INPUT, tr2=SHAPE, etc.). Volume, solo and mute are usable.
.settings => set all feedback to zero - for now. I want to rework the UI and the controls so that it’s possible to set preferences from the console. All the preferences are booleans, aside from the default fx. This means that for all the preferences other than the default fx, it should be possible to assign them to some buttons (I’m thinking of track buttons here), and light their LEDs based on whether or not the option is set to true. If we’re going to be using track buttons for this, it might be worth reworking the settings panel’s UI to better match the layout of track buttons, similarly to what we did in the track_list_panel.
.midi_learn => not yet implemented.
.suspended => set all feedback to zero.

Then, we have some functionalities which ought to send midi feedback _while_ we’re in a mode:
.settings => light on/off leds based on options getting toggled
.mappings => tbd
.midi_learn => tbd
.suspended => do nothing
.fx_sel => do nothing: when scrolling using the volume knob, the console updates its own feedback and _then_ sends us the value.
.fx_ctrl => there’s a whole list of events coming from the control surface which need to be handled, and there’s a few others coming from the UI as well. And then, there’s the case of midi inputs which either require special handling on our end, or which get updated automatically by the console - such as when it sets fx param values.

What I’m interested in at this point, is:
1.explain in plain english: what is the better approach for this ? Should the midi output carry its own set of actions?
2. if we do go with a midi output module, give me a plain english game plan for impementing all the aforementioned functionalities (on state entry feedback, mid-state feedback), module per module.
