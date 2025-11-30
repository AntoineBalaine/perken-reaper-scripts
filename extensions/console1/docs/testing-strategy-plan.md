# Testing Strategy Plan

## Overview

This plan establishes a comprehensive testing strategy for the REAPER Console1 extension, focusing on:
- Converting in-REAPER tests to local mock-based tests
- Comprehensive unit tests for track validation logic
- Stateful testing for mode actions using zlowcheck
- Removing RapidCheck in favor of zlowcheck

## Implementation Order

### 1. Remove RapidCheck (Cleanup)

**Rationale:** Remove unused testing infrastructure before adding new tests.

**Changes:**
- Delete `src/tests/rapidcheck/` directory entirely
- Remove RapidCheck references from `build_tests.zig`
- Remove any RapidCheck imports from test files

### 2. Port Track Validation Tests from TestRunner to zlowcheck

**Current state:** `track_state_tests.zig` uses TestRunner which runs inside REAPER (uses EnumProjects, Undo_BeginBlock2, etc.)

**Target pattern:** Convert to zlowcheck stateful tests like `settings_zlocheck.zig`, running locally with reaper_mock.zig

**New file:** `src/tests/track_validation_zlowcheck.zig`

**Model:**
```
TrackValidationModel = struct {
    fx_chain: []FxInfo,  // simple representation of FX on track
    expected_modules: ModuleCoverage,
}

FxInfo = struct {
    name: []const u8,
    has_c1_suffix: bool,
    module: ?ModulesList,
}
```

**Commands:**
- AddFxCmd - adds FX to track
- RemoveFxCmd - removes FX from track
- RenameFxCmd - renames FX (adds/removes C1 suffix)
- ValidateTrackCmd - triggers validateTrack() and checks consistency
- SetDefaultFxCmd - changes default FX configuration

**Preconditions:**
- AddFxCmd: track exists, not at MAX_FX limit
- RemoveFxCmd: track has FX at specified index
- RenameFxCmd: FX exists at index
- ValidateTrackCmd: always valid

**Validation:**
- After validateTrack(), verify coverage matches model expectations
- Verify duplicate suffixes are removed
- Verify missing modules are inserted
- Verify FX order matches canonical order (INPUT, GATE, EQ, COMP, OUTPT)

**Delete after conversion:** `test_runner.zig` (no longer needed)

### 3. Expand Unit Tests for Track Validation

**Target file:** Add tests to `src/track_state.zig` (inline tests)

**Functions needing additional edge case tests:**

1. `parseC1Suffix()` - already has basic test, add:
   - Multiple C1 suffixes in same name
   - C1 suffix with no closing paren
   - Empty string, very long strings

2. `analyzeCoverage()` - needs tests for:
   - Empty FX list
   - All FX are duplicates of same module
   - Partial coverage (only some modules present)
   - MAX_PARSED_FX boundary conditions

3. `removeDuplicateModule()` - needs tests for:
   - Multiple spaces before suffix
   - Suffix at start of name
   - Suffix at end of name with trailing content
   - Name with no suffix (should not crash)

4. `reorderFx2()` - needs tests for:
   - Empty chain → full default chain
   - Partial chain (INPUT and OUTPT only) → inserts middle modules
   - Already correct order → no changes
   - Completely wrong order → reorders to canonical

5. `updateTrackState()` - needs tests for:
   - Verify module_locations correctly populated
   - Verify fx_count matches coverage
   - Missing mappings handled gracefully

**Also test utility functions:**
- `utils.calculateNewScrollPosition()` - wrapping, bounds, delta calculation
- Any GUID parsing functions in utils.zig
- Any MIDI value conversion functions

### 4. Add Stateful Tests for FX Control Mode

**New file:** `src/tests/fx_ctrl_zlowcheck.zig`

**Model:**
```
FxCtrlModel = struct {
    track_id: ?u8,
    parameter_values: std.EnumMap(c1.CCs, f64),  // simplified param state
    muted: bool,
    solo: bool,
    routing_order: ModulesOrder,
    sidechain: SCRouting,
}
```

**Commands:**
- MidiInputCmd - sends MIDI CC input
- PanelInputCmd - sends widget input
- SetVolumeCmd - changes track volume
- SetPanCmd - changes track pan
- ToggleMuteCmd - toggles mute state
- ToggleSoloCmd - toggles solo state
- SetRoutingCmd - changes module routing order
- SetSidechainCmd - changes sidechain routing
- TrackEntryCmd - switches to different track

**Preconditions:**
- Most commands: track_id is set (track selected)
- MidiInputCmd/PanelInputCmd: valid CC for current module
- SetRoutingCmd: new order is different from current
- TrackEntryCmd: valid track ID

**Validation:**
- Parameter values propagate to Globals.state.fx_ctrl.values
- Mute/solo state matches REAPER track state
- Routing changes reflected in fx_ctrl state
- Track switches clear/update state appropriately

### 5. Add Stateful Tests for Transport Mode

**New file:** `src/tests/transport_zlowcheck.zig`

**Model:**
```
TransportModel = struct {
    playing: bool,
    recording: bool,
    loop_enabled: bool,
    jog_pos: u8,
    zoom_h: u8,
    zoom_v: u8,
    grid_pos: u8,
    rate_pos: u8,
    track_sel: u8,
}
```

**Commands:**
- PlayCmd - toggles playback
- RecCmd - toggles recording
- StopCmd - stops playback
- LoopToggleCmd - toggles loop
- JogCmd - jogs timeline position
- ZoomHorizontalCmd - horizontal zoom
- ZoomVerticalCmd - vertical zoom
- GridCmd - adjusts grid size
- RateCmd - adjusts playback rate
- TrackSelCmd - selects track via transport

**Preconditions:**
- PlayCmd: not already playing (or allow toggle)
- RecCmd: track has rec arm enabled (or always allow)
- JogCmd/ZoomCmd/GridCmd/RateCmd: valid position value
- TrackSelCmd: valid track index

**Validation:**
- Transport state in Globals.state.transport matches model
- REAPER transport state matches expectations
- Scroll positions wrap correctly
- Delta calculations produce correct results

### 6. Add Stateful Tests for FX Selection Mode

**New file:** `src/tests/fx_sel_zlowcheck.zig`

**Model:**
```
FxSelModel = struct {
    panel_open: bool,
    selected_fx: ?[]const u8,  // FX name
    selected_module: ?ModulesList,
    browse_position: u8,
}
```

**Commands:**
- OpenPanelCmd - opens FX selection panel
- ClosePanelCmd - closes panel (save or cancel)
- BrowseFxCmd - scrolls through FX list
- SelectFxCmd - selects FX from list
- SelectModuleCmd - chooses which module to assign to
- AssignFxCmd - assigns selected FX to selected module

**Preconditions:**
- OpenPanelCmd: panel not already open
- ClosePanelCmd: panel is open
- BrowseFxCmd: panel open, valid position
- SelectFxCmd: panel open, FX list not empty
- SelectModuleCmd: panel open
- AssignFxCmd: both FX and module selected

**Validation:**
- Panel state matches model
- FX assignment updates default_fx configuration
- Module assignment persists correctly

**Note:** Requires implementing FX library model (TODO in reaper_mock.zig:103)

### 7. Add Stateful Tests for Mapping Mode

**New file:** `src/tests/mapping_zlowcheck.zig`

**Model:**
```
MappingModel = struct {
    panel_open: bool,
    mappings: std.ArrayList(MappingEntry),
    midi_learn_active: bool,
    selected_param: ?u8,
}

MappingEntry = struct {
    fx_name: []const u8,
    module: ModulesList,
    cc: c1.CCs,
    param_index: u8,
}
```

**Commands:**
- OpenPanelCmd - opens mapping panel
- ClosePanelCmd - closes panel
- AddMappingCmd - creates new mapping
- RemoveMappingCmd - deletes mapping
- EditMappingCmd - modifies existing mapping
- MidiLearnCmd - activates MIDI learn mode
- SelectParamCmd - selects parameter for mapping

**Preconditions:**
- OpenPanelCmd: panel not open
- ClosePanelCmd: panel open
- AddMappingCmd: panel open, valid mapping data
- RemoveMappingCmd: mapping exists at index
- EditMappingCmd: mapping exists
- MidiLearnCmd: panel open, param selected

**Validation:**
- Mappings persist to MapStore
- MIDI learn captures correct CC
- Parameter mappings apply correctly
- Duplicate mappings handled appropriately

### 8. Handle Mode Transitions

**Option A:** Convert `mode_switch_tests.zig` to zlowcheck
**Option B:** Integrate mode transitions into each mode's stateful tests as ChangeModeCmd

**Recommended: Option B**

Each mode's stateful test file includes:
- ChangeModeCmd that transitions to another mode
- Precondition: transition is valid per `valid_transitions` map
- Validation: current_mode updated, state initialized correctly, MIDI feedback sent

This tests mode transitions in the context of actual usage patterns rather than in isolation.

**Delete after integration:** `mode_switch_tests.zig` (if Option B chosen)

## Critical Files to Read During Implementation

**For track validation tests:**
- src/track_state.zig (complete file)
- src/tests/track_state_tests.zig (current tests to convert)
- src/models/reaper_mock.zig (mock API for tests)

**For action stateful tests:**
- src/fx_ctrl_actions.zig (FX control actions)
- src/transport_actions.zig (transport actions)
- src/fx_sel_actions.zig (FX selection actions)
- src/mapping_actions.zig (mapping actions)
- src/actions.zig (dispatch mechanism)
- src/statemachine.zig (valid transitions, modes)
- src/globals.zig (state structure)

**For zlowcheck patterns:**
- src/tests/settings_zlocheck.zig (reference implementation)
- src/tests/mode_switch_tests.zig (setup/teardown helpers)

**For build configuration:**
- build_tests.zig (test compilation setup)

## Success Criteria

1. All tests run locally without REAPER (using mocks)
2. TestRunner deleted, no in-REAPER test execution
3. RapidCheck completely removed
4. Track validation has comprehensive unit test coverage
5. Each mode (fx_ctrl, transport, fx_sel, mapping, settings) has stateful tests
6. Mode transitions tested as part of stateful test suites
7. All tests pass with `zig build test`

## Notes

- Keep `mode_switch_tests.zig` test_setup() helper for initializing mocks - used across test files
- FX library model (reaper_mock.zig:103) must be implemented for fx_sel tests
- MIDI input tests (midi_wrapper_mock.zig:258) likely covered by stateful tests, mark TODO as resolved
- Use std.testing.allocator for all test allocations
- Follow fuzzing pattern from settings_zlocheck.zig for byte-driven tests
