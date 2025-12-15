# FX Control Mode Stateful Test Implementation Plan

## Overview

This document breaks down the implementation of fx_ctrl stateful tests into actionable phases. Each phase builds on the previous one and has clear success criteria.

## Prerequisites

Before starting implementation:
- Review docs/fx_ctrl_stateful_test_context.md for complete behavioral specifications
- Understand src/tests/mapping_panel_stateful_test.zig as the reference implementation pattern
- Familiarity with zlowcheck stateful testing framework (see .claude/skills/zlowcheck-stateful)

## Implementation Phases

### Phase 1: Test File Setup and Model Definition

**Goal**: Create the test file with Model and System structures.

**File to Create**: src/tests/fx_ctrl_stateful_test.zig

#### Tasks

1. Create file header with imports:
```zig
const std = @import("std");
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const StatefulConfig = zlowcheck.StatefulConfig;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const ModulesList = statemachine.ModulesList;
const fx_ctrl_actions = @import("../fx_ctrl_actions.zig");
const fx_ctrl_state = @import("../fx_ctrl_state.zig");
const c1 = @import("../c1.zig");
const reaper = @import("../reaper.zig").reaper;
const mappings = @import("../mappings.zig");
const models = struct {
    const reaper = @import("../models/reaper_mock.zig");
    const midi = @import("../models/midi_mock.zig");
};
```

2. Define Model struct (see context doc section 7):
   - current_track_id: ?c_int
   - track_phase_inverted: bool
   - fx_params: std.AutoHashMap(c1.CCs, f64)
   - reaper_fx_params: std.AutoHashMap(c1.CCs, f64)
   - modules: std.EnumSet(ModulesList)
   - has_mapping: std.EnumArray(ModulesList, bool)
   - init() function
   - deinit() function
   - reset() function

3. Define System struct (pattern from mapping_panel_stateful_test.zig:61-115):
   - globals: Globals
   - allocator: std.mem.Allocator
   - init() function with REAPER mock setup
   - reset() function
   - deinit() function

4. Create helper functions:
   - getAllParameterCCs() → []const c1.CCs (list all parameter CCs)
   - getAllButtonCCs() → []const c1.CCs (list all button CCs that control FX params)
   - ccToModule(cc: c1.CCs) → ?ModulesList (wrapper for cc.toModule())

**Success Criteria**:
- File compiles without errors
- Model.init(), Model.deinit(), Model.reset() work
- System.init(), System.deinit(), System.reset() work
- REAPER mock is properly initialized in System.init()

**Estimated Complexity**: Medium (150-200 lines)

---

### Phase 2: Track Management Commands

**Goal**: Implement commands for track selection and deselection.

#### Task 2.1: Implement SetTrack Command

Create the SetTrack command struct:

```zig
const SetTrack = struct {
    track_id: c_int,
    modules_to_enable: []const ModulesList,
    pub const name = "set_track";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- checkPrecondition: always true
- onModelOnly:
  - Set current_track_id
  - Enable specified modules in model.modules
  - Set has_mapping to true for enabled modules
  - Initialize fx_params and reaper_fx_params to 0.5 for all CCs belonging to enabled modules
- onPair:
  - Set up REAPER mock track with FX chain matching modules_to_enable
  - Call fxCtrlActions with on_track_entry action
  - Verify state.fx_ctrl.values matches model.fx_params for all CCs

**Testing Strategy**:
- Create a simple unit test that:
  - Initializes Model and System
  - Executes SetTrack with [.INPUT, .COMP] modules
  - Verifies onPair returns true
  - Checks state.fx_ctrl.track_state.module_locations has entries for INPUT and COMP

**Estimated Complexity**: High (100-150 lines for command + 50 lines for test)

#### Task 2.2: Implement ClearTrack Command

Create the ClearTrack command struct:

```zig
const ClearTrack = struct {
    pub const name = "clear_track";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- checkPrecondition: model.current_track_id != null
- onModelOnly:
  - Set current_track_id to null
  - Clear modules set
  - Clear fx_params and reaper_fx_params
- onPair:
  - Set sut.globals.state.current_tr_id = null
  - Verify state matches model

**Testing Strategy**:
- Unit test that:
  - Executes SetTrack followed by ClearTrack
  - Verifies track is cleared

**Estimated Complexity**: Low (50-70 lines)

**Success Criteria for Phase 2**:
- SetTrack command compiles and passes unit test
- ClearTrack command compiles and passes unit test
- Can select and deselect tracks without errors

---

### Phase 3: Parameter Update Commands

**Goal**: Implement commands for updating parameter CCs via panel_input.

#### Task 3.1: Implement SetParameterFromPanel Command

Create the SetParameterFromPanel command struct with parameterized CC and value:

```zig
const SetParameterFromPanel = struct {
    cc: c1.CCs,
    value: f64,  // Normalized 0.0-1.0
    pub const name = "set_param_panel";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- checkPrecondition:
  - Return false if model.current_track_id == null
  - Return false if CC's module not in model.modules
  - Return false if module doesn't have mapping
  - Return true otherwise
- onModelOnly:
  - Update model.fx_params[cc] = value
  - Update model.reaper_fx_params[cc] = value (simulates three-way sync)
- onPair:
  - Execute fxCtrlActions with panel_input action
  - Verify state.fx_ctrl.values[cc].param.normalized == value
  - Get module location and mapping
  - Get parameter index from mapping
  - Read REAPER FX parameter value
  - Verify REAPER value == value

**Testing Strategy**:
- Unit test that:
  - Executes SetTrack with INPUT module
  - Executes SetParameterFromPanel for Inpt_Gain
  - Verifies three-way synchronization

**Estimated Complexity**: High (150-200 lines for command + 80 lines for test)

#### Task 3.2: Test All Parameter CCs

Create test cases for representative parameter CCs from each module:
- INPUT: Inpt_Gain, Inpt_HiCut, Inpt_LoCut
- GATE: Shp_Gate, Shp_GateRelease, Shp_Punch, Shp_sustain
- EQ: Eq_HiFrq, Eq_HiGain, Eq_LoFrq, Eq_LoGain
- COMP: Comp_Attack, Comp_Thresh, Comp_Ratio, Comp_Release, Comp_DryWet
- OUTPT: Out_Drive, Out_DriveChar, Out_Pan, Out_Vol

**Testing Strategy**:
- Create parameterized test or multiple unit tests
- For each CC, verify:
  - SetParameterFromPanel correctly updates both state and REAPER
  - Values round-trip correctly through on_track_entry

**Estimated Complexity**: Medium (100-150 lines)

**Success Criteria for Phase 3**:
- SetParameterFromPanel command compiles and passes tests
- All module parameter CCs verified to work correctly
- Three-way synchronization property holds

---

### Phase 4: Button Control Commands

**Goal**: Implement commands for updating button CCs (bypass buttons).

#### Task 4.1: Implement SetButtonFromPanel Command

Create the SetButtonFromPanel command struct:

```zig
const SetButtonFromPanel = struct {
    cc: c1.CCs,
    value: f64,  // Will be converted to bool (> 0.5)
    pub const name = "set_button_panel";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- Similar to SetParameterFromPanel but:
  - Stores boolean in model: value > 0.5
  - Verifies state.fx_ctrl.values[cc].button matches
  - Verifies REAPER value matches (1.0 if true, 0.0 if false)

**Testing Strategy**:
- Unit test for each button CC:
  - Comp_comp (compressor bypass)
  - Eq_eq (equalizer bypass)
  - Shp_shape (shape button)
  - Shp_hard_gate (hard gate button)
  - Eq_hp_shape, Eq_lp_shape (filter shapes)

**Estimated Complexity**: Medium (100-120 lines for command + 60 lines for tests)

**Success Criteria for Phase 4**:
- SetButtonFromPanel command compiles and passes tests
- All button CCs verified to work correctly
- Boolean conversion (> 0.5) works correctly

---

### Phase 5: Property Commands

**Goal**: Implement toggle_phase_inv command.

#### Task 5.1: Implement TogglePhaseInversion Command

Create the TogglePhaseInversion command struct:

```zig
const TogglePhaseInversion = struct {
    pub const name = "toggle_phase";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- checkPrecondition: model.current_track_id != null
- onModelOnly:
  - Toggle model.track_phase_inverted
- onPair:
  - Get MediaTrack from track_id
  - Execute fxCtrlActions with toggle_phase_inv action
  - Read B_PHASE property from REAPER mock
  - Verify matches model.track_phase_inverted

**Testing Strategy**:
- Unit test that:
  - Sets track
  - Toggles phase multiple times
  - Verifies alternating true/false
  - Verifies REAPER B_PHASE property matches

**Estimated Complexity**: Low (60-80 lines for command + 40 lines for test)

**Success Criteria for Phase 5**:
- TogglePhaseInversion command compiles and passes test
- B_PHASE property correctly toggles in REAPER mock
- No MIDI feedback sent (verified by inspection, not explicit test)

---

### Phase 6: Safe Failure Mode Commands

**Goal**: Test that panel_input handles missing track and missing mapping correctly.

#### Task 6.1: Implement SetParameterNoTrack Command

Create command that tries to set parameter when no track is selected:

```zig
const SetParameterNoTrack = struct {
    cc: c1.CCs,
    value: f64,
    pub const name = "set_param_no_track";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- checkPrecondition: model.current_track_id == null
- onModelOnly: no-op (state should not change)
- onPair:
  - Execute panel_input
  - Verify no REAPER API calls were made
  - Verify state unchanged

**Testing Strategy**:
- Unit test that:
  - Ensures no track is selected
  - Calls panel_input
  - Verifies system handles gracefully (no crash, no state change)

**Estimated Complexity**: Low (50-60 lines)

#### Task 6.2: Implement SetParameterNoMapping Command

Create command that tries to set parameter for module without mapping:

```zig
const SetParameterNoMapping = struct {
    cc: c1.CCs,
    value: f64,
    pub const name = "set_param_no_mapping";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool;
    pub fn onModelOnly(self: *@This(), model: *Model) void;
    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool;
};
```

Implementation details:
- checkPrecondition:
  - model.current_track_id != null
  - CC's module in model.modules
  - model.has_mapping[module] == false
- onModelOnly:
  - Update model.fx_params[cc] (state should update)
  - Do NOT update model.reaper_fx_params[cc] (REAPER should not be called)
- onPair:
  - Execute panel_input
  - Verify state.fx_ctrl.values[cc] updated
  - Verify REAPER parameter NOT updated (read and compare to original value)

**Testing Strategy**:
- Unit test that:
  - Sets up track with module but no mapping
  - Calls panel_input
  - Verifies state updates but REAPER doesn't

**Estimated Complexity**: Medium (70-90 lines)

**Success Criteria for Phase 6**:
- SetParameterNoTrack command works correctly
- SetParameterNoMapping command works correctly
- Both failure modes are safe (no crashes, expected behavior)

---

### Phase 7: Integration and Full Stateful Test

**Goal**: Integrate all commands into full stateful test with random command sequences.

#### Task 7.1: Create Command Registry

Create the full command registry:

```zig
test "fx_ctrl stateful test" {
    const allocator = std.testing.allocator;

    var model = try Model.init(allocator);
    defer model.deinit();

    var sut = try System.init(allocator);
    defer sut.deinit();

    // Create command instances for each module
    // Need multiple instances per command type with different parameters

    // Track commands
    var set_track_input_comp = SetTrack{
        .track_id = 1,
        .modules_to_enable = &[_]ModulesList{ .INPUT, .COMP },
    };
    var set_track_all = SetTrack{
        .track_id = 1,
        .modules_to_enable = &[_]ModulesList{ .INPUT, .GATE, .EQ, .COMP, .OUTPT },
    };
    var clear_track_cmd = ClearTrack{};

    // Parameter commands (create multiple instances with different CCs)
    var set_inpt_gain_01 = SetParameterFromPanel{ .cc = .Inpt_Gain, .value = 0.1 };
    var set_inpt_gain_05 = SetParameterFromPanel{ .cc = .Inpt_Gain, .value = 0.5 };
    var set_inpt_gain_09 = SetParameterFromPanel{ .cc = .Inpt_Gain, .value = 0.9 };
    // ... more instances for other CCs

    // Button commands
    var set_comp_bypass_on = SetButtonFromPanel{ .cc = .Comp_comp, .value = 0.8 };
    var set_comp_bypass_off = SetButtonFromPanel{ .cc = .Comp_comp, .value = 0.2 };
    // ... more instances

    // Property commands
    var toggle_phase_cmd = TogglePhaseInversion{};

    // Register all commands
    const commands = [_]Command(Model, System){
        Command(Model, System).init(&set_track_input_comp),
        Command(Model, System).init(&set_track_all),
        Command(Model, System).init(&clear_track_cmd),
        Command(Model, System).init(&set_inpt_gain_01),
        Command(Model, System).init(&set_inpt_gain_05),
        Command(Model, System).init(&set_inpt_gain_09),
        // ... all other command instances
        Command(Model, System).init(&toggle_phase_cmd),
    };

    // Generate random command sequence
    var bytes: [128 * 1024]u8 = undefined;
    const seed: u64 = @intCast(std.time.milliTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    prng.random().bytes(&bytes);
    var finite_prng = FinitePrng.init(&bytes);
    var random = finite_prng.random();

    var cmd_seq = try CommandList(Model, System).init(&commands, &random, 500, allocator);
    defer cmd_seq.deinit(allocator);

    // Run stateful test
    const config = StatefulConfig{ .verbose = false };
    const result = try assertStateful(Model, System, &cmd_seq, &model, &sut, config);

    if (result) |failure_info| {
        std.debug.print("\nTest failed at command index: {}\n", .{failure_info});
        return error.StatefulTestFailed;
    }
}
```

**Estimated Complexity**: Medium (200-300 lines for comprehensive command instantiation)

#### Task 7.2: Run and Debug

1. Run test with verbose = true initially to see command execution
2. Fix any failing command sequences
3. Run with verbose = false and 500+ iterations
4. Test with different random seeds

**Success Criteria for Phase 7**:
- Test compiles without errors
- Test passes with 500+ random command sequences
- No false positives (commands fail when they shouldn't)
- No false negatives (commands pass when they shouldn't)

---

## Summary of Files

### Files to Create

1. src/tests/fx_ctrl_stateful_test.zig (~800-1000 lines total)

### Files to Reference (No Changes)

1. src/fx_ctrl_actions.zig (behavior specification source)
2. src/fx_ctrl_state.zig (state structure reference)
3. src/track_state.zig (track validation reference)
4. src/tests/mapping_panel_stateful_test.zig (pattern reference)
5. src/models/reaper_mock.zig (mock infrastructure)

### Files to Read During Implementation

1. src/mappings.zig (for getParamForCC function)
2. src/c1.zig (for CCs enum and toModule() method)
3. .claude/skills/zlowcheck-stateful (for zlowcheck API reference)

---

## Next Steps

1. Read and understand docs/fx_ctrl_stateful_test_context.md completely
2. Review src/tests/mapping_panel_stateful_test.zig for pattern understanding
3. Start with Phase 1 implementation
4. Proceed through phases sequentially
5. Test at each phase before moving to next
6. Document findings and deviations from plan
