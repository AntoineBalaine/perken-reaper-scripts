---
name: implementing-actions
description: Step-by-step guide for implementing new actions in modes, covering action definition, dispatch integration, handler implementation, and integration with MIDI, GUI, and REAPER callbacks. Use in conjunction with state-machine-architecture skill.
---

# Implementing Actions

This skill provides a step-by-step guide for implementing new actions in the REAPER Console1 extension. For an understanding of the overall state machine architecture and event flow, refer to the state-machine-architecture skill.

## Step 1: Define the Action Type

Actions are defined in mode-specific files as union types. Each mode has its own action union that enumerates all possible actions for that mode.

Location: `src/<mode>_actions.zig`

Example from `src/transport_actions.zig` (lines 36-56):

```zig
pub const TransportAction = union(enum) {
    automation_mode: AutomationMode,
    grid: u8,
    snap_tgl,
    jog: u8,
    // etc.
};
```

When defining your action:
- Use empty variants (e.g., `snap_tgl`, `loop_end`) for actions that require no additional data
- Use payloaded variants (e.g., `grid: u8`, `automation_mode: AutomationMode`) when the action needs data to operate on
- The payload can be a primitive type, a struct, or another union depending on the action's needs

## Step 2: Add Action to ModeAction Union

Because the dispatcher routes all actions through a central function, your mode-specific action must be wrapped in the ModeAction union.

Location: `src/actions.zig` (lines 43-62)

The ModeAction union wraps all mode-specific action types:

```zig
pub const ModeAction = union(enum) {
    // FX Control Mode
    fx_ctrl: FxCtrlAction,

    // FX Selection Mode
    fx_sel: FxSelActions,
    transport: TransportAction,
    // Mapping Mode
    mapping: MappingAction,

    // Settings Mode
    settings: SettingsActions,
    default_fx_sel: FxSelActions,
    Csurf: CsurfAction,
    // Mode transitions
    change_mode: Mode,
    set_fx_ctrl_gui,
    track_list: TrackListAction,
    midi_out: MidiOutAction,
};
```

If you are adding an action to an existing mode, this step is already complete. If you are creating a new mode, you need to add a variant to this union.

## Step 3: Update Central Dispatcher

The central dispatcher routes actions to mode-specific handlers based on the ModeAction variant.

Location: `src/actions.zig` (starting at line 65)

The dispatch function uses a switch on the ModeAction to route to the appropriate handler:

```zig
pub fn dispatch(app: *Globals, action: ModeAction) void {
    switch (action) {
        .change_mode => |new_mode| {
            // Handle mode transitions
            // ...
        },
        else => |mode_action| {
            if (app.state.current_mode == .suspended) return;
            switch (mode_action) {
                .fx_ctrl => |fx_action| fxCtrlActions(app, fx_action),
                .fx_sel => |sel_action| fx_sel_actions.fxSelActions(app, sel_action),
                .transport => |trspt_act| transportAction(app, trspt_act),
                .mapping => |map_action| mapping_actions.mappingActions(app, map_action),
                .settings => |settings_action| settings_actions.settingsActions(app, settings_action),
                // ...
            }
        },
    }
}
```

If you are adding an action to an existing mode, this step is already complete. If you are creating a new mode, you need to add a case to this switch and call your mode's handler function.

## Step 4: Implement Handler Logic

The handler function processes the action and performs the necessary state updates and external system calls.

Location: `src/<mode>_actions.zig`

The typical handler pattern follows this structure:

1. Parse the action payload using a switch statement
2. Update state in `globals.state.<mode>`
3. Call REAPER APIs via `pReaper.zig` (with reentrancy guard) or direct `reaper` module
4. Dispatch MIDI feedback actions if needed
5. Log significant state changes

Example of a simple action from `src/transport_actions.zig` (lines 230-233):

```zig
.loop_start => {
    pReaper.Main_OnCommand(.{ RprCmds.ID_LOOP_SETSTART, 0 });
    log.debug("Transport: loop_start", .{});
},
```

Example of a complex action from `src/transport_actions.zig` (lines 61-79):

```zig
.grid => |new_pos| {
    var pos_rel: u8 = globals.state.transport.grid;
    if (utils.calculateNewScrollPosition(c_int, &globals.state.transport.grid, &pos_rel, new_pos, 127, null)) |delta| {
        globals.state.transport.grid = pos_rel;

        // Adjust grid size based on delta
        if (delta > 0) {
            pReaper.Main_OnCommand(.{ RprCmds.ID_GRID_BY2, 0 }); // Grid: Adjust by 2x
        } else if (delta < 0) {
            pReaper.Main_OnCommand(.{ RprCmds.ID_GRID_BY1_5, 0 }); // Grid: Adjust by 1/2
        }

        // Send MIDI feedback if wrapped
        if (new_pos != globals.state.transport.grid) {
            actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Comp_Release, .value = globals.state.transport.grid } } });
        }

        log.debug("Transport grid: abs={d} delta={d}", .{ globals.state.transport.grid, delta });
    }
},
```

## Step 5: Integrate Event Sources

Actions can be triggered from three sources: MIDI input, REAPER callbacks, and GUI interactions.

### Step 5a: MIDI Input Integration

MIDI input from the Console1 hardware controller is decoded and routed to actions based on the current mode.

Location: `src/csurf/midi_events.zig` and mode-specific MIDI handlers like `src/csurf/midi_events_fxctrl.zig`

Example from `src/csurf/midi_events.zig` (line 126):

```zig
.transport => {
    switch (cc) {
        .Eq_LoMidGain => actions.dispatch(globals, .{ .transport = .{ .jog = val } }),
        .Eq_HiMidGain => actions.dispatch(globals, .{ .transport = .{ .jog_item = val } }),
        .Eq_HiGain => actions.dispatch(globals, .{ .transport = .{ .jog_marker = val } }),
        // ...
    }
},
```

To integrate MIDI input for your action:

1. Identify which MIDI CC value corresponds to the control you want to map
2. Add a case to the switch statement in the appropriate mode handler
3. Create the action with the appropriate payload (often transforming the raw CC value)
4. Dispatch the action

### Step 5b: REAPER Callback Integration

REAPER invokes callbacks when DAW events occur, such as track selection changes or FX parameter modifications.

Location: `src/csurf/control_surface.zig`

Example from `src/csurf/control_surface.zig` (lines 227-231):

```zig
export fn zOnTrackSelection(trackid: MediaTrack) callconv(.C) void {
    if (ignore_notifications) return;
    actions.dispatch(getGlobals(), .{ .fx_ctrl = .{ .on_track_entry = trackid } });
}
```

To integrate REAPER callbacks for your action:

1. Identify which REAPER control surface callback corresponds to the event you want to handle
2. Implement or update the callback function (these are exported C functions that REAPER calls)
3. Check the `ignore_notifications` flag to prevent feedback loops (this flag is set when your extension is making REAPER API calls that would trigger callbacks)
4. Create and dispatch the action with the appropriate payload

### Step 5c: GUI Integration

GUI panels return optional actions when users interact with widgets. Because the GUI runs on a timer and renders the current state, interactions flow through the panel functions.

Location: `src/<mode>_panel.zig`

Example from `src/fx_ctrl_panel.zig` (lines 176-178):

```zig
var gain_prm = fx_state.values.get(.Inpt_Gain).?.param;
if (try Knobs.drawWidget(ctx, &gain_prm.normalized, gain_display_label, .{ ... })) {
    rv = .{ .cc = .Inpt_Gain, .value = gain_prm.normalized };
}
```

The panel function returns an optional `WidgetInput` (or mode-specific input type), which is then converted to a `ModeAction` in `src/gui_lib.zig` and dispatched via the ImGui loop in `src/imgui_loop.zig` (lines 86-105).

To integrate GUI interactions for your action:

1. Add the widget to the appropriate panel function
2. Check if the widget was interacted with (widgets return true when modified)
3. Return the appropriate input struct with the CC identifier and new value
4. The GUI loop will automatically convert this to a `panel_input` action and dispatch it

## Step 6: Implement MIDI Feedback

Because the Console1 hardware controller has LEDs on knobs and buttons, you need to send MIDI feedback to keep the hardware state synchronized with the software state.

Location: `src/midi_out.zig`

Example from `src/midi_out.zig` (lines 41-58):

```zig
pub fn sendMidiFeedback(globals: *Globals, action: MidiOutAction) void {
    log.debug("send midi feedback: {s}", .{@tagName(action)});
    if (globals.m_midi_out) |midi_out| {
        switch (action) {
            .mode_entry => |mode| onModeEntry(globals, mode, midi_out),
            .set_param => |param| setParamLED(param.cc, param.value, midi_out),
            // ... other feedback actions
        }
    }
}

fn setParamLED(cc: c1.CCs, value: u8, midi_out: reaper.midi_Output) void {
    c.MidiOut_Send(midi_out, 0xb0, @intFromEnum(cc), value, -1);
}
```

LED conventions:
- For knobs: send the actual parameter value (0-127)
- For buttons: send 0x7f for on/lit, 0x00 for off/unlit

To implement MIDI feedback for your action:

1. In your action handler, after updating state and calling REAPER APIs, dispatch a MIDI feedback action
2. If the feedback pattern is not already supported by `MidiOutAction`, add a new variant
3. Implement the feedback logic in the `sendMidiFeedback` switch statement
4. Use the `setParamLED` helper for simple CC updates

## Step 7: Add State Fields if Needed

If your action requires persistent state that survives across invocations, you need to add fields to the mode-specific state struct.

Location: `src/statemachine.zig` or mode-specific action files

Example from `src/transport_actions.zig` (lines 25-34):

```zig
pub const TransportState = struct {
    jog: u8 = 64,
    jog_item: u8 = 64,
    jog_marker: u8 = 64,
    zoom_horizontal: u8 = 64,
    zoom_vertical: u8 = 64,
    rate: u8 = 64,
    tr_sel: u8 = 0,
    grid: u8 = 0,
};
```

The state is typically used to track:
- Current values of relative controls (like jog wheels) that need to wrap around
- Toggle states for buttons
- Selected indices for lists or enums
- Cached data that should persist across actions

The state struct is embedded in the global `State` struct in `src/statemachine.zig` and is initialized when the extension loads.
