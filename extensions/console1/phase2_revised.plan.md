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

### Review 2 - 2025-12-08

# Code Review: Step 1 - Refactor State Machine

## Summary

The hierarchical state machine structure has been successfully implemented and matches the specification. All required structures (MappingPanelMode, BrowseState, AssignState, SaveState, MappingPanelState) are correctly defined with appropriate fields. The old MappingState has been removed and replaced with the new mapping_panel field. The implementation compiles cleanly (statemachine.zig has no errors), with expected compilation errors in files that reference the old state structure. We can proceed to Step 2.

## Critical Issues (0)

None found.

## Warnings (0)

None found.

## Suggestions (1)

### 1. AssignState default union variant initialization

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/statemachine.zig:161-163

Because Zig requires unions to have a default value, the implementation initializes `current_mappings` with `.{ .COMP = MapStore.Comp{} }` as a default variant. This is an acceptable pattern, but consider documenting why COMP was chosen as the default (it's arbitrary, and the union will be replaced with the correct module when entering ASSIGN sub-mode from BROWSE).

## Patterns Followed

- MappingPanelMode enum defined correctly (BROWSE, ASSIGN, SAVE)
- BrowseState matches spec (selected_module, scroll positions, available_modules array)
- AssignState matches spec (target_fx, target_module, current_mappings union, selected fields, midi_learn_active flag)
- SaveState matches spec (name_buffer, name_len, existing_presets ArrayList, overwrite fields, init() method)
- MappingPanelState hierarchical structure correctly implemented
- Old MappingState completely removed
- State.init() calls MappingPanelState.init(gpa) for proper initialization
- Mode enum and valid_transitions unchanged (no modifications to existing modes)
- Zig naming conventions followed (PascalCase for types, snake_case for fields)

## Detailed Review

### Structure Completeness

**MappingPanelMode enum** (lines 41-45):
Because the specification required three distinct sub-modes, I verified:
- BROWSE variant present
- ASSIGN variant present
- SAVE variant present
- Follows Zig enum naming conventions

**BrowseState struct** (lines 116-122):
Because the BROWSE sub-mode needs to track module selection and cached FX info, I verified:
- selected_module: ModulesList with default .INPUT
- scroll_position_abs: u8 with default 0
- scroll_position_rel: usize with default 0
- available_modules: [5]?[]const u8 array for caching current FX names
- All fields match specification from lines 100-104 of plan

**AssignState struct** (lines 124-137):
Because the ASSIGN sub-mode needs to track mapping editing state, I verified:
- target_fx: []const u8 with empty string default
- target_module: ModulesList with default .INPUT
- current_mappings: union(ModulesList) with variants INPUT/GATE/EQ/COMP/OUTPT
- Mapping variants correctly reference MapStore types (Inpt, Shp, Eq, Comp, Outpt)
- selected_parameter: ?u32 with default null
- selected_control: ?c1.CCs with default null
- midi_learn_active: bool with default false
- All fields match specification from lines 107-118 of plan

**SaveState struct** (lines 139-151):
Because the SAVE sub-mode needs to manage preset saving with overwrite protection, I verified:
- name_buffer: [256]u8 initialized to zeros
- name_len: usize with default 0
- existing_presets: std.ArrayList([]const u8) properly typed
- show_overwrite_confirm: bool with default false
- pending_name: []const u8 with empty string default
- init() method properly initializes ArrayList with allocator (line 146-149)
- All fields match specification from lines 121-126 of plan

**MappingPanelState struct** (lines 153-167):
Because the mapping_panel mode needs to coordinate all three sub-modes, I verified:
- sub_mode: MappingPanelMode field present with default .BROWSE
- browse_state: BrowseState field present with struct literal default
- assign_state: AssignState field present (no default needed, initialized in init())
- save_state: SaveState field present (no default needed, initialized in init())
- init() method properly initializes nested states with allocator (lines 159-166)
- Matches specification structure from lines 96-127 of plan

### Initialization Correctness

**SaveState.init()** (lines 146-149):
Because SaveState needs dynamic memory for existing_presets, I verified:
- Takes allocator: std.mem.Allocator parameter
- Returns properly initialized SaveState
- Initializes existing_presets ArrayList with provided allocator
- Other fields use struct defaults

**MappingPanelState.init()** (lines 159-166):
Because MappingPanelState needs to initialize nested states that require allocators, I verified:
- Takes allocator: std.mem.Allocator parameter
- Returns properly initialized MappingPanelState
- Explicitly initializes assign_state.current_mappings with default .COMP variant (required by Zig)
- Calls SaveState.init(allocator) for save_state initialization
- browse_state uses struct defaults (no allocator needed)

**State.init()** (lines 90-96):
Because the main State struct needs to initialize MappingPanelState with an allocator, I verified:
- Calls MappingPanelState.init(gpa) instead of using struct literal
- Correctly passes gpa allocator to nested init
- Also initializes fx_ctrl state with allocator
- Shared state uses default values

### State Machine Consistency

**State struct update** (line 83):
Because the State struct needed to replace the old mapping field with new mapping_panel field, I verified:
- Old `mapping: MappingState` field REMOVED
- New `mapping_panel: MappingPanelState` field ADDED
- Field name matches convention (snake_case)
- Properly initialized in State.init()

**Mode enum unchanged** (lines 47-62):
Because the task only required adding sub-modes within mapping_panel, not changing top-level modes, I verified:
- Mode enum still contains: fx_ctrl, transport, fx_sel, mapping_panel, settings, default_fx_sel, suspended
- No new modes added
- No modes removed (Step 0 already cleaned up obsolete modes)

**valid_transitions unchanged** (lines 65-73):
Because the task only required internal sub-mode transitions, not top-level mode transitions, I verified:
- valid_transitions map unchanged from Step 0
- mapping_panel can still transition to: fx_sel, fx_ctrl, suspended
- Other mode transitions unchanged

**Imports preserved** (line 10):
Because AssignState.current_mappings union needs to reference MapStore types, I verified:
- MapStore import present (line 10)
- Inpt, Shp, Eq, Comp, Outpt types accessed via MapStore namespace (lines 128-132)

### Code Quality

**Zig fmt compliance**:
Because all code should follow Zig formatting standards, I verified:
- Indentation is consistent
- Spacing follows Zig conventions
- Struct initialization uses proper syntax

**Naming conventions**:
Because Zig requires PascalCase for types and snake_case for fields, I verified:
- Type names: MappingPanelMode, BrowseState, AssignState, SaveState, MappingPanelState (correct)
- Field names: sub_mode, browse_state, assign_state, save_state, selected_module, scroll_position_abs, etc. (correct)

**Match to pseudo-code** (plan lines 89-127):
Because the implementation should follow the specification, I verified:
- All struct fields present from pseudo-code
- Types correctly translated (enum -> enum, struct -> struct, union(ModulesList) -> union(ModulesList))
- Array sizes match (available_modules: [5], name_buffer: [256])
- Optional types correctly represented (?u32, ?c1.CCs)

### Compilation Status

**statemachine.zig** (verified via build output):
Because the refactored file should compile without errors, I verified:
- No compilation errors in statemachine.zig itself
- File successfully parsed and type-checked

**Expected compilation errors in other files** (verified via build output):
Because Step 1 only refactored the state structure without updating references, I verified expected errors:

1. src/mapping_actions.zig:37 - "no field named 'mapping' in struct 'statemachine.State'"
   - Expected: code references globals.state.mapping (old name)
   - Will be fixed in Step 2 when updating actions

2. src/mapping_panel.zig:183 - "no field named 'mapping' in struct 'statemachine.State'"
   - Expected: code references state.mapping (old name)
   - Will be fixed in Step 5 when refactoring mapping panel

3. src/mapping_panel.zig:318 - "no field named 'mapping' in struct 'statemachine.State'"
   - Expected: code references globals.state.mapping (old name)
   - Will be fixed in Step 5 when refactoring mapping panel

4. src/midi_out.zig:231 - "no field named 'mapping' in struct 'statemachine.State'"
   - Expected: code references globals.state.mapping (old name)
   - Will be fixed in Step 8 when updating MIDI handlers

These errors are expected and acceptable at this stage because Step 1 only modifies statemachine.zig. Subsequent steps will update the references.

## Overall Assessment

The implementation successfully establishes the hierarchical state machine foundation. The structure is complete, correctly typed, properly initialized, and matches the specification. All required types are defined with appropriate fields and initialization methods. The old flat MappingState has been completely replaced with the new hierarchical MappingPanelState containing three nested sub-mode states. The expected compilation errors in other files confirm that the old state structure has been removed and will be addressed in subsequent steps.

**Action Items:**

None - Step 1 is complete and ready to proceed to Step 2: Update Actions.

### Review 3 - 2025-12-08

# Code Review: Step 2 - Update Actions

## Summary

The action system has been successfully refactored to implement the hierarchical dispatch pattern. The MappingPanelAction union is complete with all required sub-mode actions, the dispatcher correctly handles transitions and updates sub_mode, and all state references have been updated from globals.state.mapping to globals.state.mapping_panel.assign_state. The code compiles cleanly and follows the specification. However, there is one critical bug that will cause runtime failures in the save flow.

## Critical Issues (1)

### 1. Missing target_fx Population in enter_assign

**File**: src/mapping_actions.zig:66-107
**Issue**: Because the enter_assign handler loads the mapping and sets target_module but never populates target_fx, the field remains an empty string. This causes both enter_save (line 118) and save_confirm (line 348) to use an empty FX name, resulting in incorrect file paths and cache lookups.
**Impact**: The save flow will fail because the FX name is empty when constructing file paths and querying the MapStore.
**Root Cause**: The Location struct in track_state.zig only contains fx_index and mapping, not the FX name. The FX name must be queried from REAPER using reaper.TrackFX_GetFXName() with the fx_index.
**Fix Required**: In enter_assign, after getting the location from module_locations, query REAPER for the FX name and assign it to globals.state.mapping_panel.assign_state.target_fx.

Example fix:
```zig
if (globals.state.fx_ctrl.track_state.module_locations.get(data.module)) |location| {
    // Query FX name from REAPER
    const track = ...; // get current track
    var fx_name_buf: [256]u8 = undefined;
    _ = reaper.TrackFX_GetFXName(track, location.fx_index, &fx_name_buf, fx_name_buf.len);
    const fx_name_z = std.mem.sliceTo(&fx_name_buf, 0);
    globals.state.mapping_panel.assign_state.target_fx = try globals.arena.dupe(u8, fx_name_z);

    // Load the mapping if it exists...
}
```

## Warnings (2)

### 1. Placeholder FX Name in enter_browse

**File**: src/mapping_actions.zig:44-59
**Issue**: Because enter_browse populates available_modules with @tagName(module) instead of querying the actual FX name from REAPER, the browse state will show module names (INPUT, GATE, EQ, COMP, OUTPT) instead of FX names (VST: ReaComp (C1-C), etc.).
**Impact**: The module selection window will not display the actual FX names loaded on each module, making it harder for users to identify which FX they want to edit.
**Note**: The comment on line 53-54 acknowledges this is a placeholder and needs to query REAPER. This should be fixed before Step 4 (Create Module Selection Panel) to ensure the UI has correct data.

### 2. Inefficient Module Extraction in save_confirm

**File**: src/mapping_actions.zig:358 and 378
**Issue**: Because the code extracts the module from the union tag twice using different methods (@enumFromInt(@intFromEnum(...)) on line 358 and direct tag coercion on line 378), there's both redundancy and a potential type safety issue.
**Impact**: Minor performance overhead and code clarity issue. Line 378 uses an incorrect pattern that may not compile or may produce wrong results.
**Fix**: Use std.meta.activeTag() consistently:
```zig
const module = std.meta.activeTag(globals.state.mapping_panel.assign_state.current_mappings);
```

## Suggestions (3)

### 1. Recursive Dispatch Pattern Could Use Documentation

**File**: src/mapping_actions.zig:171, 175, 331, 335, 382, 388
**Note**: The code correctly uses recursive dispatch for transitions (browse_confirm calls enter_assign, save_cancel calls enter_assign, etc.), which matches the specification. Consider adding a comment explaining why this pattern is used instead of directly updating state, as it ensures proper initialization logic runs.

### 2. Scroll Position Calculation Oversimplified

**File**: src/mapping_actions.zig:159-163
**Issue**: Because browse_scroll sets both scroll_position_abs and scroll_position_rel to the same encoder_val, the relative position doesn't track actual list position (which should be clamped to 0-4 for the 5 modules).
**Note**: This is acceptable for now as the actual scrolling logic will be implemented in the UI panel (Step 4), but consider adding a TODO comment.

### 3. Consider Extracting Mapping Update Logic

**File**: src/mapping_actions.zig:197-254 and 260-317
**Note**: Because assign_add_mapping and assign_remove_mapping both have large switch statements with identical structure (one sets fields, one clears them), consider extracting this into a helper function to reduce duplication. However, this is a code quality issue, not a correctness issue.

## Patterns Followed

- MappingPanelAction union includes all required actions (transitions, BROWSE, ASSIGN, SAVE)
- Action structs have correct field types (module: ModulesList, param: u8, control: c1.CCs, etc.)
- Sub-mode transitions update globals.state.mapping_panel.sub_mode correctly
- enter_browse initializes browse_state (though with placeholder data)
- enter_assign initializes assign_state with mappings from track_state
- enter_save loads existing preset names using mapping_browser.getMappingNames
- save_confirm saves to disk using MapStore.saveToFile and updates cache
- Recursive dispatch used for transitions (browse_confirm -> enter_assign, etc.)
- All state references updated to globals.state.mapping_panel.assign_state
- actions.zig ModeAction union updated to use mapping_panel: MappingPanelAction
- gui_lib.zig action dispatch updated to .mapping_panel
- Code formatted with zig fmt
- Build succeeds with no compilation errors

## Detailed Review

### Action Completeness

**MappingPanelAction union** (lines 12-39):
Because the specification required actions for all sub-modes and transitions, I verified:
- Sub-mode transitions: enter_browse, enter_assign, enter_save, exit_to_fx_ctrl (lines 14-17)
- BROWSE actions: browse_scroll, browse_select_module, browse_confirm, browse_cancel (lines 20-23)
- ASSIGN actions: all original MappingAction operations preserved (lines 26-33)
- SAVE actions: save_update_name, save_confirm, save_cancel (lines 36-38)
- Field types correct: module as ModulesList, param as u8, control as c1.CCs, name as [:0]const u8

### Dispatch Flow Correctness

**enter_browse handler** (lines 44-64):
Because this transition needs to populate browse state with available modules, I verified:
- Updates sub_mode to .BROWSE (line 45)
- Iterates through ModulesList enum (line 49)
- Checks module_locations for each module (line 51)
- Populates available_modules array (line 55) - USES PLACEHOLDER
- Resets scroll positions (lines 62-63)
- WARNING: Uses @tagName(module) instead of querying REAPER for FX name

**enter_assign handler** (lines 66-107):
Because this transition needs to load mappings and initialize editing state, I verified:
- Updates sub_mode to .ASSIGN (line 67)
- Sets target_module from action data (line 68)
- Queries module_locations for the module (line 72)
- Loads existing mapping if found (lines 74-81)
- Initializes empty mapping if not found (lines 83-90, 94-100)
- Clears selections (lines 104-106)
- CRITICAL BUG: Does not populate target_fx field (needed for save operations)

**enter_save handler** (lines 109-147):
Because this transition needs to load existing preset names for overwrite protection, I verified:
- Updates sub_mode to .SAVE (line 110)
- Clears existing_presets list (line 114)
- Gets module and fx_name from assign_state (lines 117-118)
- Converts fx_name to null-terminated string (lines 121-124)
- Calls mapping_browser.getMappingNames (lines 126-134)
- Appends preset names to save_state list (lines 137-141)
- Resets name buffer and overwrite flag (lines 144-146)
- DEPENDS ON: target_fx being populated (but enter_assign doesn't do this - CRITICAL BUG)

**exit_to_fx_ctrl handler** (lines 149-156):
Because exiting needs to clean up resources, I verified:
- Cleans up mapping_panel if it exists (lines 151-154)
- Dispatches mode change to fx_ctrl (line 155)
- Matches specification pattern (lines 237-239 of plan)

**browse_confirm handler** (lines 169-172):
Because confirming selection should transition to ASSIGN mode, I verified:
- Gets selected_module from browse_state (line 170)
- Recursively dispatches enter_assign with selected module (line 171)
- Follows recursive dispatch pattern from spec (lines 246-247 of plan)

**browse_cancel handler** (lines 174-176):
Because canceling should exit the workflow, I verified:
- Recursively dispatches exit_to_fx_ctrl (line 175)
- Follows recursive dispatch pattern from spec (lines 249-250 of plan)

**assign_request_save handler** (lines 330-332):
Because requesting save should transition to SAVE mode, I verified:
- Recursively dispatches enter_save (line 331)
- Follows recursive dispatch pattern from spec (lines 259-260 of plan)

**assign_cancel handler** (lines 334-336):
Because canceling should exit the workflow, I verified:
- Recursively dispatches exit_to_fx_ctrl (line 335)
- Follows recursive dispatch pattern from spec (lines 262-263 of plan)

**save_confirm handler** (lines 347-383):
Because confirming save should write to disk and update MapStore, I verified:
- Gets fx_name from assign_state (line 348) - WILL FAIL: target_fx is empty
- Converts to null-terminated string (lines 352-355)
- Extracts module from union tag (line 358) - WARNING: inefficient pattern
- Creates TaggedMapping from current_mappings (lines 359-365)
- Calls MapStore.saveToFile with module, fx_name, mapping, and name (lines 367-375)
- Reloads mapping into cache with get() (lines 378-379) - WARNING: incorrect tag extraction
- Recursively dispatches exit_to_fx_ctrl (line 382)
- Follows recursive dispatch pattern from spec (lines 266-268 of plan)
- CRITICAL BUG: fx_name will be empty, causing incorrect file paths

**save_cancel handler** (lines 385-389):
Because canceling save should return to ASSIGN mode, I verified:
- Gets current_module from assign_state (line 387)
- Recursively dispatches enter_assign with current module (line 388)
- Follows recursive dispatch pattern from spec (lines 270-271 of plan)

### ASSIGN Action Preservation

**assign_select_parameter** (lines 179-182):
Because parameter selection needs to update state, I verified:
- Updates selected_parameter in assign_state (line 181)
- Logs selection (line 180)
- Preserves existing mapping logic

**assign_select_control** (lines 184-187):
Because control selection needs to update state, I verified:
- Updates selected_control in assign_state (line 186)
- Logs selection (line 185)
- Preserves existing mapping logic

**assign_toggle_midi_learn** (lines 189-195):
Because MIDI learn toggle needs to update flag and clear control, I verified:
- Toggles midi_learn_active flag (line 191)
- Clears selected_control when disabling (line 193)
- Logs state change (line 190)
- Preserves existing mapping logic

**assign_add_mapping** (lines 197-258):
Because adding mapping needs to update the appropriate union variant, I verified:
- Switches on current_mappings union (line 201)
- Handles all module types: COMP, EQ, INPUT, OUTPT, GATE (lines 202-253)
- Switches on control CC to set appropriate field (e.g., Comp_Attack sets comp.Comp_Attack)
- Clears selections after mapping (lines 256-257)
- Logs mapping addition (line 198)
- Preserves existing mapping logic

**assign_remove_mapping** (lines 260-318):
Because removing mapping needs to clear the appropriate union variant field, I verified:
- Switches on current_mappings union (line 264)
- Handles all module types: COMP, EQ, INPUT, OUTPT, GATE (lines 265-316)
- Switches on control CC to set field to null (e.g., Comp_Attack => comp.Comp_Attack = null)
- Logs mapping removal (line 261)
- Preserves existing mapping logic

**assign_change_module** (lines 320-328):
Because changing module needs to initialize a new empty mapping, I verified:
- Switches on new_module to create appropriate mapping type (lines 321-327)
- Initializes with default (empty) mapping struct
- Preserves existing mapping logic

### State Reference Updates

**mapping_panel.zig references** (verified via grep and Read):
Because all references to globals.state.mapping need to be updated, I verified:
- Line 183: state.mapping_panel.assign_state.current_mappings (in getControlMapping)
- Line 318: globals.state.mapping_panel.assign_state.selected_control (in mappingWidget)
- No remaining references to globals.state.mapping or state.mapping

**midi_out.zig references** (verified via grep and Read):
Because MIDI feedback needs to access current mappings, I verified:
- Line 231: globals.state.mapping_panel.assign_state.current_mappings (in MappingsEntry)
- No remaining references to globals.state.mapping

**actions.zig ModeAction** (verified via Read):
Because the top-level action union needs to use the new action type, I verified:
- Line 8: imports MappingPanelAction from mapping_actions.zig
- Line 9: imports mappingPanelActions dispatcher
- Line 42: mapping_panel: MappingPanelAction variant in union
- Line 115: .mapping_panel => |mp_action| mappingPanelActions(app, mp_action) in dispatch
- No mapping or preset_browser variants remain

**gui_lib.zig dispatch** (verified via Read):
Because the GUI needs to return the new action type, I verified:
- Line 143: calls mapping_panel.mappingPanel (unchanged, returns MappingPanelAction)
- Line 144: rv = .{ .mapping_panel = map_action } (uses .mapping_panel tag)
- Correct integration with new action system

### Code Quality

**Zig fmt compliance** (verified via zig fmt --check):
Because all code should be formatted, I verified:
- All files pass zig fmt --check with no output
- Indentation and spacing consistent

**Build status** (verified via zig build):
Because the code must compile, I verified:
- Build succeeds with exit code 0
- No compilation errors
- All type checks pass

**Writing style compliance**:
Because comments should explain cause before consequence, I verified:
- Line 47: "Because we need to populate available_modules from track_state.module_locations..."
- Line 70: "Because we need to load FX parameters and initialize assign_state with current mappings..."
- Line 112: "Because we need to load existing preset names, we use mapping_browser.getMappingNames"
- Line 120: "Because getMappingNames requires a null-terminated string, we need to convert fx_name"
- All comments follow proper English with articles and antecedents first

**Dispatch pattern match** (verified against plan lines 219-272):
Because the implementation should follow the specification, I verified:
- Sub-mode transitions update globals.state.mapping_panel.sub_mode correctly
- Recursive dispatch used for multi-step transitions
- State initialization happens in transition handlers
- Follows the exact flow from pseudo-code

## Overall Assessment

The action system implementation is mostly correct and successfully consolidates all mapping panel operations into a hierarchical dispatcher. The code compiles, follows the specification's dispatch pattern, preserves all existing mapping logic, and correctly updates all state references. However, the critical bug where target_fx is never populated will cause the save flow to fail with empty FX names. This must be fixed before proceeding to UI implementation.

The warnings about placeholder FX names and inefficient tag extraction should be addressed but are not blockers. The suggestions about documentation and code refactoring can be deferred to later cleanup.

**Action Items:**

- [X] CRITICAL: Fix enter_assign to populate target_fx by querying REAPER (src/mapping_actions.zig:66-107)
- [ ] WARNING: Update enter_browse to query actual FX names from REAPER instead of using placeholders (src/mapping_actions.zig:44-59)
- [ ] WARNING: Fix module extraction pattern in save_confirm to use std.meta.activeTag (src/mapping_actions.zig:358, 378)

### Review 4 - 2025-12-08

# Code Review: Step 3 - Implement Stateful Tests

## Summary

The stateful test implementation successfully verifies the hierarchical state machine using zlowcheck model-based testing. All 78 tests pass, including the mapping panel stateful test. The model captures essential state machine properties, commands mirror dispatcher actions correctly with proper preconditions, and the test integration follows zlowcheck patterns. However, there are critical issues with the SavePreset command implementation that will cause it to fail in real scenarios, and some commands are missing from the specification.

## Critical Issues (2)

### 1. SavePreset Command Will Fail Due to Empty target_fx

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:641-669

**Issue**: Because the SavePreset command in onPair (line 660) calls save_confirm which depends on assign_state.target_fx being populated, and this field is never set in the test (the enter_assign handler in mapping_actions.zig has the bug identified in Review 3 where it doesn't populate target_fx), the save operation will fail with an empty FX name.

**Impact**: The SavePreset command will execute but will attempt to save to an incorrect file path. This test is passing now because it only verifies that current_mode == .fx_ctrl after save (line 667), which happens even when the save fails. The test is not verifying that the mapping was actually written to disk.

**Root Cause**: The test relies on the SUT (System Under Test) having a properly initialized target_fx, but the SUT's enter_assign handler doesn't populate this field (as identified in Review 3).

**Fix Required**: This will be automatically fixed when the Critical Issue from Review 3 is addressed (enter_assign needs to populate target_fx by querying REAPER).

### 2. Missing Track State Setup in System.init

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:68-76

**Issue**: Because the System.init creates a Globals instance but never populates globals.state.fx_ctrl.track_state.module_locations, the enter_assign handler (which queries module_locations to load existing mappings) will always find null and create empty mappings. This means the test never actually tests loading existing mappings from track state.

**Impact**: The test's coverage is incomplete - it doesn't verify the workflow where a module already has an FX assigned and the user edits that FX's mappings. The enter_assign command will always initialize empty mappings instead of loading existing ones.

**Fix Required**: In System.init, populate track_state.module_locations with FxInfo from the model to enable testing of the load-existing-mapping workflow.

## Warnings (3)

### 1. Model Track State Overly Simplified

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:26-27

**Issue**: Because the Model's track state only stores FxInfo (name and param_count) and doesn't track which parameters are mapped to which controls, the model can't verify that mappings remain consistent with the actual FX parameters.

**Impact**: The test can't catch bugs where mappings reference invalid parameter indices (e.g., mapping to parameter 15 when the FX only has 10 parameters). The spec says "Mappings reference valid parameters and controls" should be verified (line 338 of plan).

**Note**: This is acceptable for a simplified model, but consider adding parameter index validation in AddMapping.checkPrecondition to ensure param is less than the FX param_count.

### 2. Missing ChangeParameter Command

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig (entire file)

**Issue**: Because the specification lists "ChangeParameter: select different parameter" as a test command (line 317 of plan), but this command is not implemented in the test file, the test coverage is incomplete.

**Impact**: The test doesn't verify the select_parameter action. This is a minor workflow action, but it's part of the UI interaction flow.

**Note**: This may have been omitted intentionally because parameter selection is purely UI state that doesn't affect the core state machine transitions. However, it should be documented why it was omitted if that's the case.

### 3. Model Doesn't Track Preset Save History

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:20-56

**Issue**: Because the Model doesn't maintain a list of saved presets (equivalent to what would be written to disk), the SavePreset command can't verify that the mapping was actually saved with the correct values.

**Impact**: The test verifies that the workflow completes (mode returns to fx_ctrl), but doesn't verify that the save operation wrote the correct data. A bug where save writes corrupt data or to the wrong file would not be caught.

**Note**: This is acceptable for a minimal model that focuses on state machine transitions, but consider adding a saved_mappings tracking field if you want to verify save correctness.

## Suggestions (4)

### 1. Add Comments Explaining Recursive Dispatch Pattern

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:291, 328, 597, 688

**Note**: Because commands like ConfirmBrowse and CancelBrowse recursively call other actions (browse_confirm triggers enter_assign internally), consider adding comments explaining that these commands test the recursive dispatch pattern, not direct state manipulation.

### 2. Consider Parameterized SavePreset

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:641-669

**Note**: Because SavePreset always uses the hardcoded name "test_preset" (line 659), the test never verifies different preset names or the overwrite protection logic. Consider making SavePreset parameterized with a preset name to test multiple saves and overwrite scenarios.

### 3. Test Could Benefit from More Module Variety

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:712-742

**Note**: Because the test only creates EnterAssign commands for three modules (COMP, EQ, INPUT) and not for GATE and OUTPT, the test coverage for those modules is reduced. Consider adding commands for all five module types.

### 4. Model.init Could Use Better Documentation

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/tests/mapping_panel_stateful_test.zig:39-46

**Note**: Because Model.init hardcodes three specific modules (INPUT, COMP, EQ) with specific param counts, it's not obvious why these choices were made. Add a comment explaining that these modules match the commands registered in the test.

## Patterns Followed

- Model captures essential state machine properties (mode, sub_mode, track state, browser state, edit state, save state)
- Model is simplified but sufficient to verify correctness (FxInfo contains name and param_count)
- Model initialization correct (init() populates three modules)
- Memory management proper (init/deinit/reset implemented correctly)
- All required commands implemented (sub-mode transitions, BROWSE, ASSIGN, SAVE actions)
- checkPrecondition correctly enforces state constraints (mode checks, sub_mode checks, module existence checks)
- onModelOnly updates model state correctly during generation
- onPair executes on system, updates model, and verifies synchronization
- Commands mirror the MappingPanelAction actions from Step 2
- Tests cover all major workflows (BROWSE to ASSIGN to SAVE to exit)
- Tests cover cancellation paths (BROWSE cancel, ASSIGN cancel, SAVE cancel)
- Tests cover module switching and mapping operations
- Invalid transitions prevented by preconditions
- Follows zlowcheck-stateful patterns correctly
- CommandList properly initialized with all commands
- assertStateful called with appropriate configuration
- System Under Test properly implements required interface
- Code formatted with zig fmt
- Tests compile and pass (zig build test shows 78/78 passed)
- No memory leaks (proper arena allocator usage in System.deinit)
- Clear command names and documentation

## Overall Assessment

The stateful test implementation successfully establishes model-based testing for the hierarchical state machine. The test structure is correct, command implementations mirror the dispatcher actions, preconditions properly enforce state constraints, and zlowcheck integration follows the documented patterns. The tests compile and pass (78/78), demonstrating that the core state machine logic is working.

However, there are two critical issues that reduce test effectiveness:

1. SavePreset will fail in real scenarios due to empty target_fx (depends on fix from Review 3)
2. System.init doesn't populate track_state, so enter_assign never tests loading existing mappings

Both issues can be fixed without changing the test structure. Once addressed, the test will provide comprehensive coverage of the mapping panel workflows.

The warnings about simplified model state and missing ChangeParameter command are minor - the current test level is sufficient to verify state machine correctness. The suggestions about documentation and parameterization would improve test clarity and coverage but are not blockers.

**Status: Needs fixes (but can proceed)**

Because the critical issues are either (1) already being fixed in Review 3 or (2) specific to test setup and don't affect the core state machine logic, we can proceed to Step 4 while the fixes are being implemented. The test structure is correct and will work properly once the underlying bugs are fixed.

**Action Items:**

- [ ] CRITICAL: Fix mapping_actions.zig enter_assign to populate target_fx (from Review 3, already being addressed)
- [ ] CRITICAL: Fix System.init to populate track_state.module_locations with test FX data
- [ ] SUGGESTION: Add comments explaining recursive dispatch pattern in command onPair methods
- [ ] SUGGESTION: Consider parameterizing SavePreset with preset name to test overwrite protection

### Review 5 - 2025-12-09

# Code Review: Step 4 - Create Module Selection Panel

## Summary

The module selection panel implementation follows the pure function pattern correctly and displays all required UI elements. The code compiles successfully and is properly formatted. However, there are several critical issues that prevent the implementation from working as specified: the function uses translation parameter but never actually uses translation strings, the hover interaction doesn't update browse_state.selected_module correctly, and there's duplicate code for the drawInvertedSlctblColors helper that should be shared with fx_sel_panel.zig.

## Critical Issues (3)

### 1. Hover Selection Logic Broken

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:67-71

**Issue**: Because the hover logic returns browse_select_module action but the onPair handler in mapping_actions.zig expects the browse_state to be updated before any UI rendering, the hover interaction creates a race condition. The handler updates browse_state.selected_module (line 159 in mapping_actions.zig), but then the UI re-renders in the same frame, checking if is_selected matches the OLD browse_state value (line 42), so the highlight appears one frame late.

**Impact**: The hover highlight lags behind mouse movement by one frame, creating a janky user experience. Users will see the highlight update after they've already moved to the next item.

**Root Cause**: The UI checks browse_state.selected_module at the start of rendering (line 42), but the action that updates browse_state is only dispatched at the end of the frame. By the next frame, the mouse may have already moved.

**Fix Required**: The hover logic should work differently - either:
1. Check IsItemHovered() and draw highlight immediately without going through the action system (for immediate visual feedback), OR
2. The action handler needs to request a re-render after updating browse_state

This is a fundamental issue with how stateful hover interactions work in immediate mode GUIs when state updates happen through an action system.

### 2. Translation String Not Defined

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:36

**Issue**: Because the window title uses a hardcoded string "Select Module to Edit" instead of calling tr(translations, .module_sel_title), the implementation doesn't follow the translation pattern used in fx_sel_panel.zig (line 178). The translation key module_sel_title would need to be added to translations.zig, but this wasn't done.

**Impact**: The window title will not be translatable, breaking consistency with other panels. Users with non-English language settings will see mixed languages.

**Fix Required**:
1. Add module_sel_title to TranslationKeys enum in translations.zig
2. Add translation entries to en.ini and fr.ini
3. Update line 36 to: `if (try imgui.Begin(.{ ctx, tr(translations, .module_sel_title), &open }))`

### 3. Duplicate Helper Function

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:88-130

**Issue**: Because the drawInvertedSlctblColors function is duplicated between module_selection_panel.zig and fx_sel_panel.zig with identical implementations (214-257 in fx_sel_panel.zig), this violates the DRY principle and creates a maintenance burden.

**Impact**: Bug fixes or improvements to the highlight rendering logic will need to be applied in two places. This has already happened - both implementations are identical copies, which indicates code duplication rather than intentional divergence.

**Fix Required**: Extract drawInvertedSlctblColors into a shared module (e.g., ui_helpers.zig or styles_components.zig) and import it from both files.

## Warnings (4)

### 1. FX Name Formatting Issues

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:45-57

**Issue**: Because the FX name display logic reuses the same fx_name_buf buffer for both reading the FX name from REAPER (line 50) and formatting the display text (line 52), there's a potential buffer overflow risk if the FX name is very long.

**Impact**: If an FX name approaches 256 characters, the formatted string with module name prefix could overflow the buffer, causing truncation or undefined behavior.

**Example**: Module name "INPUT" (5 chars) + "    [" (5 chars) + FX name (240 chars) + "]" (1 char) = 251 chars, which fits. But longer module names or FX names could cause issues.

**Fix**: Use two separate buffers - one for the raw FX name, one for the formatted display text. Or calculate the required size first and ensure the format won't overflow.

### 2. No Encoder/Keyboard Navigation

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:41-72

**Issue**: Because the specification states "Encoder scrolls through 5 modules" (line 389 of plan) and "SOLO button (or click) confirms selection" (line 391), the implementation should support encoder navigation, but it only implements mouse clicks (Selectable and IsItemHovered).

**Impact**: Users with hardware controllers (the C1 surface) won't be able to navigate the module list using the encoder. The browse_scroll action exists in mapping_actions.zig but is never used by this UI.

**Note**: The encoder input would need to come from the MIDI event handler (src/csurf/midi_events.zig), which would dispatch browse_scroll actions. The UI would then read browse_state.scroll_position_rel to determine which module to highlight. This is an integration issue, not just a UI issue.

### 3. Browse State Not Actually Used for Scrolling

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:41-72

**Issue**: Because the UI iterates through all modules using comptime iteration (line 41) but never reads browse_state.scroll_position_abs or scroll_position_rel, the browse_scroll action handler (mapping_actions.zig:159-163) has no effect on the UI.

**Impact**: When encoder scrolling is implemented, it will update the scroll positions but the UI won't respond because it's not checking those values.

**Fix**: The UI should:
1. Read browse_state.scroll_position_rel to determine which module index to highlight
2. Only render a window of visible modules (or at least ensure the highlighted one is scrolled into view)
3. For a list of only 5 items, scrolling may not be necessary (all fit on screen), but if the spec requires it, implement it.

### 4. Window Size Hardcoded

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:32

**Issue**: Because the window size is hardcoded to 500x300 (line 32) instead of being derived from theme or style settings, it may not adapt well to different screen sizes or theme configurations.

**Impact**: On smaller displays or with different UI scaling, the window may be too large or too small. This is a minor UX issue.

**Note**: The fx_sel_panel.ModulePopup also uses hardcoded size 400x300 (line 174), so this is consistent with existing patterns. Consider extracting window sizes to a constants or theme configuration.

## Suggestions (3)

### 1. Add Error Handling for REAPER Queries

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:49-50

**Note**: Because TrackFX_GetFXName can fail if the track is invalid or the FX index doesn't exist, the current code assumes success. Consider checking the return value or handling the error case more gracefully. The current fallback to "[No FX]" (line 56) only handles the case where module_locations doesn't have an entry, not the case where REAPER query fails.

### 2. Extract Module Name Display Logic

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:44-57

**Note**: Because the module display text formatting logic is contained in a labeled block (blk:), it's somewhat complex and could be extracted into a helper function for clarity. Consider creating a function like `formatModuleDisplay(module: ModulesList, track_state: *const TrackState, current_track_id: ?c_int) [:0]const u8`.

### 3. Consider Using BeginChild for Scrollable List

**File**: /Users/antoine/Documents/personnel/experiments/zigwrap2/src/module_selection_panel.zig:36-72

**Note**: Because the window content is a list of selectable items, using imgui.BeginChild for the list area would enable proper scrolling behavior if the list grows beyond 5 items in the future. This is standard ImGui pattern for scrollable lists.

## Patterns Followed

- Pure function signature (no struct, state comes from parameters) ✓
- Returns ?MappingPanelAction ✓
- Window styling applied with PushWindowStyle/PopWindowStyle ✓
- Window size set with SetNextWindowSize ✓
- All 5 modules displayed via comptime iteration over ModulesList enum ✓
- FX names queried from REAPER using TrackFX_GetFXName ✓
- Selected module highlighted using DrawListSplitter pattern ✓
- Selectable widgets respond to clicks and return browse_confirm ✓
- Cancel button returns browse_cancel ✓
- Window close (X button) returns browse_cancel ✓
- Formatted with zig fmt ✓
- Compiles successfully ✓
- Proper error handling (uses try for allocations) ✓
- Function signature matches window consolidation layer requirements ✓

## Detailed Review

### Function Signature

**drawModuleSelectionPanel** (lines 18-26):
Because the specification required a pure function with specific parameters, I verified:
- ctx: imgui.ContextPtr - ✓ correct
- browse_state: *const BrowseState - ✓ read-only access to browse state
- track_state: *const TrackState - ✓ read-only access to track state
- current_track_id: ?c_int - ✓ needed for REAPER queries
- drwls_splitter: *imgui.DrawListSplitterPtr - ✓ needed for highlight rendering
- style_manager: *styles.StyleManager - ✓ needed for window styling
- translations: *TranslationStore - ✓ needed for translations (but NOT USED - Critical Issue 2)
- Returns !?MappingPanelAction - ✓ correct return type with error union

### Window Styling

**PushWindowStyle/PopWindowStyle** (lines 29-30):
Because window styling should match other panels, I verified:
- Uses PushWindowStyle with .main style (line 29)
- Defers PopStyle for cleanup (line 30)
- Matches pattern from fx_sel_panel.ModulePopup (lines 171-172)
- try/catch pattern correct (PopStyle catches errors)

**SetNextWindowSize** (line 32):
Because the window needs a fixed size, I verified:
- Size set to 500x300
- Uses null for condition (always apply)
- Larger than fx_sel_panel.ModulePopup (400x300) - reasonable for wider text
- WARNING: Hardcoded size (see Warning 4)

### Module Display

**Module iteration** (line 39-41):
Because all 5 modules need to be displayed, I verified:
- Uses comptime std.enums.values(ModulesList) to get all enum values
- Inline for loop ensures compile-time expansion
- Correctly iterates INPUT, GATE, EQ, COMP, OUTPT

**FX name querying** (lines 45-57):
Because the display should show current FX assignments, I verified:
- Queries module_locations map for each module (line 47)
- Gets track using CSurf_TrackFromID with current_track_id (line 49)
- Calls TrackFX_GetFXName to get FX name (line 50)
- Formats display text as "MODULE_NAME    [FX Name]" (line 52)
- Falls back to "[No FX]" if no location exists (line 56)
- Uses labeled block for complex formatting logic (line 46-57)
- WARNING: Single buffer used for both reading and formatting (see Warning 1)
- SUGGESTION: Formatting logic could be extracted (see Suggestion 2)

### Selection and Highlighting

**Selectable widget** (lines 59-61):
Because clicking should confirm selection, I verified:
- Uses imgui.Selectable with display_text
- Returns .browse_confirm when clicked (line 60)
- Follows specification "SOLO button (or click) confirms selection" (line 391 of plan)

**Highlight rendering** (lines 63-65):
Because selected module should be highlighted, I verified:
- Checks if is_selected matches browse_state.selected_module (line 42)
- Calls drawInvertedSlctblColors to render highlight (line 64)
- Uses DrawListSplitter pattern (matches fx_sel_panel.zig pattern)
- CRITICAL BUG: Duplicate function (see Critical Issue 3)

**Hover interaction** (lines 67-71):
Because hovering should update selection, I verified:
- Checks imgui.IsItemHovered (line 67)
- Only returns action if not already selected (line 68)
- Returns .browse_select_module action with module value (line 69)
- CRITICAL BUG: Hover highlighting lags by one frame (see Critical Issue 1)

### Cancel Actions

**Cancel button** (lines 76-78):
Because user should be able to cancel, I verified:
- Separator added before button for visual separation (line 74)
- Button labeled "Cancel" (line 76)
- Returns .browse_cancel when clicked (line 77)
- Follows specification "MUTE button (or Cancel button) cancels" (line 392 of plan)

**Window close** (lines 81-83):
Because closing the window should cancel, I verified:
- Checks !open after Begin block (line 81)
- Returns .browse_cancel if window closed (line 82)
- Follows standard ImGui pattern for close detection

### Helper Function

**drawInvertedSlctblColors** (lines 88-130):
Because highlighted items need inverted colors, I verified:
- Takes ctx, display_text, and g_drwls_splitter parameters
- Validates and creates DrawListSplitter if needed (lines 89-94)
- Splits into 2 channels (line 96)
- Defers merge (line 97)
- Channel 0: Draws filled rectangle with genlist_fg color (lines 98-116)
- Channel 1: Draws text with genlist_bg color (lines 118-129)
- Gets item rect using GetItemRectMin/Max (lines 100-106)
- Applies frame_padding to text position (lines 120-122)
- Matches fx_sel_panel.zig implementation exactly (lines 214-257)
- CRITICAL ISSUE: Duplicate code (see Critical Issue 3)

### Integration Readiness

**Action returns** (verified against mapping_actions.zig):
Because the UI must return correct actions, I verified:
- browse_confirm: void - ✓ used on line 60
- browse_cancel: void - ✓ used on lines 77, 82
- browse_select_module: ModulesList - ✓ used on line 69
- All action types match MappingPanelAction union (lines 20-23 of mapping_actions.zig)

**State access** (verified against statemachine.zig):
Because the UI must read correct state fields, I verified:
- browse_state.selected_module: ModulesList - ✓ read on line 42
- track_state.module_locations: HashMap - ✓ queried on line 47
- Both fields exist in state structure

**Type compatibility**:
Because types must match across modules, I verified:
- BrowseState imported from statemachine.zig (line 9)
- TrackState imported from track_state.zig (line 10)
- MappingPanelAction imported from mapping_actions.zig (line 12)
- ModulesList imported from statemachine.zig (line 8)
- All types correctly imported and used

### Code Quality

**Zig fmt compliance** (verified via zig fmt command):
Because all code should be formatted, I verified:
- Indentation consistent (4 spaces)
- Spacing follows Zig conventions
- Struct initialization syntax correct
- No formatting errors

**Build status** (verified via zig build command):
Because the code must compile, I verified:
- Build succeeds with exit code 0
- No compilation errors in module_selection_panel.zig
- No type mismatches
- All imports resolve correctly

**Writing style**:
Because the codebase requires proper English with articles, I verified:
- No comments present (code is self-documenting)
- No telegraphic-style writing in code
- Function and variable names clear and descriptive

**Error handling**:
Because Zig requires explicit error handling, I verified:
- All imgui calls use try (lines 29, 32, 36, 37, 59, 64, 67, 74, 76)
- Return type includes ! for error union
- defer used for cleanup (line 30, 37)
- No uncaught errors

### Match to Specification

**Display layout** (verified against plan lines 376-386):
Because the UI must match the specification, I verified:
- ✓ Window title present (though hardcoded - see Critical Issue 2)
- ✓ All 5 modules listed (INPUT, GATE, EQ, COMP, OUTPT)
- ✓ Module names with FX names in brackets format "MODULE    [FX Name]"
- ✓ Highlighted selection using DrawListSplitter pattern
- ✓ Cancel button present
- ✗ Encoder scrolling not implemented (see Warning 2)

**Behavior** (verified against plan lines 388-393):
Because the UI must implement specified behavior, I verified:
- ✗ Encoder scrolls through 5 modules - NOT IMPLEMENTED (see Warning 2)
- ✓ Current selection highlighted with inverted colors
- ✓ Click confirms selection (returns browse_confirm)
- ✓ Cancel button cancels (returns browse_cancel)
- ✓ Window close cancels (returns browse_cancel)
- ~ Hover updates selection (returns browse_select_module but lags by one frame - see Critical Issue 1)

## Overall Assessment

The module selection panel implementation successfully establishes the pure function pattern and displays all required UI elements. The code compiles, is properly formatted, and follows the structural requirements from the specification. The function signature is correct for integration with the window consolidation layer, and the basic interaction flow (click to select, cancel button, window close) works as specified.

However, there are three critical issues that must be addressed before this implementation can be considered complete:

1. The hover interaction creates a one-frame lag in highlight updates due to the action dispatch pattern
2. Translation support is incomplete (uses hardcoded English string)
3. Code duplication of the drawInvertedSlctblColors helper function

Additionally, there are four warnings about missing functionality (encoder navigation, scroll state not used, FX name formatting buffer issues, hardcoded window size) that should be addressed for production readiness.

**Status: Needs fixes before proceeding to Step 5**

Because the critical issues affect core functionality (hover interaction UX, internationalization support, code maintainability), they should be fixed before moving to Step 5. The warnings can be addressed in later iterations, but the critical issues will cause problems if left unfixed.

**Action Items:**

- [ ] CRITICAL: Fix hover interaction lag by either (a) drawing highlight immediately without action dispatch, or (b) implementing frame-based re-render trigger
- [ ] CRITICAL: Add module_sel_title translation key to translations.zig and language packs, update window title to use tr()
- [ ] CRITICAL: Extract drawInvertedSlctblColors to shared module (ui_helpers.zig) and import from both module_selection_panel.zig and fx_sel_panel.zig
- [ ] WARNING: Fix FX name formatting to use separate buffers for read and format operations
- [ ] WARNING: Implement encoder navigation support (requires integration with MIDI event handler)
- [ ] WARNING: Make UI read browse_state scroll positions and respond to browse_scroll actions
- [ ] SUGGESTION: Add error handling for REAPER TrackFX_GetFXName failures
- [ ] SUGGESTION: Extract module display formatting logic into helper function
- [ ] SUGGESTION: Consider using BeginChild for scrollable list area

### Review 3 - 2025-12-09

# Code Review: Step 5 - Refactor Mapping Panel

## Summary

The mapping panel refactoring successfully implements the pure function pattern as specified. The code correctly removes the MappingPanel struct, converts drawMappingPanel to a pure function that receives all state through parameters, loads fx_params in the enter_assign action handler, and updates all action names to use the assign_ prefix. The implementation compiles cleanly and follows the established patterns. No critical issues found.

## Critical Issues (0)

None found.

## Warnings (0)

None found.

## Suggestions (2)

### 1. Unused params Function

**File**: src/mapping_panel.zig:19-50
**Note**: Because the params function is defined but never called in drawMappingPanel, it appears to be dead code. The function iterates through fx_params and displays them as selectables, which seems like it should be part of the UI, but it's not integrated into the current panel layout. Consider either integrating this into the controls/formControls functions or removing it if it's obsolete.

### 2. Helper Functions Could Accept Fewer Parameters

**File**: src/mapping_panel.zig (various functions)
**Note**: Because helper functions like inputMappingPanel, gateMappingPanel, etc. receive both the full State and assign_state parameters, but only use State for the helper functions isParamMapped and getControlMapping, consider refactoring those helpers to accept assign_state directly instead of State. This would make the pure function pattern more explicit and reduce coupling to the global state structure.

Example:
```
// Current:
fn isParamMapped(state: *const State, param_idx: usize) bool {
    const current_mappings = switch (state.mapping_panel.mode) {
        .assign => |s| s.current_mappings,
        else => return false,
    };
    // ... rest of implementation
}

// Suggested:
fn isParamMapped(current_mappings: ModuleMappings, param_idx: usize) bool {
    // ... implementation using current_mappings directly
}
```

## Patterns Followed

**Pure Function Pattern:**
- MappingPanel struct removed completely
- drawMappingPanel is a pure function that receives state through parameters
- No internal state stored in the module
- All state comes from AssignState parameter
- Helper functions (controls, formControls, mappingWidget, etc.) follow the same pattern

**State Management:**
- fx_params ArrayList added to AssignState in statemachine.zig
- Parameters loaded in enter_assign action handler (mapping_actions.zig:75-103)
- Parameters NOT loaded in draw function (correct separation of concerns)
- FxParameter struct properly defined in AssignState with index and name fields

**Action Names:**
- All actions use assign_ prefix consistently
- Returns MappingPanelAction instead of MappingAction
- Save button returns assign_request_save
- Cancel button returns assign_cancel
- All action types properly namespaced (assign_select_parameter, assign_select_control, assign_toggle_midi_learn, assign_add_mapping, assign_remove_mapping, assign_change_module)

**Auto-Open Removal:**
- No window management code in drawMappingPanel (no Begin/End Window calls)
- Only uses BeginGroup/EndGroup for layout grouping
- Just renders content as expected

**Integration:**
- Call site in gui_lib.zig updated (line 143-151)
- Correctly extracts assign_state from mapping_panel.mode union
- Component types updated (mappingButton.zig, mappingKnob.zig use AssignState.FxParameter)
- No references to old MappingPanel struct in globals.zig

**Code Quality:**
- Code compiles successfully with zig build
- All files properly formatted with zig fmt
- Helper functions properly updated to accept assign_state
- Proper const correctness (State and AssignState parameters are *const)
- Action dispatching works correctly through gui_lib.zig

## Overall Assessment

Excellent implementation. The refactoring correctly follows the pure function pattern specified in the requirements. All structural changes are complete:

1. MappingPanel struct removed
2. drawMappingPanel converted to pure function receiving state through parameters
3. fx_params moved to AssignState and loaded in action handler
4. Action names properly prefixed with assign_
5. Window management removed from draw function
6. All integration points updated

The code is production-ready for Step 5. The two suggestions are minor code quality improvements that don't affect correctness or functionality.

**Status: PASS - Ready to proceed to Step 6**

**Action Items:**

None (suggestions are optional improvements)
