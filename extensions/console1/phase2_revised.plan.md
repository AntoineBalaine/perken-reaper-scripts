# Phase 2 Revised Plan - Preset System with Hierarchical State Machine

## Table of Contents

- [Overview](#overview)
- [What Needs to Be Done](#what-needs-to-be-done)
- [State Machine Architecture](#state-machine-architecture)
  - [Mode Hierarchy](#mode-hierarchy)
  - [State Structure (Pseudo-code)](#state-structure-pseudo-code)
  - [State Transitions (Pseudo-code)](#state-transitions-pseudo-code)
- [Dispatcher Actions](#dispatcher-actions)
  - [Action Hierarchy (Pseudo-code)](#action-hierarchy-pseudo-code)
  - [Dispatch Flow (Pseudo-code)](#dispatch-flow-pseudo-code)
- [Testing](#testing)
  - [Model-Based State Testing](#model-based-state-testing)
  - [Test Commands](#test-commands)
  - [Properties Verified](#properties-verified)
- [UI Panels](#ui-panels)
  - [New Panels to Implement](#new-panels-to-implement)
  - [Window Consolidation Strategy](#window-consolidation-strategy)
  - [Panels to Remove](#panels-to-remove)
  - [Panels to Modify](#panels-to-modify)
- [Implementation Order](#implementation-order)
- [Key Architectural Decisions](#key-architectural-decisions)
- [Notes](#notes)
- [Summary](#summary)

## Overview

Because the code review revealed that the user flow was incorrectly specified in the original plan, we need to redesign Phase 2 with the correct architecture. The preset button should open a module selection window first, allowing the user to choose which FX to edit, rather than assuming an FX is already selected.

Because this workflow involves three distinct UI screens that share context (module selection → mapping editing → save dialog), we implement this as a hierarchical state machine with sub-modes within the mapping_panel mode.

## What Needs to Be Done

### 1. Implement Hierarchical State Machine

Because the preset workflow has three distinct phases (browse modules, assign mappings, save preset), we need sub-modes within mapping_panel mode:

- BROWSE: Module selection window showing all 5 modules with their current FX
- ASSIGN: Mapping panel for editing parameter assignments
- SAVE: Save preset dialog with overwrite protection

### 2. Refactor UI Draw Functions to Pure Functions

Because the codebase pattern uses pure draw functions (not struct methods), we need to refactor:

- SavePresetDialog.draw() → drawSavePresetDialog()
- Follow the pattern from fx_sel_panel.ModulePopup()

### 3. Create Module Selection Window

Because the user needs to choose which module's FX to edit, we need a new window that:

- Shows all 5 modules (INPUT/GATE/EQ/COMP/OUTPT)
- Displays the current FX name loaded on each module
- Allows scrolling with encoder
- Confirms selection with SOLO button

### 4. Consolidate Windows into Single Reusable Window

Because the code review expects window reuse rather than separate windows, we need:

- Single window that transitions between three display modes
- Shared window state maintained across transitions
- Consistent styling and positioning

### 5. Update MIDI Button Mappings

Because the PRESET button should trigger the module selection window:

- PRESET button: enter mapping_panel mode in BROWSE sub-mode
- In BROWSE: encoder scrolls, SOLO selects, MUTE cancels
- In ASSIGN: existing mapping panel controls, plus Save button enters SAVE sub-mode
- In SAVE: encoder scrolls presets, SOLO confirms save, MUTE cancels

## State Machine Architecture

### Mode Hierarchy

```
mapping_panel mode
  ├─ BROWSE sub-mode (module selection)
  ├─ ASSIGN sub-mode (mapping editing)
  └─ SAVE sub-mode (save preset dialog)
```

### State Structure (Pseudo-code)

```
MappingPanelMode = enum
  BROWSE
  ASSIGN
  SAVE

MappingPanelState = struct
  sub_mode: MappingPanelMode

  // BROWSE sub-mode state
  browse_state: struct
    selected_module: ModulesList
    scroll_position_abs: u8
    scroll_position_rel: usize
    available_modules: [5]ModuleInfo  // cached info about current FX on each module

  // ASSIGN sub-mode state
  assign_state: struct
    target_fx: string
    target_module: ModulesList
    current_mappings: union(ModulesList)
      INPUT: Inpt
      GATE: Shp
      EQ: Eq
      COMP: Comp
      OUTPT: Outpt
    selected_parameter: ?u32
    selected_control: ?CC
    midi_learn_active: bool

  // SAVE sub-mode state
  save_state: struct
    name_buffer: [256]u8
    name_len: usize
    existing_presets: []string
    show_overwrite_confirm: bool
    pending_name: string
```

### State Transitions (Pseudo-code)

```
Transition Rules:

fx_ctrl mode:
  on PRESET_BUTTON pressed:
    enter mapping_panel mode with sub_mode = BROWSE
    initialize browse_state with current track's module info
    show module selection window

mapping_panel.BROWSE:
  on SOLO_BUTTON pressed:
    transition to ASSIGN sub-mode
    load current mappings for selected FX
    show mapping panel window (reuse same window)

  on MUTE_BUTTON pressed:
    exit mapping_panel mode
    return to fx_ctrl mode
    close window

mapping_panel.ASSIGN:
  on SAVE_BUTTON clicked:
    transition to SAVE sub-mode
    load existing preset names for current FX
    initialize save_state with "default" name
    show save dialog (reuse same window)

  on CANCEL_BUTTON clicked:
    exit mapping_panel mode
    return to fx_ctrl mode
    close window

mapping_panel.SAVE:
  on save confirmed:
    save mapping to disk
    update MapStore preferred mapping
    exit mapping_panel mode
    return to fx_ctrl mode
    close window

  on CANCEL_BUTTON clicked:
    return to ASSIGN sub-mode
    show mapping panel window (reuse same window)
```

## Dispatcher Actions

### Action Hierarchy (Pseudo-code)

```
// Top-level action union
ModeAction = union
  mapping_panel: MappingPanelAction
  fx_ctrl: FxCtrlAction
  // ... other modes

// Mapping panel actions (all sub-modes)
MappingPanelAction = union
  // Sub-mode transitions
  enter_browse: void
  enter_assign: struct { module: ModulesList }
  enter_save: void
  exit_to_fx_ctrl: void

  // BROWSE sub-mode actions
  browse_scroll: u8
  browse_select_module: ModulesList
  browse_confirm: void
  browse_cancel: void

  // ASSIGN sub-mode actions
  assign_select_parameter: ?u32
  assign_select_control: ?CC
  assign_toggle_midi_learn: void
  assign_add_mapping: struct { param: u8, control: CC }
  assign_remove_mapping: CC
  assign_change_module: ModulesList
  assign_request_save: void
  assign_cancel: void

  // SAVE sub-mode actions
  save_update_name: string
  save_confirm: string
  save_cancel: void
```

### Dispatch Flow (Pseudo-code)

```
function dispatch(globals: Globals, action: ModeAction):
  switch action
    case mapping_panel(mp_action):
      switch mp_action
        // Sub-mode transitions
        case enter_browse:
          globals.state.mapping_panel.sub_mode = BROWSE
          initialize_browse_state(globals)

        case enter_assign(module):
          globals.state.mapping_panel.sub_mode = ASSIGN
          load_fx_mappings_for_module(globals, module)

        case enter_save:
          globals.state.mapping_panel.sub_mode = SAVE
          initialize_save_state(globals)

        case exit_to_fx_ctrl:
          cleanup_mapping_panel_state(globals)
          globals.state.current_mode = fx_ctrl

        // BROWSE actions
        case browse_scroll(encoder_val):
          update_scroll_position(globals.state.mapping_panel.browse_state, encoder_val)

        case browse_confirm:
          selected = get_selected_module(globals.state.mapping_panel.browse_state)
          dispatch(globals, mapping_panel(enter_assign(selected)))

        case browse_cancel:
          dispatch(globals, mapping_panel(exit_to_fx_ctrl))

        // ASSIGN actions
        case assign_select_parameter(param):
          globals.state.mapping_panel.assign_state.selected_parameter = param

        case assign_add_mapping(data):
          add_mapping_to_current_mappings(globals, data.param, data.control)

        case assign_request_save:
          dispatch(globals, mapping_panel(enter_save))

        case assign_cancel:
          dispatch(globals, mapping_panel(exit_to_fx_ctrl))

        // SAVE actions
        case save_confirm(name):
          save_mapping_to_disk(globals, name)
          dispatch(globals, mapping_panel(exit_to_fx_ctrl))

        case save_cancel:
          dispatch(globals, mapping_panel(enter_assign(current_module)))
```

## Testing

We test the hierarchical state machine and action dispatcher using zlowcheck's model-based stateful testing. The /Users/antoine/Documents/personnel/experiments/zigwrap2/.claude/skills/zlowcheck-stateful skill documents how to implement these tests.

### Model-Based State Testing

The test model maintains a simplified representation of the system:

**Mode State:**
- Current mode (fx_ctrl or mapping_panel)
- Current sub-mode when in mapping_panel (BROWSE, ASSIGN, or SAVE)

**Track State:**
- FX assigned to each module (INPUT, GATE, EQ, COMP, OUTPT)
- Each FX includes:
  - FX name with module suffix (e.g., "VST: ReaComp (C1-C)")
  - List of parameters with names and current values
  - Current mapping (which parameters map to which Console1 controls)

**Browser State:**
- Selected module in BROWSE sub-mode
- Scroll position

**Edit State:**
- Modified mappings in ASSIGN sub-mode
- Preset name being saved in SAVE sub-mode

### Test Commands

Commands mirror the actions defined in the dispatcher:

**Mode Transitions:**
- EnterBrowse: press PRESET button from fx_ctrl mode
- ExitToFxCtrl: cancel or complete workflow

**BROWSE Sub-mode:**
- ScrollBrowse: encoder changes module selection
- ConfirmBrowse: SOLO button selects module and enters ASSIGN
- CancelBrowse: MUTE button exits to fx_ctrl

**ASSIGN Sub-mode:**
- AddMapping: assign FX parameter to Console1 control
- RemoveMapping: clear control assignment
- ChangeParameter: select different parameter
- RequestSave: press Save button to enter SAVE sub-mode
- CancelAssign: press Cancel to exit

**SAVE Sub-mode:**
- SavePreset: confirm save with preset name
- CancelSave: return to ASSIGN sub-mode

Each command implements checkPrecondition (when is this valid?), onModelOnly (update model during generation), and onPair (execute on system and verify sync).

### Properties Verified

zlowcheck automatically verifies:

**Transition Validity:**
- State transitions follow valid_transitions rules
- Sub-mode is only accessible when in mapping_panel mode
- Can't enter SAVE without first being in ASSIGN

**State Consistency:**
- FX names maintain correct module suffixes (as described in the `track_state.zig`validation code.)
- Mappings reference valid parameters and controls
- Selected module in BROWSE corresponds to valid FX on track

**Workflow Integrity:**
- All command sequences either complete the workflow or cancel back to fx_ctrl
- Canceling from SAVE returns to ASSIGN with unchanged state
- Saving writes correct mapping values to model

**Precondition Enforcement:**
- Commands with unsatisfied preconditions are skipped
- Invalid transitions are rejected before execution

### Test Implementation

Test file: src/tests/mapping_panel_stateful_test.zig

The test uses zlowcheck's CommandList to generate random sequences of valid commands, executes them on both the model and the actual state machine, and verifies they remain synchronized. When a test fails, zlowcheck shrinks the command sequence to the minimal failing case.

## UI Panels

### New Panels to Implement

#### 1. Module Selection Window (new: src/module_selection_panel.zig)

Because the user needs to choose which module to edit, we create a new panel that shows all modules.

Pure function signature:
```
function drawModuleSelectionPanel(
  ctx: ImGuiContext,
  state: BrowseState,
  track_state: TrackState,
  style_manager: StyleManager,
  translations: TranslationStore
) -> ?MappingPanelAction
```

Display layout:
```
Window: "Select Module to Edit"

INPUT    [VST: Some Compressor (C1-I)]  <- scrollable list
GATE     [JS: Gate Plugin (C1-S)]
EQ       [VST: FabFilter Pro-Q (C1-E)]
COMP     [VST: ReaComp (C1-C)]          <- highlighted if selected
OUTPT    [JS: Volume Smoother (C1-O)]

[Cancel]
```

Behavior:
- Encoder scrolls through 5 modules
- Current selection highlighted with inverted colors (DrawListSplitter pattern)
- SOLO button (or click) confirms selection
- MUTE button (or Cancel button) cancels
- Returns browse_confirm or browse_cancel action

#### 2. Mapping Panel Modifications (modify: src/mapping_panel.zig)

Because the mapping panel currently has its own draw method, we need to refactor it.

Current structure:
```
MappingPanel = struct
  // ... state fields

  fn draw(self: *MappingPanel, ...) -> ?MappingAction
```

New structure:
```
function drawMappingPanel(
  ctx: ImGuiContext,
  state: AssignState,
  style_manager: StyleManager,
  translations: TranslationStore
) -> ?MappingPanelAction
```

Changes needed:
- Remove struct method, convert to pure function
- Remove auto-open behavior
- Add "Save" and "Cancel" buttons at bottom
- Save button returns assign_request_save action
- Cancel button returns assign_cancel action
- Keep existing parameter assignment UI

#### 3. Save Preset Dialog Refactor (modify: src/save_preset_dialog.zig)

Because the current implementation uses a struct method, we need to refactor to pure function.

Current structure:
```
SavePresetDialog = struct
  name_buffer: [256]u8
  existing_presets: []string
  show_overwrite_confirm: bool
  pending_name: string

  fn draw(self: *SavePresetDialog, ...) -> ?SavePresetAction
```

New structure:
```
function drawSavePresetDialog(
  ctx: ImGuiContext,
  state: SaveState,
  style_manager: StyleManager,
  translations: TranslationStore
) -> ?MappingPanelAction
```

Changes needed:
- Remove struct, move state fields to SaveState in state machine
- Convert draw method to pure function
- Keep existing UI layout (preset list, text input, Save/Cancel buttons)
- Keep overwrite confirmation popup logic

### Window Consolidation Strategy

Because the code review expects window reuse, we use a single window that changes content based on sub-mode.

Main window function (new: src/mapping_panel_window.zig):
```
function drawMappingPanelWindow(
  ctx: ImGuiContext,
  globals: Globals,
  style_manager: StyleManager,
  translations: TranslationStore
) -> ?MappingPanelAction:

  apply_window_style()
  set_window_size(400, 400)

  open = true
  if begin_window("Preset Manager", &open):
    defer end_window()

    // Dispatch to appropriate sub-panel based on sub_mode
    switch globals.state.mapping_panel.sub_mode
      case BROWSE:
        return drawModuleSelectionPanel(ctx, globals.state.mapping_panel.browse_state, ...)

      case ASSIGN:
        return drawMappingPanel(ctx, globals.state.mapping_panel.assign_state, ...)

      case SAVE:
        return drawSavePresetDialog(ctx, globals.state.mapping_panel.save_state, ...)

  if not open:
    return exit_to_fx_ctrl
```

### Panels to Remove

Remove src/preset_browser_panel.zig - it's not part of the flow.

### Panels to Modify

#### 1. src/mapping_panel.zig

Current issues:
- Has draw as struct method
- May have auto-open behavior

Changes:
- Convert draw method to pure function drawMappingPanel()
- Remove auto-open logic
- Integrate into window consolidation strategy

#### 2. src/save_preset_dialog.zig

Current issues:
- Has draw as struct method
- SavePresetDialog struct holds state that should be in state machine

Changes:
- Convert draw method to pure function drawSavePresetDialog()
- Move state fields to SaveState in statemachine.zig
- Update function signature to take SaveState parameter


## Implementation Order

### Step 0: Remove Obsolete Files and Modes

Remove files that are not part of the correct flow:
- src/preset_browser_panel.zig
- src/preset_browser_actions.zig (if only used by preset_browser_panel)
- src/tests/preset_browser_tests.zig

Remove obsolete modes from src/statemachine.zig:
- Remove `preset_browser` from Mode enum
- Remove `midi_learn` from Mode enum (keep `midi_learn_active` boolean flag in MappingState)
- Remove both modes from valid_transitions map

Remove references to obsolete modes:
- Search for transitions TO preset_browser or midi_learn modes and remove them
- Remove any mode-specific handlers in src/actions.zig
- Remove any mode-specific MIDI handling in src/csurf/midi_events.zig
- Remove any mode-specific rendering in src/gui_lib.zig

### Step 1: Refactor State Machine

Because all UI changes depend on the state structure, we start here.

Files to modify:
- src/statemachine.zig

Changes:
- Add MappingPanelMode enum
- Replace MappingState with MappingPanelState structure (as shown in pseudo-code above)
- Add BrowseState, AssignState, SaveState nested structs

### Step 2: Update Actions

Because the dispatcher needs to handle sub-mode transitions, we update actions next.

Files to modify:
- src/actions.zig (modify ModeAction union)
- Create or modify src/mapping_panel_actions.zig (consolidate all mapping panel actions)

Changes:
- Define MappingPanelAction union with all sub-mode actions
- Implement dispatch handlers for each action
- Add sub-mode transition logic

### Step 3: Implement Stateful Tests

Because we have the state machine and actions defined, we implement tests before continuing with UI.

Files to create:
- src/tests/mapping_panel_stateful_test.zig

Implementation:
- Define test model with mode state, track state (FX with params and mappings), browser state, edit state
- Implement commands that mirror dispatcher actions
- Set up zlowcheck CommandList with all commands
- Run assertStateful to verify model/system synchronization

### Step 4: Create Module Selection Panel

Because this is new functionality, we implement it before modifying existing panels.

Files to create:
- src/module_selection_panel.zig

Implementation:
- Pure function drawModuleSelectionPanel()
- List all 5 modules with current FX names
- Highlight selected module
- Return appropriate actions

### Step 5: Refactor Mapping Panel

Because we need to remove struct methods, we refactor the existing mapping panel.

Files to modify:
- src/mapping_panel.zig

Changes:
- Extract draw logic into pure function
- Remove auto-open behavior
- Update to return MappingPanelAction instead of MappingAction

### Step 6: Refactor Save Preset Dialog

Because we need to follow the pure function pattern, we refactor save dialog.

Files to modify:
- src/save_preset_dialog.zig

Changes:
- Move state to statemachine.zig SaveState
- Convert draw to pure function
- Update to return MappingPanelAction

### Step 7: Implement Window Consolidation

Because we need a single window for all sub-modes, we create the wrapper.

Files to create:
- src/mapping_panel_window.zig

Implementation:
- Main window function that switches on sub_mode
- Delegates to appropriate sub-panel draw function
- Handles window-level concerns (styling, sizing, open/close)

### Step 8: Update MIDI Handlers

Because button mappings need to work with the new sub-modes, we update MIDI handlers.

Files to modify:
- src/csurf/midi_events.zig

Changes:
- Add PRESET button handler to enter mapping_panel.BROWSE
- Add sub-mode-specific button handlers
- Route encoder/button events based on current sub_mode

### Step 9: Integrate into Main GUI Loop

Because the main loop needs to render the new window structure, we integrate.

Files to modify:
- src/gui_lib.zig

Changes:
- Add mapping_panel mode rendering
- Call drawMappingPanelWindow()
- Handle returned actions

### Step 10: Update Integration Tests

Files to remove:
- src/tests/preset_browser_tests.zig (already removed in Step 0)

Files to modify:
- src/tests/mappings_integration_tests.zig (if additional integration tests are needed beyond the stateful tests from Step 3)

Changes:
- Update any existing integration tests to use new state structure
- Verify that stateful tests from Step 3 provide sufficient coverage

## Key Architectural Decisions

### 1. Hierarchical State Machine vs Flat Modes

Decision: Use hierarchical state machine (sub-modes within mapping_panel mode).

Rationale: Because the three phases (browse, assign, save) share context and form a natural workflow, grouping them under a single mode with sub-modes is clearer than having three separate top-level modes.

### 2. Pure Functions vs Struct Methods

Decision: Use pure functions for all UI draw functions.

Rationale: Because this matches the existing codebase pattern (fx_sel_panel.ModulePopup) and makes the code more testable and composable.

### 3. Single Window vs Multiple Windows

Decision: Use single window that changes content based on sub-mode.

Rationale: Because the code review expects window reuse and this provides better UX continuity (window stays in same position, same size, same styling).

### 4. State Location

Decision: All sub-mode state lives in statemachine.zig MappingPanelState.

Rationale: Because UI functions should be pure and stateless, all state belongs in the state machine. This also makes state persistence and serialization easier.

## Notes

### File Path Construction

When saving a mapping, the filepath is constructed from components: `<resource_path>/maps/<module>/<fx_name>/<preset_name>.ini`. We don't need to store a default filepath in state.

### Text Input

The TODO comment in save_preset_dialog.zig about text input not being implemented is misleading. ImGui.InputText is available in the bindings (src/reaper_imgui.zig:5877) and can be used for the preset name input field.

## Summary

Because the code review identified fundamental flow issues, this revised plan restructures Phase 2 around a hierarchical state machine with three sub-modes: BROWSE (module selection), ASSIGN (mapping editing), and SAVE (preset saving).

The main changes from the original plan are:

1. Preset button opens module selection, not preset browser
2. Single reusable window instead of multiple separate windows
3. Pure draw functions instead of struct methods
4. Hierarchical state machine with sub-modes
5. Consolidated action system for all mapping panel operations

Because these changes affect the architecture significantly, we implement in a specific order: state machine first, then actions, then UI panels, then integration. This ensures each layer has the foundation it needs from the previous layer.

The implementation will reuse existing code where possible (mapping panel, save dialog) but refactor it to match the codebase patterns and the correct user flow.
