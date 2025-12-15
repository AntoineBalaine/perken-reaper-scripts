# FX Control Mode Stateful Test Context

## Overview

This document provides comprehensive context for implementing stateful tests for the FX Control (fx_ctrl) mode. It covers all action types, precise behavioral specifications, state properties to test, and references to existing implementations.

## 1. Scope and Objectives

### What We Are Testing

The fx_ctrl stateful tests focus on verifying the **three-way synchronization** between:
1. Controller/UI input (panel_input actions)
2. Application state (globals.state.fx_ctrl.values)
3. REAPER FX parameters (TrackFX_SetParamNormalized/GetParamNormalized)

Additionally, we test:
- Track phase inversion toggling
- Safe failure modes (no track, no mapping)
- Parameter vs button-type control handling

### What We Are NOT Testing

- Track validation (has dedicated test file: src/track_state.zig:512-1648)
- FX reordering (tested in src/track_state.zig:1485-1648)
- FX window display (not worth testing per user guidance)
- MIDI input routing (handled by onMidiEvent_FxCtrl in src/csurf/midi_events_fxctrl.zig)
- Track-level parameters like volume, pan, mute, solo (different subsystem)
- Unimplemented actions: set_routing_order, set_sidechain

## 2. FX Control Actions (src/fx_ctrl_actions.zig)

### 2.1 panel_input (lines 50-113)

Location: src/fx_ctrl_actions.zig:50-113

Purpose: Handles GUI widget interactions (sliders, buttons) from the ImGui panel.

#### Behavior Specification

Special handling for three CCs:
- Inpt_phase_inv (line 53-58): Dispatches toggle_phase_inv action
- Inpt_disp_on (line 59-63): Dispatches fx_win_disp action
- Inpt_disp_mode (line 65-67): Changes mode to transport

For all other CCs (lines 68-112):
1. Updates globals.state.fx_ctrl.values based on control type (lines 70-86):
   - param type: stores normalized value (0.0-1.0)
   - button type: converts to boolean (> 0.5 = true)
   - track/meter types: logs warning (shouldn't occur)

2. Sends MIDI feedback (line 89): Converts normalized value to 0-127 range

3. If current track exists and has mapping (lines 90-111):
   - Gets module for CC via cc.toModule()
   - Looks up module location in track_state.module_locations
   - If mapping exists, gets parameter index via mappings.getParamForCC()
   - Calls pReaper.TrackFX_SetParamNormalized to update REAPER

#### Properties to Test

1. **Three-way synchronization for parameter CCs**:
   - panel_input → updates state.fx_ctrl.values.param.normalized
   - panel_input → updates REAPER FX parameter (if mapping exists)
   - Both state and REAPER values must match

2. **Three-way synchronization for button CCs**:
   - panel_input → updates state.fx_ctrl.values.button
   - panel_input → updates REAPER FX parameter (if mapping exists)
   - Conversion: value > 0.5 becomes true/1.0, else false/0.0

3. **Safe failure modes**:
   - No current_tr_id: state.fx_ctrl.values updated, REAPER NOT called (no-op for REAPER)
   - No mapping for CC: state.fx_ctrl.values updated, REAPER NOT called (safe skip)
   - Both are valid states, not errors

4. **MIDI feedback**:
   - Always sent for all CCs except special three
   - Value range: 0-127 (converted from normalized 0.0-1.0)

#### Affected CCs by Type

Parameter CCs (src/fx_ctrl_state.zig:108):
```
Comp_Attack, Comp_DryWet, Comp_Ratio, Comp_Release, Comp_Thresh,
Eq_HiFrq, Eq_HiGain, Eq_HiMidFrq, Eq_HiMidGain, Eq_HiMidQ,
Eq_LoFrq, Eq_LoGain, Eq_LoMidFrq, Eq_LoMidGain, Eq_LoMidQ,
Inpt_Gain, Inpt_HiCut, Inpt_LoCut,
Out_Drive, Out_DriveChar, Out_Pan, Out_Vol,
Shp_Gate, Shp_GateRelease, Shp_Punch, Shp_sustain
```

Button CCs (src/fx_ctrl_state.zig:96-105):
```
Out_mute, Out_solo,
Comp_comp (compressor bypass),
Eq_eq (equalizer bypass),
Eq_hp_shape, Eq_lp_shape (filter shapes),
Shp_hard_gate, Shp_shape (gate bypass/shape)
```

Note: Button CCs that control FX parameters (bypass buttons) should be tested like parameter controls per user guidance.

### 2.2 on_track_entry (lines 147-161)

Location: src/fx_ctrl_actions.zig:147-161

Purpose: Main track selection handler that initializes FX control state when entering a track.

#### Behavior Specification

1. Validates track FX chain (line 151):
   - Calls fx_ctrl.validateTrack() which is defined in src/fx_ctrl_state.zig:141-160
   - validateTrack delegates to track_state.validateTrack() in src/track_state.zig:58-95
   - We do NOT test validation logic here (tested in src/track_state.zig)

2. Updates FX parameter values (line 156):
   - Calls updateFxParamValues() at src/fx_ctrl_actions.zig:165-248
   - Iterates all parameter CCs (lines 167-247)
   - For each CC with a module and mapping:
     - Reads value from REAPER via TrackFX_GetParamNormalized (line 214)
     - Updates state.fx_ctrl.values based on control type (lines 218-225)
       - param type: stores normalized value
       - button type: stores boolean (> 0.5)
     - Logs error if value < 0 (parameter read failed, lines 227-239)

3. Handles FX window display (line 158):
   - We skip testing this per user guidance

4. Sends MIDI feedback (line 160):
   - Dispatches midi_out.mode_entry action

#### Properties to Test

1. **Parameter synchronization after track entry**:
   - After on_track_entry, all state.fx_ctrl.values should reflect REAPER FX parameter values
   - For each parameter CC with valid mapping:
     - state.fx_ctrl.values[cc].param.normalized == REAPER FX param value
   - For each button CC with valid mapping:
     - state.fx_ctrl.values[cc].button == (REAPER FX param value > 0.5)

2. **Coverage of all modules**:
   - Test with tracks having different module combinations
   - INPUT, GATE, EQ, COMP, OUTPT modules
   - Each module has different parameter mappings

3. **Interaction with panel_input**:
   - Sequence: panel_input → REAPER update → on_track_entry → state matches REAPER
   - Verifies round-trip synchronization

### 2.3 toggle_phase_inv (lines 116-120)

Location: src/fx_ctrl_actions.zig:116-120

Purpose: Toggles track phase inversion.

#### Behavior Specification

1. Reads current phase state from REAPER (line 117):
   - Calls GetMediaTrackInfo_Value(track, "B_PHASE")
   - Returns 0.0 (not inverted) or 1.0 (inverted)

2. Toggles the value (line 118):
   - If phase == 0, set to 1
   - If phase != 0, set to 0

3. Writes back to REAPER (line 119):
   - Calls pReaper.SetMediaTrackInfo_Value(track, "B_PHASE", new_value)

4. Does NOT send MIDI feedback (per user guidance)

#### Properties to Test

1. **Phase toggle correctness**:
   - Initially false → toggle → true
   - Initially true → toggle → false
   - Multiple toggles alternate correctly

2. **REAPER property synchronization**:
   - Model tracks track_phase_inverted boolean
   - After toggle, REAPER B_PHASE must match model state

3. **No MIDI feedback**:
   - Verify midi_out actions are NOT dispatched

## 3. State Structure

### 3.1 FxControlState (src/fx_ctrl_state.zig:12)

Location: src/fx_ctrl_state.zig:12-120

```zig
pub const FxControlState = struct {
    track_state: TrackState = .{},  // src/track_state.zig:25
    values: std.AutoArrayHashMap(c1.CCs, ControlValue),  // line 73
    scRouting: SCRouting = .off,  // line 74
    display: ?u8 = null,  // line 77
    vol_lastpos: u8 = 0,  // line 78
    current_page: u8 = 0,  // line 82
    track_list: TrackList,  // line 83
};
```

### 3.2 ControlValue (src/fx_ctrl_state.zig:59-64)

```zig
const ControlValue = union(enum) {
    param: ParamValue,   // line 60
    track: TrackValue,   // line 61
    meter: MeterValue,   // line 62
    button: bool,        // line 63
};
```

### 3.3 ParamValue (src/fx_ctrl_state.zig:43-46)

```zig
const ParamValue = struct {
    normalized: f64 = 0.0,  // line 44
    formatted: ?[:0]const u8 = null,  // line 45
};
```

### 3.4 TrackState (src/track_state.zig:25-42)

```zig
pub const TrackState = struct {
    fx_states: [MAX_FX]struct {
        fx_index: i32,
        modules: ActiveModules = .{},
    } = undefined,  // lines 27-31
    fx_count: usize = 0,  // line 32
    module_locations: ModuleLocations = undefined,  // line 35
};
```

Where ModuleLocations is defined at src/track_state.zig:23:
```zig
const ModuleLocations = std.EnumArray(ModulesList, ?Location);
```

And Location at src/track_state.zig:18-21:
```zig
const Location = struct {
    fx_index: c_int,
    mapping: ?TaggedMapping,
};
```

## 4. Supporting Types

### 4.1 ModulesList (src/statemachine.zig)

```zig
pub const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    OUTPT,
};
```

### 4.2 TaggedMapping (src/mappings.zig)

```zig
pub const TaggedMapping = union(ModulesList) {
    INPUT: Inpt,
    GATE: Shp,
    EQ: Eq,
    COMP: Comp,
    OUTPT: Outpt,
};
```

Each mapping struct (Inpt, Shp, Eq, Comp, Outpt) contains optional parameter indices for the corresponding module's CCs.

## 5. Test Patterns from mapping_panel_stateful_test.zig

Location: src/tests/mapping_panel_stateful_test.zig

### 5.1 Model Structure (lines 24-53)

The model represents abstract expected state:
```zig
const Model = struct {
    current_mode: Mode = .fx_ctrl,
    sub_mode: ?MappingPanelMode = null,
    modules: std.EnumArray(ModulesList, ?FxInfo),
    selected_module: ModulesList = .INPUT,
    current_mappings: ?TaggedMapping = null,

    pub fn init() Model { ... }
    pub fn reset(self: *Model) void { ... }
};
```

### 5.2 System Structure (lines 61-115)

The system under test wraps real Globals with mock infrastructure:
```zig
const System = struct {
    globals: Globals,
    allocator: std.mem.Allocator,
    mock_fs: *MockFileSystem,
    resource_path: [:0]const u8,

    pub fn init(allocator: std.mem.Allocator) !System { ... }
    pub fn reset(self: *System) void { ... }
    pub fn deinit(self: *System) void { ... }
};
```

Key setup steps (lines 67-97):
1. Create MockFileSystem
2. Copy embedded files to temp directory
3. Build resource_path
4. Initialize Globals with mock filesystem
5. Set initial mode to fx_ctrl

### 5.3 Command Pattern (example: AddMapping, lines 346-465)

```zig
const AddMapping = struct {
    control: c1.CCs,
    param: u8,
    pub const name = "add_mapping";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        // Returns true if command can execute
        return model.current_mode == .mapping_panel and
            model.sub_mode == .ASSIGN and
            model.current_mappings != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Updates abstract model state
        // Modifies model.current_mappings based on self.control
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // 1. Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals,
            .{ .assign_add_mapping = .{ .param = self.param, .control = self.control } });

        // 2. Update model
        self.onModelOnly(model);

        // 3. Verify synchronization
        const sut_mappings = switch (sut.globals.state.mapping_panel.mode) {
            .assign => |s| s.current_mappings,
            else => return false,
        };

        // Detailed verification that specific field was updated
        return /* detailed comparison */;
    }
};
```

### 5.4 Test Execution (lines 703-788)

```zig
test "mapping panel hierarchical state machine" {
    const allocator = std.testing.allocator;

    var model = Model.init();
    var sut = try System.init(allocator);
    defer sut.deinit();

    // Create command instances
    var cmd1 = Command1{};
    var cmd2 = Command2{ .param = value };
    // ...

    // Register commands
    const commands = [_]Command(Model, System){
        Command(Model, System).init(&cmd1),
        Command(Model, System).init(&cmd2),
        // ...
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

## 6. Mock Infrastructure

### 6.1 Reaper Mock (src/models/reaper_mock.zig)

The mock provides complete REAPER API simulation:

```zig
pub fn setupTestModel(
    allocator: std.mem.Allocator,
    trck_count: ?usize,
    prealloc_tracks: ?usize
) struct {
    orig_funcs: Mocks,
    model_ptr: *Session,
    pub fn teardown(self: *@This()) void { ... }
}
```

Mocked Functions Relevant to fx_ctrl:
- GetMediaTrackInfo_Value / SetMediaTrackInfo_Value: Track properties including B_PHASE
- TrackFX_GetParamNormalized: Read FX parameter values
- TrackFX_SetParamNormalized: Write FX parameter values (via pReaper.zig wrapper)
- TrackFX_GetCount, TrackFX_GetFXName, TrackFX_GetNamedConfigParm: FX chain info
- CSurf_TrackFromID, CSurf_TrackToID: Track ID conversions
- GetNumTracks, CountTracks, GetTrack: Track enumeration

### 6.2 Test Model Types (src/models/)

Track model (src/models/track_model.zig):
```zig
pub const Track = struct {
    name: ?utils.StringPool.StringRef,
    fx_list: std.ArrayListUnmanaged(FX),
    automation_mode: AutomationMode,
    info: TrackInfo,
    peak_info: ?PeakInfo,
};
```

FX model (src/models/fx_model.zig):
```zig
pub const FX = struct {
    guid: utils.Guid,
    enabled: bool = true,
    params: []Param,
    named_configs: NamedConfigs,
};

pub const Param = struct {
    name: [:0]const u8,
    normalized_value: f64 = 0.0,
    formatted_value: [:0]const u8,
};
```

## 7. Proposed Model for fx_ctrl Stateful Tests

```zig
const Model = struct {
    // Current track (null means no track selected)
    current_track_id: ?c_int = null,

    // Track properties
    track_phase_inverted: bool = false,

    // Application state: FX parameter values (mirrors fx_ctrl.values)
    // Only tracks parameter and button type CCs
    fx_params: std.AutoHashMap(c1.CCs, f64),

    // REAPER state: FX parameter values (simulates REAPER's internal state)
    // Separate from fx_params to test synchronization
    reaper_fx_params: std.AutoHashMap(c1.CCs, f64),

    // Module presence (which modules are available on current track)
    modules: std.EnumSet(ModulesList),

    // Module mappings (whether each module has a mapping)
    has_mapping: std.EnumArray(ModulesList, bool),

    pub fn init(allocator: std.mem.Allocator) Model {
        return .{
            .fx_params = std.AutoHashMap(c1.CCs, f64).init(allocator),
            .reaper_fx_params = std.AutoHashMap(c1.CCs, f64).init(allocator),
            .modules = std.EnumSet(ModulesList).initEmpty(),
            .has_mapping = std.EnumArray(ModulesList, bool).initFill(false),
        };
    }

    pub fn deinit(self: *Model) void {
        self.fx_params.deinit();
        self.reaper_fx_params.deinit();
    }

    pub fn reset(self: *Model) void {
        self.current_track_id = null;
        self.track_phase_inverted = false;
        self.fx_params.clearRetainingCapacity();
        self.reaper_fx_params.clearRetainingCapacity();
        self.modules = std.EnumSet(ModulesList).initEmpty();
        self.has_mapping = std.EnumArray(ModulesList, bool).initFill(false);
    }
};
```

## 8. Proposed Commands

### 8.1 Track Management Commands

#### SetTrack
Purpose: Simulates selecting a track (on_track_entry)

```zig
const SetTrack = struct {
    track_id: c_int,
    modules: []const ModulesList,  // Which modules to enable
    pub const name = "set_track";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;  // Can always set track
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        model.current_track_id = self.track_id;
        model.modules.setPresent(.INPUT, false);
        model.modules.setPresent(.GATE, false);
        model.modules.setPresent(.EQ, false);
        model.modules.setPresent(.COMP, false);
        model.modules.setPresent(.OUTPT, false);

        for (self.modules) |module| {
            model.modules.setPresent(module, true);
            model.has_mapping.set(module, true);
        }

        // Initialize all params to 0.5 for simplicity
        // In real implementation, would read from REAPER mock
        for (all_parameter_ccs) |cc| {
            model.fx_params.put(cc, 0.5) catch unreachable;
            model.reaper_fx_params.put(cc, 0.5) catch unreachable;
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute on_track_entry action
        const media_track = reaper.CSurf_TrackFromID(self.track_id, false);
        fx_ctrl_actions.fxCtrlActions(&sut.globals, .{ .on_track_entry = media_track });

        // Update model
        self.onModelOnly(model);

        // Verify synchronization: fx_ctrl.values should match REAPER
        for (all_parameter_ccs) |cc| {
            const module = cc.toModule() orelse continue;
            if (!model.modules.contains(module)) continue;

            if (sut.globals.state.fx_ctrl.values.get(cc)) |value| {
                const expected = model.reaper_fx_params.get(cc) orelse continue;
                const actual = switch (value) {
                    .param => |p| p.normalized,
                    .button => |b| if (b) 1.0 else 0.0,
                    else => continue,
                };
                if (@abs(actual - expected) > 0.001) return false;
            }
        }

        return true;
    }
};
```

#### ClearTrack
Purpose: Simulates deselecting track (current_tr_id becomes null)

### 8.2 Parameter Update Commands

#### SetParameterFromPanel
Purpose: Simulates panel_input for a parameter CC

```zig
const SetParameterFromPanel = struct {
    cc: c1.CCs,
    value: f64,  // Normalized 0.0-1.0
    pub const name = "set_param_panel";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        // Can only set param if track exists and module has mapping
        if (model.current_track_id == null) return false;
        const module = self.cc.toModule() orelse return false;
        return model.modules.contains(module) and model.has_mapping.get(module);
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Update both application state and REAPER state (three-way sync)
        model.fx_params.put(self.cc, self.value) catch unreachable;
        model.reaper_fx_params.put(self.cc, self.value) catch unreachable;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute panel_input action
        fx_ctrl_actions.fxCtrlActions(&sut.globals,
            .{ .panel_input = .{ .cc = self.cc, .value = self.value } });

        // Update model
        self.onModelOnly(model);

        // Verify three-way synchronization
        // 1. Check fx_ctrl.values
        const state_value = sut.globals.state.fx_ctrl.values.get(self.cc) orelse return false;
        const state_normalized = switch (state_value) {
            .param => |p| p.normalized,
            else => return false,
        };
        if (@abs(state_normalized - self.value) > 0.001) return false;

        // 2. Check REAPER FX parameter
        const module = self.cc.toModule().?;
        const module_loc = sut.globals.state.fx_ctrl.track_state.module_locations.get(module) orelse return false;
        const mapping = module_loc.mapping orelse return false;
        const param_idx = mappings.getParamForCC(self.cc, mapping) orelse return false;

        const track = reaper.CSurf_TrackFromID(model.current_track_id.?, false);
        const reaper_value = reaper.TrackFX_GetParamNormalized(track, module_loc.fx_index, param_idx);
        if (@abs(reaper_value - self.value) > 0.001) return false;

        return true;
    }
};
```

#### SetParameterFromReaper
Purpose: Simulates REAPER callback updating a parameter (then re-syncing via on_track_entry)

#### SetButtonFromPanel
Purpose: Simulates panel_input for a button CC (similar to SetParameterFromPanel but for buttons)

### 8.3 Property Commands

#### TogglePhaseInversion
Purpose: Toggles track phase inversion

```zig
const TogglePhaseInversion = struct {
    pub const name = "toggle_phase";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_track_id != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.track_phase_inverted = !model.track_phase_inverted;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        const track = reaper.CSurf_TrackFromID(model.current_track_id.?, false);

        // Execute toggle action
        fx_ctrl_actions.fxCtrlActions(&sut.globals, .{ .toggle_phase_inv = track });

        // Update model
        self.onModelOnly(model);

        // Verify REAPER B_PHASE property matches model
        const reaper_phase = reaper.GetMediaTrackInfo_Value(track, "B_PHASE");
        const expected: f64 = if (model.track_phase_inverted) 1.0 else 0.0;

        return @abs(reaper_phase - expected) < 0.001;
    }
};
```

## 9. Test Properties Summary

### Property 1: Three-Way Parameter Synchronization
For any parameter CC with valid mapping:
- panel_input(cc, value) → state.fx_ctrl.values[cc] == value AND REAPER FX param == value
- Verified by: SetParameterFromPanel command's onPair verification

### Property 2: Three-Way Button Synchronization
For any button CC with valid mapping:
- panel_input(cc, value) → state.fx_ctrl.values[cc].button == (value > 0.5) AND REAPER FX param matches
- Verified by: SetButtonFromPanel command's onPair verification

### Property 3: Track Entry Synchronization
After on_track_entry:
- For all CCs: state.fx_ctrl.values[cc] == REAPER FX param value
- Verified by: SetTrack command's onPair verification

### Property 4: Phase Toggle Correctness
- toggle_phase_inv toggles B_PHASE property
- No MIDI feedback sent
- Verified by: TogglePhaseInversion command's onPair verification

### Property 5: Safe Failure Mode - No Track
- panel_input with current_tr_id == null → state.fx_ctrl.values updated, REAPER NOT called
- Verified by: SetParameterFromPanel with ClearTrack precondition

### Property 6: Safe Failure Mode - No Mapping
- panel_input for CC without mapping → state.fx_ctrl.values updated, REAPER NOT called
- Verified by: SetParameterFromPanel with module that has no mapping

### Property 7: Module Coverage
- Test all 5 modules (INPUT, GATE, EQ, COMP, OUTPT)
- Each module has different parameter mappings
- Verified by: SetTrack command with different module combinations

## 10. Implementation Strategy

### Phase 1: Infrastructure
- Create Model struct with proper fields
- Create System struct with mock infrastructure
- Set up test helpers for module and mapping initialization

### Phase 2: Basic Commands
- Implement SetTrack command
- Implement ClearTrack command
- Verify track selection and deselection works

### Phase 3: Parameter Commands
- Implement SetParameterFromPanel for parameter CCs
- Verify three-way synchronization for parameters
- Test with all modules

### Phase 4: Button Commands
- Implement SetButtonFromPanel for button CCs
- Verify three-way synchronization for buttons
- Test bypass buttons (Comp_comp, Eq_eq, Shp_shape, etc.)

### Phase 5: Property Commands
- Implement TogglePhaseInversion
- Verify B_PHASE property updates
- Verify no MIDI feedback

### Phase 6: Integration
- Run full stateful test with all commands
- Verify 500+ random command sequences pass
- Test with different random seeds
