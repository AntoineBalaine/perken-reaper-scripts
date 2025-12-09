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

---

## Context Manifest

### How The Current System Works

#### State Machine Architecture (src/statemachine.zig)

The application uses a centralized state machine with a flat Mode enum that defines all possible application states. The current mode is stored in `State.current_mode`, which is a value from the `Mode` enum. This enum includes modes like `fx_ctrl` (FX control), `fx_sel` (FX selection), `mapping_panel` (mapping configuration), `preset_browser` (preset browsing), `midi_learn` (MIDI learning), `settings`, `transport`, and `suspended`.

The state machine enforces valid transitions through the `valid_transitions` map, which is an `EnumMap(Mode, []const Mode)` that specifies which modes can transition to which other modes. For example, `fx_ctrl` mode can transition to `settings`, `fx_sel`, `mapping_panel`, `preset_browser`, `suspended`, and `transport`. The `validateTransition()` function checks this map before allowing any mode change. Mode transitions happen through the `dispatch()` function in `actions.zig`, which validates the transition and updates `State.current_mode`.

Each mode has its own state structure stored in the main `State` struct. For example, `fx_ctrl: FxControlState`, `fx_sel: FxSelectionState`, `preset_browser: PresetBrowserState`, and `mapping: MappingState`. These state structures persist across mode changes, allowing the application to return to previous states without losing context.

The current `MappingState` structure (lines 130-169) contains fields for the target FX name, current mappings (as a union of module-specific mapping types), an optional target mapping filepath, selected parameter/control, and a `midi_learn_active` boolean flag. The mappings are stored as a union tagged by `ModulesList` (INPUT, GATE, EQ, COMP, OUTPT), where each variant contains the corresponding mapping structure (Inpt, Shp, Eq, Comp, or Outpt).

The current `PresetBrowserState` structure (lines 117-123) contains the target FX name, target module, list of available presets, and scroll positions (absolute and relative). This state is populated when entering preset_browser mode and is used to display the preset list in the UI.

#### Action System Architecture (src/actions.zig)

The action system uses a hierarchical union type `ModeAction` that represents all possible actions in the application. The top-level union has variants for each mode (fx_ctrl, fx_sel, mapping, preset_browser, settings, etc.) plus special variants like `change_mode` for mode transitions, `set_fx_ctrl_gui` for toggling GUI visibility, `track_list` for track list operations, and `midi_out` for MIDI feedback.

Actions flow through a single entry point: the `dispatch()` function (lines 62-133). This function pattern-matches on the action type and routes it to the appropriate handler. For mode changes, it validates the transition using `validateTransition()`, updates the state, manages the ImGui registration (calls `imgui_loop.register()` or `imgui_loop.reset()` based on GUI visibility settings), logs the state change, and sends MIDI feedback. For mode-specific actions, it dispatches to specialized handler functions like `fxCtrlActions()`, `fx_sel_actions.fxSelActions()`, `mappingActions()`, `presetBrowserActions()`, etc.

The current mapping actions are defined in `src/mapping_actions.zig` as the `MappingAction` union (lines 11-32). This includes actions for parameter selection (`select_parameter`), control selection (`select_control`), MIDI learn toggling (`toggle_midi_learn`), mapping operations (`add_mapping`, `remove_mapping`), and panel operations (`save_mapping`, `cancel_mapping`, `change_module`). The `mappingActions()` function (lines 34-247) handles these actions by directly modifying `globals.state.mapping`.

When saving a mapping (lines 183-226), the system extracts the module type from the current_mappings union, converts it to a `TaggedMapping`, calls `globals.map_store.saveToFile()` to write the mapping to disk, calls `globals.map_store.get()` to reload the mapping into cache (though there's a comment questioning why this read is necessary instead of just putting directly into the store), cleans up the mapping panel if it exists, and dispatches a mode change back to `fx_ctrl`.

The current preset browser actions are defined in `src/preset_browser_actions.zig` as the `PresetBrowserAction` union (lines 12-19): `scroll`, `select_preset`, `close`, and `open_for_current_fx`. The `presetBrowserActions()` function handles these, with `open_for_current_fx` (lines 23-101) finding the first module with an assigned FX, getting the FX name from REAPER, loading the preset list using `mapping_browser.getMappingNames()`, populating `globals.state.preset_browser`, and dispatching to preset_browser mode.

#### Mapping Panel Implementation (src/mapping_panel.zig)

The mapping panel is implemented as a struct `MappingPanel` (lines 22-39) that holds FX parameters as an `ArrayList(FxParameter)`. Each `FxParameter` contains an index and a name. The panel has a `loadParameters()` method (lines 41-64) that queries REAPER for all parameters of an FX using `reaper.TrackFX_GetNumParams()` and `reaper.TrackFX_GetParamName()`, storing them in the ArrayList.

The main rendering happens through the `mappingPanel()` function (lines 102-120), which is called from the GUI loop when in mapping_panel mode. This function creates an ImGui group, calls the `controls()` function to render the module-specific control panels, calls `formControls()` to render the bottom panel with buttons and dropdowns, and returns any `MappingAction` that was triggered by user interaction.

The `controls()` function (lines 123-162) uses an inline for loop to render all five module panels (INPUT, GATE, EQ, COMP, OUTPT). It disables inactive panels using `imgui.BeginDisabled()` and `imgui.EndDisabled()`, only processing actions from the active panel (determined by `globals.state.mapping.current_mappings`). Each module has its own specialized panel function (e.g., `compMappingPanel()`, `eqMappingPanel()`) that renders the appropriate knobs and buttons using the `mappingWidget()` helper.

The `mappingWidget()` function (lines 244-288) is the core of the control rendering. It takes a CC enum value, a label, a variant (button or knob), and a disabled flag. It gets the current mapping using `getControlMapping()`, which returns the parameter index assigned to that control (or null if unmapped). It renders either a mapping button or mapping knob (different components) that display the current assignment and allow the user to select a new parameter. When the user interacts with the widget, it returns a `MappingAction` (either `select_control`, `add_mapping`, or `remove_mapping`).

The `formControls()` function (lines 201-242) renders the bottom control bar with a combo box for module selection (allowing users to switch between INPUT/GATE/EQ/COMP/OUTPT), a MIDI Learn button, a Save button, and a Cancel button. Each button returns the corresponding `MappingAction` when clicked.

The mapping panel currently does NOT auto-open. The current flow requires manual navigation to mapping_panel mode. The panel operates on `globals.state.mapping`, which must be initialized before entering mapping_panel mode.

#### Save Preset Dialog (src/save_preset_dialog.zig)

The save dialog is implemented as a struct `SavePresetDialog` (lines 14-19) with state fields: a name buffer (256 bytes), list of existing presets, boolean flag for showing overwrite confirmation, and the pending name. The `init()` method (lines 24-49) takes an allocator, FX name, module, and resource path. It initializes the name buffer with "default", calls `mapping_browser.getMappingNames()` to load existing presets for the FX, and returns the dialog. The arena allocator is used for existing_presets, so no explicit deinit is needed.

The `draw()` method (lines 52-149) is a struct method that takes ImGui context and style manager. It applies window styling, sets window size to 400x300, creates the window with title "Save Preset", lists existing presets if any exist, shows preset name text (with a TODO comment about text input not being implemented, though the comment is misleading because `imgui.InputText` IS available in the bindings at line 5877 of reaper_imgui.zig), renders Save and Cancel buttons, and handles the overwrite confirmation popup.

The overwrite logic (lines 89-108) checks if the name is empty (though this check references a `name_len` field that doesn't exist in the struct), searches `existing_presets` to see if the name already exists, shows the confirmation popup if it exists and confirmation hasn't been shown yet, or returns the save action if confirmation has been shown or the name is new. The confirmation popup (lines 118-143) uses `imgui.BeginPopup()` to show a modal with Yes/No buttons.

The dialog returns a `SavePresetAction` union (lines 9-12) with variants `save` (containing the preset name) or `cancel`. The caller is responsible for actually saving the mapping file using the returned name.

#### FX Selection Panel Pattern (src/fx_sel_panel.zig)

The fx_sel_panel demonstrates the pure function pattern that we need to follow. The main function is `ModulePopup()` (lines 159-212), which takes the ImGui context, module type, mappings (as a StringArrayHashMapUnmanaged), current index, display_menus flag, DrawListSplitter pointer, style manager, and translations store. This is a pure function - it doesn't hold any state internally.

The function applies window styling using `PushWindowStyle()`, sets window size to 400x300, creates the window with a var for open tracking, renders the module name as text, iterates through the mappings to render selectables (highlighting the current selection using the DrawListSplitter pattern), optionally renders menus for browsing all available FX, and returns an `FxSelActions` union value or null. If the window is closed (open becomes false), it returns `.close_browser`.

The highlighting pattern uses `drawInvertedSlctblColors()` (lines 214-257) to draw a filled rectangle behind the selected item in one color and the text on top in the inverted color. This requires the DrawListSplitter to be passed in as a pointer, which is managed by the caller (stored in `globals.drwls_splitter`).

This pattern is important because it means UI state (like the open flag, the DrawListSplitter) is managed by the caller, not by the draw function. The draw function is stateless and can be called every frame without side effects.

#### MIDI Event Handling (src/csurf/midi_events.zig)

MIDI events are processed through the `OnMidiEvent()` function (lines 17-161), which is called by the REAPER control surface wrapper for every incoming MIDI message. The function parses the MIDI message to extract the CC number and value (handling running status), converts the CC number to the `c1.CCs` enum, and dispatches based on the current mode.

For `fx_ctrl` mode (lines 42-49), most CCs are dispatched as `fx_ctrl` actions with `.midi_input`. However, the `Inpt_preset` button is handled specially - it dispatches `.preset_browser = .open_for_current_fx` instead of a regular MIDI input action. This is the entry point for the preset browser flow.

For `fx_sel` mode (lines 51-69), the encoder (Out_Vol) dispatches a scroll action, SOLO button selects the FX at the current scroll position, MUTE button closes the browser, and track buttons (Tr_tr1 through Tr_tr5) toggle the module browser for each module (INPUT, GATE, EQ, COMP, OUTPT). The settings button (Tr_tr20) opens settings.

For `preset_browser` mode (lines 98-111), the encoder scrolls through presets, SOLO button selects the preset at the current scroll position (calling `dispatch()` with `.preset_browser = .{ .select_preset = ... }`), and MUTE button closes the preset browser.

The mapping_panel mode is NOT handled in this MIDI event handler. This means the mapping panel doesn't currently have MIDI button mappings for its operations. All interaction happens through the GUI.

#### Track State and Module Management (src/track_state.zig)

The track state system manages FX instances and their module assignments. The core struct `TrackState` (lines 25-42) contains an array of `fx_states` (each with an fx_index and ActiveModules bit mask), an `fx_count`, and `module_locations` (an EnumArray mapping each module to its Location). A `Location` (lines 18-21) contains the FX index and an optional TaggedMapping.

The `validateTrack()` function (lines 58-95) is the main entry point. It resets the track state, gets the FX count from REAPER, scans the FX chain looking for FX with C1 suffixes (e.g., "(C1-C)" for COMP), parses the suffixes using `parseC1Suffix()`, analyzes coverage to determine which modules are provided by which FX, reorders FX if necessary (adding missing modules based on preferences), and updates track state with the final module locations and mappings.

The `parseC1Suffix()` function (lines 97-120) looks for the last occurrence of "(C1-" in the FX name, extracts the module identifier characters between "(C1-" and ")", and returns the first valid module character (I=INPUT, S=GATE, E=EQ, C=COMP, O=OUTPT). This allows FX names like "ReaComp (C1-C)" to be identified as providing the COMP module.

The `analyzeCoverage()` function (lines 911-940) iterates through parsed FX, checking if each module is already covered. If a module is found twice, it calls `removeDuplicateModule()` to strip the suffix from the duplicate. Otherwise, it records the FX index and GUID as providing that module. This ensures each module has at most one provider.

The `reorderFx2()` function (lines 1151-1356) handles both insertion and reordering. If `preferences.auto_insert_modules` is enabled, it inserts missing modules using default FX from settings, respecting the user's preferred module order (S-C-EQ, S-EQ-C, or EQ-S-C). If `preferences.auto_reorder_modules` is enabled, it moves FX to the canonical positions (INPUT first, then middle modules in preferred order, then OUTPT last). The function uses `applyInsert()` and `applyMove()` to update coverage indices after each operation.

The `updateTrackState()` function (lines 990-1033) takes the final coverage and populates the track_state fields. For each module in the coverage, it gets the original FX name from REAPER, queries the MapStore for the mapping, sets the module_locations entry with the fx_index and mapping, creates an ActiveModules struct with just that module set, and adds an entry to fx_states.

#### Mapping Storage System (src/mappings.zig)

Mappings are stored on disk in a hierarchical directory structure: `<resource_path>/maps/<MODULE>/<fx_name>/<mapping_name>.ini`. For example, `maps/COMP/VST__ReaComp_(Cockos)/default.ini`. The FX name is sanitized to remove invalid filesystem characters.

The `MapStore` struct (lines 114-122) manages mappings with lazy loading. It has a hash map for each module type (COMP, EQ, INPUT, OUTPT, GATE) that maps FX names to `FxMaps`. The `FxMaps(T)` generic struct (lines 97-109) contains a hash map of mapping filepaths to optional mapping values and a `preferred_mapping` field that points to one of the filepaths.

The `get()` method (lines 203-272) returns the preferred mapping for an FX. It first checks if the FX exists in the module's hash map. If found, it looks up the preferred_mapping in the FxMaps.mappings hash map and returns it. If not found, it calls `getMap()` to load the mapping from disk with the name "default".

The `getMap()` method (lines 370-495) constructs the filepath using the sanitized FX name, module name, and mapping name. It opens the file, parses it using the ini parser, creates the appropriate mapping struct (Comp, Eq, Inpt, Outpt, or Shp), gets or creates an entry in the module's hash map (creating an FxMaps if this is the first mapping for this FX), puts the mapping into FxMaps.mappings keyed by the filepath, sets preferred_mapping to this filepath if it's the first one, and returns the TaggedMapping.

The `saveToFile()` method (lines 566-644) takes a module, FX name, TaggedMapping, and mapping name. It sanitizes the FX name, creates the directory structure (maps/<MODULE>/<fx_name>/), constructs the full filepath with the mapping name, creates or truncates the file, and writes each field of the mapping struct as "field_name = value\n" using `formatOptionalU8()` to handle optional u8 fields.

The `setPreferredMapping()` method (lines 277-330) updates which mapping is preferred for an FX. It looks up the FX in the module's hash map, validates that the specified filepath exists in FxMaps.mappings, and updates preferred_mapping to point to that filepath. This doesn't change what's in memory - it just changes which mapping is returned by `get()`.

The system uses arena allocators for most string storage. The MapStore takes an allocator in `init()`, and all FX names and filepaths are allocated with this allocator. In tests, this is an arena that gets cleaned up at the end of the test. In production, it's `globals.arena`, which persists for the lifetime of the application.

#### GUI Loop Integration (src/gui_lib.zig)

The main GUI rendering happens in the `main()` function (lines 24-243), which is called every frame by the ImGui integration. It takes the ImGui context, globals, window flags, and style manager. The function creates the main window titled "CONSOLE1", renders the ButtonsBar, handles style editor panels if open, and switches on the current mode to render the appropriate panel.

For `mapping_panel` mode (lines 172-176), it calls `mapping_panel.mappingPanel(ctx, globals, &globals.translations)` and returns the resulting `MappingAction` wrapped in `.{ .mapping = map_action }`. This is a simple passthrough - the mode-specific rendering is delegated to the panel function.

For `preset_browser` mode (lines 143-171), it first renders the fx_ctrl panel in the background (similar to fx_sel mode), handles encoder and button inputs that operate on the preset browser state, and then calls `preset_browser_panel.PresetBrowserPopup()` to render the preset browser window on top. The encoder (Out_Vol) scrolls through presets, SOLO button selects the preset at current scroll position, and MUTE button closes the browser.

The pattern shows that mode rendering can be layered - preset_browser renders fx_ctrl underneath, then adds its own window on top. The same pattern is used for fx_sel mode (lines 108-142), which also renders fx_ctrl underneath.

Actions returned from panel rendering are returned up to the caller, which then dispatches them through `actions.dispatch()`. This creates a loop: GUI renders -> user interacts -> action returned -> dispatch handles action -> state updated -> GUI re-renders with new state.

#### Module and FX Data Structures

The `ModulesList` enum (lines 14-39 in statemachine.zig) represents the five module slots: INPUT, GATE, EQ, COMP, OUTPT. Each has helper methods `toModulePrefixChar()` and `toModulePrefix()` to convert to the single-character prefix used in C1 suffixes (I, S, E, C, O).

Module-specific mapping structures are defined in mappings.zig. Each contains optional u8 fields for parameter indices:
- `Comp` (lines 12-21): Comp_Attack, Comp_DryWet, Comp_Ratio, Comp_Release, Comp_Thresh, Comp_comp
- `Eq` (lines 23-38): Eq_HiFrq, Eq_HiGain, Eq_HiMidFrq, Eq_HiMidGain, Eq_HiMidQ, Eq_LoFrq, Eq_LoGain, Eq_LoMidFrq, Eq_LoMidGain, Eq_LoMidQ, Eq_eq, Eq_hp_shape, Eq_lp_shape
- `Inpt` (lines 40-52): Inpt_Gain, Inpt_HiCut, Inpt_LoCut, Inpt_disp_mode, Inpt_disp_on, Inpt_filt_to_comp, Inpt_phase_inv, Inpt_preset
- `Outpt` (lines 54-64): Out_Drive, Out_DriveChar, Out_Pan, Out_Vol
- `Shp` (lines 66-74): Shp_Gate, Shp_GateRelease, Shp_Punch, Shp_hard_gate, Shp_shape, Shp_sustain

Each mapping struct includes a `version` field (u8) with the current format version (set to 1).

The `TaggedMapping` union (lines 77-93) wraps these mapping types, tagged by ModulesList. This allows passing around mappings generically without losing type information about which module they belong to.

The `c1.CCs` enum (in c1.zig, referenced throughout) represents all Console1 control change numbers. Each CC is named after its module and function (e.g., Comp_Attack, Eq_HiFrq, Inpt_Gain). The CC enum has methods like `toModule()` to determine which module a CC belongs to.

#### zlowcheck Test Infrastructure (src/tests/zlowcheck.zig, .claude/skills/zlowcheck-stateful/)

zlowcheck is a property-based testing library used for model-based stateful testing. The test pattern involves defining a simplified Model that represents correct behavior, defining Commands that operate on both the Model and the System Under Test, generating random command sequences, executing commands on both Model and SUT, and verifying they remain synchronized.

Commands implement three methods:
1. `checkPrecondition(model: *Model) bool` - Returns true if the command can be executed given the current model state
2. `onModelOnly(model: *Model) void` - Updates the model during command generation phase
3. `onPair(model: *Model, sut: *System) !bool` - Executes the command on the SUT, updates the model, and returns true if they're synchronized

The test setup creates command instances, wraps them with `Command(Model, System).init()`, generates a command sequence using `CommandList(Model, System).init()` with random bytes, and runs `assertStateful()` which executes the sequence and reports failures.

When a test fails, zlowcheck automatically shrinks the command sequence to find the minimal failing case. This makes debugging much easier because you see the smallest sequence of operations that triggers the bug.

For the mapping panel hierarchical state machine, we need to test:
- Mode transitions (fx_ctrl -> mapping_panel.BROWSE, BROWSE -> ASSIGN, ASSIGN -> SAVE, etc.)
- State consistency (selected module, selected parameter, current mappings)
- Workflow integrity (canceling returns to correct state, saving writes correct data)
- Precondition enforcement (can't save without being in ASSIGN mode, can't confirm browse without selecting module)

### What Needs to Be Implemented for Phase 2

#### Hierarchical State Machine Structure

The current flat Mode enum needs to be extended to support sub-modes within mapping_panel mode. We need a new enum `MappingPanelMode` with variants BROWSE, ASSIGN, and SAVE. The `MappingState` struct needs to be replaced with `MappingPanelState` containing:
- `sub_mode: MappingPanelMode` - current sub-mode
- `browse_state: BrowseState` - module selection state
- `assign_state: AssignState` - mapping editing state
- `save_state: SaveState` - preset saving state

The `BrowseState` needs fields for selected_module (ModulesList), scroll positions, and cached module info (current FX on each module). The `AssignState` needs the existing mapping state fields (target_fx, target_module, current_mappings, selected_parameter, selected_control, midi_learn_active). The `SaveState` needs fields for the preset name buffer, list of existing presets, overwrite confirmation flag, and pending name.

The state transitions need to be updated. The valid_transitions map currently allows mapping_panel to transition to fx_sel, fx_ctrl, and suspended. We need to add internal transitions between sub-modes that aren't represented in the Mode enum. These will be handled by the action dispatcher checking the current sub_mode and updating it directly.

#### Action System Refactoring

The current separate `MappingAction` and `PresetBrowserAction` unions need to be consolidated into a single `MappingPanelAction` union that handles all sub-modes. This union needs variants for:
- Sub-mode transitions: enter_browse, enter_assign, enter_save, exit_to_fx_ctrl
- BROWSE actions: browse_scroll, browse_select_module, browse_confirm, browse_cancel
- ASSIGN actions: all current MappingAction variants (select_parameter, select_control, toggle_midi_learn, add_mapping, remove_mapping, change_module, assign_request_save, assign_cancel)
- SAVE actions: save_update_name, save_confirm, save_cancel

The `mappingActions()` function in mapping_actions.zig needs to be updated to handle the consolidated action union. It needs to switch on the sub_mode and only process actions that are valid for the current sub_mode. Sub-mode transitions need to be handled explicitly, with proper state initialization (e.g., when entering BROWSE, populate browse_state with current module info; when entering SAVE, load existing preset names).

The preset_browser related actions need to be removed from the main ModeAction union since preset browsing is being eliminated in favor of the mapping panel flow.

#### UI Panel Refactoring

The `MappingPanel` struct with its `loadParameters()` method needs to be eliminated. Instead, parameter loading needs to happen during state initialization, storing the parameter list in `AssignState`. The rendering function `mappingPanel()` needs to be refactored to take just the context, globals, and translations (no struct pointer), and it needs to access parameters from `globals.state.mapping_panel.assign_state`.

The `SavePresetDialog` struct needs to be eliminated entirely. Its state fields (name_buffer, existing_presets, show_overwrite_confirm, pending_name) need to move to `SaveState` in the state machine. The `draw()` method needs to become a pure function `drawSavePresetDialog()` that takes context, SaveState, style manager, and translations. The text input TODO needs to be fixed - we should use `imgui.InputText()` which is available in the bindings.

A new pure function `drawModuleSelectionPanel()` needs to be created that takes context, BrowseState, TrackState, style manager, and translations. It needs to render a list of all 5 modules showing the current FX on each (by looking up module_locations in TrackState and getting the FX name from REAPER), highlight the selected module using the DrawListSplitter pattern, handle encoder scrolling through modules, return browse_confirm when SOLO is pressed, and return browse_cancel when MUTE is pressed.

A consolidation wrapper `drawMappingPanelWindow()` needs to be created that opens a single ImGui window, switches on the current sub_mode, delegates to the appropriate sub-panel draw function (drawModuleSelectionPanel, drawMappingPanel, or drawSavePresetDialog), and handles the window close button by returning exit_to_fx_ctrl action.

#### MIDI Button Integration

The `OnMidiEvent()` function in midi_events.zig currently handles the Inpt_preset button in fx_ctrl mode by dispatching to preset_browser mode. This needs to change to enter mapping_panel mode in BROWSE sub-mode instead.

A new case for `mapping_panel` mode needs to be added to the switch statement. In BROWSE sub-mode, the encoder (Out_Vol) should scroll through modules, SOLO button should confirm selection, and MUTE button should cancel. In ASSIGN sub-mode, the existing mapping panel doesn't have MIDI controls, but we might want to add them (e.g., encoder to scroll parameters, SOLO to confirm, MUTE to cancel). In SAVE sub-mode, encoder should scroll through preset names, SOLO should confirm save, and MUTE should cancel.

#### File System Integration

The mapping save flow currently happens in mapping_actions.zig when handling the save_mapping action. This needs to be updated to work with the new save dialog flow. When the user enters SAVE sub-mode (by clicking Save button in ASSIGN mode), the system needs to load existing preset names using `mapping_browser.getMappingNames()` and populate SaveState.

When the user confirms save (SOLO button or Save button in SAVE sub-mode), the system needs to construct the filepath from components (resource_path, "maps", module name, sanitized FX name, preset name + ".ini"), call `map_store.saveToFile()` with the current mappings and mapping name, call `map_store.setPreferredMapping()` to make this the preferred mapping, and exit back to fx_ctrl mode.

The overwrite protection logic needs to check if the preset name exists in SaveState.existing_presets and show the confirmation popup if it does.

#### Test Implementation Strategy

The stateful test needs to model the hierarchical state machine with Mode (fx_ctrl or mapping_panel) and MappingPanelMode (BROWSE, ASSIGN, SAVE) fields. The test model needs to track FX assigned to each module (with parameters and current mappings), browser state (selected module, scroll position), and edit state (modified mappings, preset name being saved).

Commands need to be defined for each action:
- EnterBrowse: precondition is current mode is fx_ctrl, onModelOnly sets mode to mapping_panel and sub_mode to BROWSE
- ScrollBrowse: precondition is sub_mode is BROWSE, onModelOnly updates scroll position
- ConfirmBrowse: precondition is sub_mode is BROWSE, onModelOnly sets sub_mode to ASSIGN with selected module
- CancelBrowse: precondition is sub_mode is BROWSE, onModelOnly sets mode to fx_ctrl
- AddMapping: precondition is sub_mode is ASSIGN, onModelOnly adds mapping to current_mappings
- RemoveMapping: precondition is sub_mode is ASSIGN, onModelOnly removes mapping
- RequestSave: precondition is sub_mode is ASSIGN, onModelOnly sets sub_mode to SAVE
- CancelAssign: precondition is sub_mode is ASSIGN, onModelOnly sets mode to fx_ctrl
- SavePreset: precondition is sub_mode is SAVE, onModelOnly writes mapping to model's storage and sets mode to fx_ctrl
- CancelSave: precondition is sub_mode is SAVE, onModelOnly sets sub_mode to ASSIGN

The onPair implementations need to execute the corresponding action on the SUT (by calling dispatch with the appropriate MappingPanelAction), update the model to match, and verify they're synchronized (check mode, sub_mode, selected values, current mappings).

The test should verify transition validity (can't enter SAVE without being in ASSIGN first), state consistency (selected module corresponds to valid FX, mappings reference valid parameters), and workflow integrity (cancel returns to correct state, save writes correct data).

### Technical Reference Details

#### File Locations

State machine:
- Main state structure: `src/statemachine.zig` lines 75-109
- Mode enum: `src/statemachine.zig` lines 41-60
- Valid transitions: `src/statemachine.zig` lines 63-73
- Current MappingState: `src/statemachine.zig` lines 130-169
- Current PresetBrowserState: `src/statemachine.zig` lines 117-123

Actions:
- Main dispatcher: `src/actions.zig` lines 62-133
- Mode action union: `src/actions.zig` lines 37-59
- Mapping actions: `src/mapping_actions.zig` lines 11-247
- Preset browser actions: `src/preset_browser_actions.zig` lines 12-194

UI Panels:
- Mapping panel: `src/mapping_panel.zig` lines 22-873
- Save dialog: `src/save_preset_dialog.zig` lines 14-151
- FX sel panel (pure function example): `src/fx_sel_panel.zig` lines 159-212
- Preset browser panel (to be removed): `src/preset_browser_panel.zig` lines 14-70
- GUI main loop: `src/gui_lib.zig` lines 24-243

MIDI handling:
- Event processing: `src/csurf/midi_events.zig` lines 17-161

Data management:
- Track state: `src/track_state.zig` lines 25-1472
- Mapping storage: `src/mappings.zig` lines 114-919
- Mapping browser: `src/mapping_browser.zig` lines 8-104

Testing:
- zlowcheck wrapper: `src/tests/zlowcheck.zig` lines 1-119
- Example stateful test: lines 9-118

Configuration:
- Globals structure: `src/globals.zig` lines 16-148

#### Key Type Signatures

State structures:
```zig
pub const Mode = enum { fx_ctrl, transport, fx_sel, mapping_panel, settings, default_fx_sel, preset_browser, midi_learn, suspended }

pub const State = struct {
    current_mode: Mode,
    fx_ctrl: FxControlState,
    fx_sel: FxSelectionState,
    mapping: MappingState,
    preset_browser: PresetBrowserState,
    // ... other fields
}

pub const MappingState = struct {
    target_fx: [:0]const u8,
    current_mappings: union(ModulesList) {
        INPUT: MapStore.Inpt,
        GATE: MapStore.Shp,
        EQ: MapStore.Eq,
        COMP: MapStore.Comp,
        OUTPT: MapStore.Outpt,
    },
    selected_parameter: ?u32,
    selected_control: ?c1.CCs,
    midi_learn_active: bool,
}
```

Actions:
```zig
pub const ModeAction = union(enum) {
    fx_ctrl: FxCtrlAction,
    fx_sel: FxSelActions,
    mapping: MappingAction,
    preset_browser: PresetBrowserAction,
    change_mode: Mode,
    // ... other variants
}

pub const MappingAction = union(enum) {
    select_parameter: ?u32,
    select_control: ?c1.CCs,
    toggle_midi_learn: void,
    add_mapping: struct { param: u8, control: c1.CCs },
    remove_mapping: c1.CCs,
    save_mapping: void,
    cancel_mapping: void,
    change_module: ModulesList,
}

pub fn dispatch(app: *Globals, action: ModeAction) void
```

UI Patterns:
```zig
// Pure function pattern (example from fx_sel_panel.zig)
pub fn ModulePopup(
    ctx: imgui.ContextPtr,
    module: ModulesList,
    mappings: std.StringArrayHashMapUnmanaged(void),
    current_index: usize,
    display_menus: bool,
    g_drwls_splitter: *imgui.DrawListSplitterPtr,
    style_manager: *styles.StyleManager,
    translations: *TranslationStore,
) !?FxSelActions

// Struct method pattern (to be refactored)
pub const SavePresetDialog = struct {
    // ... state fields
    pub fn draw(self: *SavePresetDialog, ctx: imgui.ContextPtr, style_manager: *styles.StyleManager) !?SavePresetAction
}
```

Mapping structures:
```zig
pub const Comp = struct {
    version: u8 = 1,
    Comp_Attack: ?u8 = null,
    Comp_DryWet: ?u8 = null,
    // ... other fields
}

pub const TaggedMapping = union(ModulesList) {
    INPUT: Inpt,
    GATE: Shp,
    EQ: Eq,
    COMP: Comp,
    OUTPT: Outpt,
}
```

MapStore interface:
```zig
pub const MapStore = struct {
    COMP: std.StringArrayHashMapUnmanaged(FxMaps(Comp)),
    // ... other module maps

    pub fn get(self: *MapStore, fxName: [:0]const u8, module: ModulesList) ?TaggedMapping
    pub fn saveToFile(self: *MapStore, module: ModulesList, fx_name: [:0]const u8, mapping: TaggedMapping, mapping_name: [:0]const u8) !void
    pub fn setPreferredMapping(self: *MapStore, fx_name: [:0]const u8, module: ModulesList, filepath: [:0]const u8) !void
}
```

#### Critical Patterns and Constraints

Pure draw functions:
- Must not hold state internally
- Take all required state as parameters
- Return action unions or null
- Can be called every frame without side effects
- Example: `fx_sel_panel.ModulePopup()`

DrawListSplitter for highlighting:
- Managed by caller (stored in globals.drwls_splitter)
- Passed as pointer to draw functions
- Used to render inverted selection colors
- Pattern: split into 2 channels, draw background in channel 0, draw text in channel 1

Arena allocator usage:
- globals.arena persists for application lifetime
- Used for FX names, preset lists, file paths
- No explicit frees needed (cleaned up when arena is reset)
- Test arenas are created and destroyed per test

State machine transitions:
- All transitions validated through valid_transitions map
- Mode changes logged with Event structure
- GUI registration managed based on mode and visibility settings
- MIDI feedback sent on mode entry

Action dispatch flow:
- All actions go through single dispatch() entry point
- Mode-specific actions delegated to handler functions
- Handlers directly modify globals.state
- Recursive dispatch allowed for multi-step transitions

Mapping file format:
- INI format with field_name = value lines
- Optional u8 fields written as empty string if null
- version field always present (current value: 1)
- Directory structure: maps/<MODULE>/<sanitized_fx_name>/<mapping_name>.ini

---

## Code Review History

### Review 1 - 2025-12-08

# Code Review: Step 0 - Remove Obsolete Files and Modes

## Summary

The implementation successfully removes all obsolete preset_browser and midi_learn modes, along with their associated files and references. The code compiles cleanly, and all dangling references have been properly eliminated. The critical midi_learn_active boolean flag has been correctly preserved in MappingState as required.

## Critical Issues (0)

None found.

## Warnings (0)

None found.

## Suggestions (0)

None - the implementation is clean and complete.

## Patterns Followed

- Mode enum properly cleaned up (preset_browser and midi_learn modes removed)
- valid_transitions map updated correctly (no transitions to/from removed modes)
- No dangling imports of deleted files
- MappingState.midi_learn_active boolean flag correctly preserved
- Build verification passed (zig build succeeds)
- All obsolete files successfully deleted

## Detailed Review

### Files Deleted

Because the task required removing obsolete files that are not part of the correct flow, I verified the following files were successfully deleted:

- /Users/antoine/Documents/personnel/experiments/zigwrap2/src/preset_browser_panel.zig - DELETED
- /Users/antoine/Documents/personnel/experiments/zigwrap2/src/preset_browser_actions.zig - DELETED
- /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/preset_browser_tests.zig - DELETED

### Mode Enum Cleanup (src/statemachine.zig lines 41-56)

Because the Mode enum needed to be cleaned of obsolete modes, I verified:

- preset_browser mode: REMOVED
- midi_learn mode: REMOVED
- Remaining modes are: fx_ctrl, transport, fx_sel, mapping_panel, settings, default_fx_sel, suspended

### Valid Transitions Map (src/statemachine.zig lines 59-67)

Because the valid_transitions map needed to remove references to obsolete modes, I verified:

- No transitions TO preset_browser or midi_learn
- fx_ctrl transitions: settings, fx_sel, mapping_panel, suspended, transport (correct)
- fx_sel transitions: fx_ctrl, mapping_panel, settings, fx_sel, suspended (correct)
- mapping_panel transitions: fx_sel, fx_ctrl, suspended (correct)
- All transition rules are consistent with remaining modes

### MappingState Structure (src/statemachine.zig lines 115-154)

Because the task specification explicitly required preserving the midi_learn_active flag, I verified:

- midi_learn_active: bool = false (line 127) - CORRECTLY PRESERVED
- target_fx, current_mappings, selected_parameter, selected_control - all present
- No PresetBrowserState structure exists (correctly removed)

### Action System (src/actions.zig lines 34-53)

Because the action system needed to remove references to obsolete modes, I verified:

- ModeAction union contains: fx_ctrl, fx_sel, transport, mapping, settings, default_fx_sel, Csurf, change_mode, set_fx_ctrl_gui, track_list, midi_out
- No preset_browser action variant
- No midi_learn action variant
- All remaining action variants are valid

### MIDI Event Handling (src/csurf/midi_events.zig lines 17-120)

Because MIDI event routing needed to remove handlers for obsolete modes, I verified:

- fx_ctrl mode: handles all FX control inputs (lines 42-44)
- fx_sel mode: handles browser scrolling and selection (lines 45-63)
- default_fx_sel mode: handles default FX selection (lines 64-82)
- settings mode: handles settings panel (lines 83-91)
- transport mode: handles transport controls (lines 92-120)
- No preset_browser mode handler - CORRECTLY REMOVED
- No midi_learn mode handler - CORRECTLY REMOVED

### GUI Rendering (src/gui_lib.zig lines 47-146)

Because GUI rendering needed to remove rendering code for obsolete modes, I verified:

- fx_ctrl mode rendering (lines 48-70)
- settings mode rendering (lines 71-81)
- default_fx_sel mode rendering (lines 82-106)
- fx_sel mode rendering (lines 107-141)
- mapping_panel mode rendering (lines 142-146)
- transport mode rendering (lines 147-180)
- No preset_browser mode rendering - CORRECTLY REMOVED
- No midi_learn mode rendering - CORRECTLY REMOVED

### Logger Scopes (src/logger.zig lines 1-80)

Because logging scopes might reference obsolete modes, I verified:

- No preset_browser logging scope defined
- No midi_learn logging scope defined
- Only references to midi_learn appear in language pack files (resources/langPacks/en.ini and resources/langPacks/fr.ini) which is acceptable as they are translation resources

### No Dangling Imports

Because dangling imports would cause compilation failures, I verified:

- grep for "preset_browser_panel" in src/: NO MATCHES
- grep for "preset_browser_actions" in src/: NO MATCHES
- grep for "PresetBrowserState" in src/: NO MATCHES
- grep for "PresetBrowserAction" in src/: NO MATCHES
- grep for ".preset_browser" in src/: NO MATCHES

### Build Verification

Because the task required that code compiles successfully, I verified:

- zig build: SUCCESSFUL (no errors)
- All source files parse correctly
- No missing imports or undefined references

### References Only in Documentation

Because documentation files are expected to reference the removed modes for historical/planning purposes, the following occurrences are acceptable:

- phase2_revised.plan.md: contains preset_browser references in context documentation
- phase2_orchestration.md: planning document
- mapping_panel.testing.md: testing documentation
- mapping_panel.plan.md: planning document
- src/resources/langPacks/en.ini: contains midi_learn translation string
- src/resources/langPacks/fr.ini: contains midi_learn translation string

## Overall Assessment

The implementation passes review with no issues. All obsolete files and mode references have been completely removed, the midi_learn_active flag has been correctly preserved, no dangling references remain, and the code compiles successfully. We can proceed to Step 1.

**Action Items:**

None - Step 0 is complete and ready to proceed to Step 1.
