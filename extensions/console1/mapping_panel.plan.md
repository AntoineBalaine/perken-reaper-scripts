# Mapping Panel Implementation Plan

## Folder Structure (Question #2 Answer)

### File Path

The code reads from:
```
<REAPER_RESOURCE_PATH>/Data/Perken/Console1/maps/<module>/<fx_name>.ini
```

### How It Works

- `src/resources/maps/` contains shipped defaults embedded into the binary at compile time (fs_helpers.zig:60-74)
- At startup, `ensureConfigPath()` creates the runtime directory and copies embedded defaults there if they do not exist (fs_helpers.zig:76-177)
- The app only reads from and writes to the runtime location (mappings.zig:219-228, 347-356)

The `resources/` folder is just for shipping defaults in the binary, not for reading at runtime.

---

## Data Structure Changes Needed

### 1. MapStore Changes (src/mappings.zig)

#### Problem

The hashmap is keyed only by FX name, so we can only store one mapping per FX.

#### Current Structure

```zig
COMP: StringArrayHashMapUnmanaged(Comp)  // fx_name -> Comp
```

#### New Structure

Because we need to support multiple mappings per FX, we key on file paths instead of just FX names. All hashmaps are unmanaged to maintain explicit allocation control.

```zig
pub const MappingsList = struct {
    mappings: StringArrayHashMapUnmanaged(?Comp),  // filepath -> ?Comp (null = file not found)
    preferred_mapping: [:0]const u8,  // filepath of preferred mapping

    allocator: std.mem.Allocator,  // stored for deinit

    fn deinit(self: *MappingsList) void {
        self.mappings.deinit(self.allocator);
    }
};

COMP: StringArrayHashMapUnmanaged(MappingsList),  // fx_name -> MappingsList
```

Note: The in-use mapping is stored in the track state. The preferred mapping is stored here as a default when a track FX is first encountered.

#### File Path Changes

- From: `maps/COMP/VST: ReaComp.ini`
- To: `maps/COMP/VST: ReaComp/default.ini`

#### Functions to Update

- `getMap()` - accept filepath parameter
- `saveToFile()` - accept filepath parameter
- `get()` - return preferred mapping or accept filepath
- New: `getMappingNames()` - list available mappings for an FX
- New: `setPreferredMapping()` - set the preferred mapping for an FX

#### Design Decision: Nested Hashmaps (Unmanaged)

We are using nested hashmaps instead of an interning strategy because:
- We will not have many mappings per FX (typically 1-5)
- Lookups are infrequent after initial lazy load
- Code complexity is lowest with nested structure
- Memory overhead is negligible for our use case

IMPORTANT: All hashmaps must be unmanaged (StringArrayHashMapUnmanaged) to maintain explicit control over allocations.

### 2. Channel Strip Preset Structure (new: src/channel_strip.zig)

NOTE: LOW PRIORITY - Implement preset UI for individual mappings first.

#### Data Structures

Because channel strips are not stored in application state at runtime, we only need file paths. The list of channel strips is loaded at display time, and contents are read only at selection time.

```zig
pub const ChannelStripPreset = struct {
    INPUT: ?[]const u8 = null,   // file path to mapping
    GATE: ?[]const u8 = null,
    EQ: ?[]const u8 = null,
    COMP: ?[]const u8 = null,
    OUTPT: ?[]const u8 = null,
};
```

#### File Format

INI at `<controller_dir>/channel_strips/<preset_name>.ini`:

```ini
[INPUT]
mapping_path = maps/INPUT/JS: Volume Pan Smoother v5/default.ini

[COMP]
mapping_path = maps/COMP/VST: ReaComp/aggressive.ini
```

#### Key Feature

Because the preset references mappings by path, we are protected against data corruption between REAPER restarts (stateless design).

### 3. MappingState Changes (src/statemachine.zig:118)

#### Add Field

```zig
target_mapping_filepath: ?[:0]const u8,  // which mapping we're editing (null if creating new)
```

Because we may be creating a new mapping from scratch, this field is optional. If null, we are creating a new mapping and will prompt for a name when saving.

### 4. Missing Files Error Tracking (src/statemachine.zig)

#### Alternative Approach: Use Optional in MapStore

Instead of tracking missing files separately, we can make the mapping storage optional in MapStore:

```zig
// In MappingsList:
mappings: StringArrayHashMapUnmanaged(?Comp)  // null = file not found on disk
```

Because this approach is simpler and avoids a separate error tracking structure, we should use optional values in the storage itself. When loading fails, we store null instead of the Comp data.

### 5. UI Window Mode Changes (src/statemachine.zig)

#### Add to Globals

Because there will likely be other window state to track (similar to `temp_settings`), we use an optional property in globals:

```zig
// In Globals:
mapping_panel_state: ?struct {
    visible: bool,
    // ... other window-specific state
} = null,
```

If the property exists, the window should be displayed. Because this pattern matches how `temp_settings` works, it provides consistency.

---

## Implementation Epics and Tasks

### Epic 1: Multiple Mappings Per FX (Foundation)

PRIORITY: HIGH - Required for everything else

#### Tasks

1. Add file format versioning - add magic number/version field to mapping file format for future compatibility
2. Update MapStore data structure - define MappingsList with filepath keys, change hashmap types, update init/deinit (all unmanaged)
3. Update file path handling - modify `getMap()` and `saveToFile()` for directory-based paths
4. Add new MapStore methods - `getMappingNames()`, `setPreferredMapping()`, handle optional Comp values for missing files
5. Update MappingState - add `target_mapping_filepath: ?[:0]const u8` field
6. Update tests - all MapStore tests need updates
7. Update fs_helpers.zig - embedded defaults need new directory layout

### Epic 2: Preset UI (Load/Save for Individual Mappings)

PRIORITY: HIGH - Must come before channel strips

#### Tasks

1. Implement preset browser UI - reuse existing FX browser pattern (encoder + MIDI buttons, usable from UI)
2. Add preset selection logic - when selecting same FX with different mapping, replace mapping in console state but keep host FX chain untouched
3. Console1 button mapping - Preset button for load, Mode+Preset for save
4. Implement save preset UI - show dialog with list of existing mappings and text input for name (pre-filled with "default")
5. Add overwrite protection - show confirmation popup when saving with existing name
6. No directory navigation in save dialog - only list existing mappings for current FX

### Epic 3: Mapping Panel UI Improvements

PRIORITY: MEDIUM

#### Tasks

1. Remove auto-open behavior - find and remove code that auto-opens panel
2. Make mapping panel a floating window - add `mapping_panel_state` to globals, use floating ImGui window
3. Add mapping name selection to panel - UI to select/create mappings
4. Add manual trigger for mapping panel - buttons in fx_ctrl or settings

### Epic 4: Polish and Error Handling

PRIORITY: MEDIUM

#### Tasks

1. Fix + button crash (src/ButtonsBar.zig:71)
2. Implement MIDI learn (already tracked in TODO)
3. Missing files UI - error display when optional Comp values are null
4. Preset browser improvements - deletion, display enhancements

### Epic 5: Channel Strip Presets

PRIORITY: LOW - Implement last

#### Tasks

1. Create channel strip data structures - new src/channel_strip.zig file with filepath-based structure
2. Implement file I/O - `load()`, `save()` functions
3. Handle missing files - use optional values, graceful handling
4. Implement apply preset functionality - loads all mappings from file paths
5. Add UI for channel strip browser

---

## Implementation Order (4 Phases)

### Phase 1: Foundation (Required for everything)

#### Epic 1: Multiple Mappings Per FX

- Data structure changes first (Tasks 1.1-1.4)
- Update fs_helpers (Task 1.7)
- Migration and tests (Tasks 1.5-1.6)

Rationale: Because everything depends on this foundation.

### Phase 2: Preset System (Core feature)

#### Epic 2: Preset UI (Load/Save for Individual Mappings)

- Implement preset browser with directory navigation (Task 2.1)
- Add preset selection logic (Tasks 2.2, 2.4)
- Console1 integration (Task 2.3)
- Save preset UI (Task 2.5)

Rationale: Because this is the primary way users will interact with multiple mappings. Must come before channel strips.

### Phase 3: UI Improvements (Makes system usable)

#### Epic 3: Mapping Panel UI Improvements + Epic 4: Polish

- Remove auto-open, make floating (Tasks 3.1-3.2)
- Add mapping selection and triggers (Tasks 3.3-3.4)
- Error handling and polish (Epic 4)

Rationale: Because we need manual triggers before removing auto-open behavior, and these improvements make the system more polished.

### Phase 4: Advanced Features (Low priority)

#### Epic 5: Channel Strip Presets

- Data structures and file I/O (Tasks 5.1-5.2)
- Missing files handling (Task 5.3)
- Apply functionality and UI (Tasks 5.4-5.5)

Rationale: Because this is a convenience feature that builds on the multi-mapping foundation. Implement last.

---

## Critical Path

These must be done in order:

1. MapStore data structure change (filepath-based keys, optional Comp values)
2. File path handling update (directory structure)
3. Preset browser UI implementation
4. Preset selection logic (handle same FX vs different FX)
5. Mapping panel floating window
6. (LOW PRIORITY) Channel strip data structures
7. (LOW PRIORITY) Channel strip file I/O

---

## Open Questions

### 1. ~~Default Mapping Name~~ (RESOLVED)

DECISION: Use "default" as the placeholder text in the save file name input.

Workflow:
- User loads an FX that has no mapping in MapStore (mapping is null)
- User creates a preset/mapping and hits save in the mapping panel
- A save dialog opens with text input focused, pre-filled with "default"
- User can type a different name or accept "default"
- No directory navigation is provided, only listing of existing mappings for the current FX

### 2. ~~Migration Strategy~~ (RESOLVED)

DECISION: No migration. This app is not in production yet.

Because we are still in development, we focus on feature implementation and tests only. However, we need to add a file format versioning scheme (magic number) to mapping files for future compatibility.

### 3. ~~Interning Strategy for MapStore~~ (RESOLVED)

DECISION: Use nested hashmaps with all unmanaged structures.

Because we will not have many mappings per FX (typically 1-5), lookups are infrequent after initial load, and the code complexity is lowest with nested structure, we are using nested StringArrayHashMapUnmanaged. The memory overhead is negligible for our use case.

### 4. ~~Preset Selection UX~~ (RESOLVED)

DECISION: Default behavior without prompting.

When the user selects an FX that matches the current one but with a different mapping, we replace the mapping in the console state but leave the host FX chain untouched. Because this is less disruptive (no audio glitches) and matches user intent (different parameter mappings, not different FX instance), we do this without prompting.

### 5. ~~Console1 Preset Browser Controls~~ (RESOLVED)

DECISION: Use existing FX browser implementation pattern.

Because we already have a similar implementation in the FX browser, we reuse that pattern. The browser is usable both from the console (encoder + MIDI buttons) and from the UI.

### 6. ~~Preset Overwrite Protection~~ (RESOLVED)

DECISION: Prompt user with popup on overwrite.

When saving a mapping with a name that already exists, we show a confirmation popup asking the user to confirm overwrite.

### 7. ~~Channel Strip Naming~~ (RESOLVED)

DECISION: User choice.

Channel strip preset names are up to the user. They can name them after tracks, processing styles, or anything else that makes sense to them.

---

## Summary of Decisions

All design questions have been resolved:

1. Default mapping name: "default" as placeholder in save dialog
2. Migration strategy: No migration (development phase only), add file format versioning
3. Interning strategy: Nested unmanaged hashmaps
4. Preset selection UX: Replace mapping without prompting when same FX selected
5. Browser controls: Reuse existing FX browser pattern
6. Overwrite protection: Show confirmation popup
7. Channel strip naming: User choice

## Next Steps - Phase 1 Implementation Tasks

Ready to begin Phase 1 implementation: Multiple Mappings Per FX (Foundation).

### Task Breakdown (In Order)

#### 1. Add File Format Versioning

**Files to modify**: `src/mappings.zig`

- Add version field to each mapping struct (Comp, Eq, Inpt, Outpt, Shp)
- Update `readToU8Struct()` to parse and validate version field
- Update `saveToFile()` to write version field
- Define current version constant (e.g., `MAPPING_FORMAT_VERSION = 1`)

#### 2. Update MapStore Data Structure

**Files to modify**: `src/mappings.zig`

- Define `MappingsList` struct with nested unmanaged hashmap and allocator field
- Add `deinit()` method to `MappingsList`
- Change module fields from `StringArrayHashMapUnmanaged(Comp)` to `StringArrayHashMapUnmanaged(MappingsList)`
- Update `empty()` function to initialize new structure
- Update `init()` function to create `MappingsList` instances
- Update `deinit()` to properly clean up nested structures (iterate and call `MappingsList.deinit()`)

#### 3. Update File Path Handling

**Files to modify**: `src/mappings.zig`

- Modify `getMap()` to accept `mapping_name` parameter and construct directory-based path: `maps/<MODULE>/<fx_name>/<mapping_name>.ini`
- Update `saveToFile()` to accept `mapping_name` parameter and use directory-based path
- Ensure directory creation before saving (create `maps/<MODULE>/<fx_name>/` directory if it does not exist)
- Update `sanitizeFxName()` if needed for directory handling

#### 4. Add New MapStore Methods

**Files to modify**: `src/mappings.zig`

- `getMappingNames(fx_name: [:0]const u8, module: ModulesList) []const [:0]const u8` - list all mapping files for an FX by reading directory
- `setPreferredMapping(fx_name: [:0]const u8, module: ModulesList, filepath: [:0]const u8)` - update preferred_mapping field in MappingsList
- `getPreferredMapping(fx_name: [:0]const u8, module: ModulesList) ?[:0]const u8` - return preferred mapping filepath
- Update `get()` to return preferred mapping when no filepath is specified, or specific mapping when filepath is provided
- Handle optional Comp values (null = file not found on disk)

#### 5. Update MappingState

**Files to modify**: `src/statemachine.zig`

- Add `target_mapping_filepath: ?[:0]const u8` field to `MappingState`
- Update initialization code to set field to null

#### 6. Update fs_helpers.zig

**Files to modify**: `src/fs_helpers.zig`, `src/resources/maps/`

- Update embedded defaults structure from flat files to directory structure
- Modify resource embedding to handle subdirectories: `maps/<MODULE>/<fx_name>/default.ini`
- Update `ensureConfigPath()` to create directory structure correctly

#### 7. Update Tests

**Files to modify**: `src/mappings.zig` (test blocks)

- Update "MapStore - initialization and caching" test for new structure
- Update "MapStore - lazy loading and caching" test for filepath-based access
- Update "MapStore - invalid fx name" test
- Update "MapStore - mapping validation" test
- Update "MapStore - cross-module access" test
- Add new tests for `getMappingNames()`, `setPreferredMapping()`, `getPreferredMapping()`
- Add tests for optional Comp values (missing file handling)

### Dependencies

Tasks must be completed in order because:
- Task 2 depends on Task 1 (data structures need versioning fields)
- Task 3 depends on Task 2 (file path handling needs new data structure)
- Task 4 depends on Tasks 2-3 (new methods operate on new structure and paths)
- Task 5 is independent but related
- Task 6 depends on Task 3 (needs to know new path structure)
- Task 7 depends on all previous tasks (validates everything works)

---

## Phase 2 Implementation Tasks - Preset UI (Load/Save)

### Task Breakdown (In Order)

#### 1. Implement Preset Browser UI

**Files to modify**: New file `src/preset_browser.zig`, possibly `src/fx_sel_panel.zig` or similar for reference

- Study existing FX browser implementation to understand the pattern
- Create preset browser data structure to track:
  - Current navigation state (which FX is selected, list of mappings)
  - Selected mapping
  - Module filter (which module we're browsing)
- Implement directory listing function that reads `maps/<MODULE>/<fx_name>/` to get available mappings
- Create ImGui UI that displays:
  - Module selection (COMP, EQ, INPUT, OUTPT, GATE)
  - FX list for selected module
  - Mapping list for selected FX
  - Navigation breadcrumbs (Module > FX > Mapping)
- Implement encoder + MIDI button controls:
  - Encoder: scroll through current list
  - Track buttons: quick selection
  - Module buttons: filter by module type
  - Mode button: navigate up/back
  - Preset button: confirm selection

#### 2. Add Preset Selection Logic

**Files to modify**: `src/preset_browser.zig`, `src/statemachine.zig`, integration with actions

- Implement `applyPreset()` function that:
  - Takes selected FX name, module, and mapping filepath
  - Checks if selected FX matches current track FX for that module
  - If match: replace mapping in console state, keep host FX chain untouched
  - If no match: assign new FX to module and load mapping
- Add action for preset selection to dispatch system
- Update state machine to handle preset selection events
- Integrate with REAPER API for FX assignment when needed

#### 3. Console1 Button Mapping

**Files to modify**: `src/midi_input.zig` or MIDI handling files, `src/actions.zig`

- Map Preset button to open preset browser (load mode)
- Map Mode+Preset button combination to open save preset dialog
- Add MIDI input handling for new button combinations
- Create actions for:
  - `OpenPresetBrowser` - opens browser in load mode
  - `OpenSavePresetDialog` - opens save dialog
- Wire actions through dispatch system

#### 4. Implement Save Preset UI

**Files to modify**: New file `src/save_preset_dialog.zig` or add to `src/preset_browser.zig`

- Create save dialog UI that shows:
  - List of existing mappings for current FX (read from `maps/<MODULE>/<fx_name>/`)
  - Text input field for mapping name (focused, pre-filled with "default")
  - Save button
  - Cancel button
- No directory navigation - only show current FX mappings
- Implement text input handling with ImGui
- Connect to MapStore `saveToFile()` with user-provided name

#### 5. Add Overwrite Protection

**Files to modify**: `src/save_preset_dialog.zig`

- Before saving, check if mapping file already exists at path
- If exists, show confirmation popup:
  - Message: "Mapping '<name>' already exists. Overwrite?"
  - Yes/No buttons
- If user confirms, proceed with save
- If user cancels, return to save dialog with text input still focused

#### 6. Integration and Testing

**Files to modify**: Various integration points

- Integrate preset browser with main UI loop
- Ensure preset browser opens on Preset button press
- Ensure save dialog opens on Mode+Preset press
- Test encoder and button navigation
- Test mapping selection and application
- Test save workflow with overwrite protection
- Add tests for preset browser logic
- Add tests for preset selection logic

### Dependencies

Tasks must be completed in order because:
- Task 2 depends on Task 1 (selection logic needs browser UI structure)
- Task 3 can be done in parallel with Tasks 1-2 (independent button mapping)
- Task 4 depends on Task 1 (reuses browser pattern and data structures)
- Task 5 depends on Task 4 (overwrite protection is part of save workflow)
- Task 6 depends on all previous tasks (integration validates everything)

---

## Phase 3 Implementation Tasks - Mapping Panel UI Improvements

### Task Breakdown (In Order)

#### 1. Remove Auto-Open Behavior

**Files to modify**: Search codebase for mapping panel triggers

- Use Grep to find where mapping panel is automatically opened
- Remove or comment out auto-open logic
- Ensure mapping panel only opens on explicit user action

#### 2. Make Mapping Panel a Floating Window

**Files to modify**: `src/statemachine.zig`, `src/mapping_panel.zig` or equivalent

- Add `mapping_panel_state` to Globals:
  ```zig
  mapping_panel_state: ?struct {
      visible: bool,
      // ... other window-specific state
  } = null,
  ```
- Update mapping panel rendering code to use floating ImGui window (not docked)
- Check `mapping_panel_state` existence to determine if window should be displayed
- Add close button to window that sets `mapping_panel_state` to null

#### 3. Add Mapping Name Selection to Panel

**Files to modify**: `src/mapping_panel.zig`

- Add dropdown or list widget to select active mapping for current FX
- Call `MapStore.getMappingNames()` to populate list
- Display current active mapping (from `MappingState.target_mapping_filepath`)
- When user selects different mapping:
  - Update `MappingState.target_mapping_filepath`
  - Load selected mapping into panel for editing

#### 4. Add Manual Trigger for Mapping Panel

**Files to modify**: `src/fx_ctrl_panel.zig` or `src/settings_panel.zig`, `src/actions.zig`

- Add button in FX Control panel or Settings panel to open mapping panel
- Create action `OpenMappingPanel` that:
  - Creates `mapping_panel_state` in Globals if it does not exist
  - Sets `visible` to true
- Wire action through dispatch system
- Optionally add keyboard shortcut or MIDI button mapping

#### 5. Testing and Integration

**Files to modify**: Various

- Verify mapping panel no longer auto-opens
- Test opening mapping panel via new manual trigger
- Test floating window behavior (movable, closable)
- Test mapping selection dropdown
- Test switching between mappings in panel
- Verify state persistence while window is open

### Dependencies

Tasks can be completed in order or partially in parallel:
- Task 1 is independent (just removal)
- Task 2 is mostly independent but should be done before Task 3
- Task 3 depends on Task 2 (needs floating window structure)
- Task 4 can be done in parallel with Tasks 2-3
- Task 5 depends on all previous tasks

---

## Phase 4 Implementation Tasks - Polish and Error Handling

### Task Breakdown (In Order)

#### 1. Fix + Button Crash

**Files to modify**: `src/ButtonsBar.zig:71`

- Read the code at the crash location
- Identify the cause of the crash
- Implement proper bounds checking or null handling
- Test the fix thoroughly

#### 2. Implement MIDI Learn

**Files to modify**: `src/mapping_panel.zig`, MIDI input handling

Note: This is already tracked in existing TODO. Reference existing MIDI learn design if available.

- Add MIDI learn mode toggle in mapping panel
- When enabled, capture incoming MIDI CC messages
- Map captured CC to selected parameter in mapping
- Update mapping data structure with new assignment
- Provide visual feedback during MIDI learn

#### 3. Missing Files UI

**Files to modify**: `src/mapping_panel.zig` or main UI

- When MapStore returns null for a mapping (file not found), display error message
- Show which mappings are missing:
  - Module name
  - FX name
  - Mapping name
- Provide options:
  - Create new mapping
  - Choose different mapping
  - Dismiss error
- Consider adding error list to UI if multiple mappings are missing

#### 4. Preset Browser Improvements

**Files to modify**: `src/preset_browser.zig`

- Add delete functionality:
  - Right-click or dedicated button to delete mapping
  - Show confirmation dialog before deletion
  - Remove file from disk
  - Update browser display
- Display enhancements:
  - Show mapping metadata (date modified, version, etc.)
  - Add search/filter functionality
  - Improve visual hierarchy
  - Add icons or indicators for different mapping types

#### 5. Testing and Polish

**Files to modify**: Various

- Test all error handling paths
- Verify missing file UI appears correctly
- Test delete functionality in preset browser
- Polish visual appearance of all UIs
- Add tooltips where helpful
- Ensure consistent styling across all new UI elements

### Dependencies

Tasks have some flexibility in order:
- Task 1 is independent (specific bug fix)
- Task 2 is independent (MIDI learn feature)
- Task 3 should be done after Phase 1 (needs optional Comp handling)
- Task 4 should be done after Phase 2 (needs preset browser)
- Task 5 depends on all previous tasks (final polish)

---

## Implementation Summary

### Phase Overview

1. **Phase 1 (Foundation)**: 7 tasks - MapStore refactor with nested unmanaged hashmaps, file versioning, directory structure
2. **Phase 2 (Preset UI)**: 6 tasks - Preset browser, save dialog, button mapping, overwrite protection
3. **Phase 3 (Panel Improvements)**: 5 tasks - Remove auto-open, floating window, mapping selection, manual trigger
4. **Phase 4 (Polish)**: 5 tasks - Bug fixes, MIDI learn, error handling, browser enhancements

### Total Estimated Tasks: 23

### Critical Milestones

- **Milestone 1**: Phase 1 complete - Multiple mappings per FX working, all tests passing
- **Milestone 2**: Phase 2 complete - Users can browse and save presets via Console1
- **Milestone 3**: Phase 3 complete - Mapping panel is fully functional floating window
- **Milestone 4**: Phase 4 complete - All polish and error handling complete

### Note on Phase 5 (Channel Strips)

Phase 5 (Channel Strip Presets) is LOW PRIORITY and not detailed here. Because channel strips build on the preset system from Phases 1-2, they should only be implemented after those phases are stable and well-tested.
