# Game Plan for Implementing REAPER Stateful Testing Model

## Overview
This plan outlines the development of a simplified REAPER state model for property-based testing. The model will mimic only the APIs used by our application, focusing on track and FX manipulation without UI interactions.

## Data Structures

### FX Model
```zig
struct FX {
    name: [:0]const u8,
    guid: [:0]const u8,
    enabled: bool,
    params: []Param,
    pin_mappings: PinMappings,
    named_configs: NamedConfigs,
}

struct Param {
    name: [:0]const u8,
    normalized_value: f64,
    formatted_value: [:0]const u8,
}

struct PinMappings {
    // Input/output pin routing data
}

struct NamedConfigs {
    original_name: [:0]const u8,
    renamed_name: [:0]const u8,
    gain_reduction_db: f64,
}
```

### Track Model
```zig
struct Track {
    name: [:0]const u8,
    fx_list: []FX,
    automation_mode: AutomationMode,
    info: TrackInfo,
    peak_info: ?PeakInfo,  // Only valid during playback
}

struct TrackInfo {
    phase: bool,            // B_PHASE
    num_channels: i32,      // I_NCHAN
    volume: f64,            // D_VOL
    pan: f64,               // D_PAN
    mute: bool,             // B_MUTE
    solo: i32,              // I_SOLO
    track_number: i32,      // IP_TRACKNUMBER
}

enum AutomationMode {
    trim_read,
    read,
    touch,
    write,
    latch,
}

struct PeakInfo {
    // Peak meter data
}
```

### Session Model
```zig
struct Session {
    tracks: []Track,
    selected_track_indices: []usize,
    last_touched_track_index: ?usize,
    cursor_position: f64,
    global_automation_mode: AutomationMode,
    playrate: f64,
    tempo: f64,
    grid_settings: GridSettings,
    markers: []TempoTimeSigMarker,
    frame_rate: f64,
    midi_inputs: []MidiDevice,
    midi_outputs: []MidiDevice,
}

struct GridSettings {
    // Grid configuration
}

struct TempoTimeSigMarker {
    position: f64,
    tempo: f64,
    time_sig_num: i32,
    time_sig_denom: i32,
}

struct MidiDevice {
    name: [:0]const u8,
    number: i32,
}
```

## Implementation Phases

### Phase 1: Core Structure Setup
1. Create basic data structures for the model
2. Define the API interface that mirrors REAPER's functions
3. Implement memory management for the model

### Phase 2: Track Manipulation
1. Implement basic track creation/deletion
2. Implement track selection
3. Implement track property access/modification (volume, pan, mute, solo)

### Phase 3: FX Manipulation
1. Implement FX addition/enumeration
2. Implement FX parameter access/modification
3. Implement FX enable/bypass

### Phase 4: Integration with RapidCheck
1. Define commands to represent API calls
2. Create generators for model states
3. Implement property checks

### Phase 5: Validation and Testing
1. Create test scenarios with known outcomes
2. Verify model behavior against expectations
3. Run randomized property-based tests

## API Implementation Approach

For each REAPER API function our application uses, create:
1. A function with identical signature in our mock API
2. Logic that updates our model state
3. Appropriate return values that mimic REAPER's behavior

Example:
```zig
fn GetTrack(project: ?*void, trackidx: i32) ?*Track {
    _ = project;
    if (trackidx < 0 || trackidx >= state.tracks.len) return null;
    return &state.tracks[trackidx];
}

fn SetMediaTrackInfo_Value(track: ?*Track, parmname: [*:0]const u8, newvalue: f64) bool {
    if (track == null) return false;

    const param = std.mem.span(parmname);
    if (std.mem.eql(u8, param, "D_VOL")) {
        track.?.info.volume = newvalue;
        return true;
    }
    // Handle other parameters...

    return false;
}
```

## Testing Strategy

1. **Simple Commands**: Start with simple, atomic operations (e.g., select track, change volume)
2. **Command Sequences**: Test sequences of related operations
3. **Property Verification**: Define properties the system should maintain
4. **Randomized Testing**: Use RapidCheck to generate random command sequences

## Initial Playground Implementation

The playground should:
1. Initialize the model with a small predefined state
2. Provide a way to execute API calls and observe state changes
3. Include simple assertions to verify expected behavior
4. Allow for command logging to debug test failures

## Notes for Implementation

- Keep state operations pure where possible
- Use allocators consistently for memory management
- Document assumptions and simplifications
- Focus first on correctness, then on API coverage
- Add only what's needed for the application under test
