# Mapping Panel Testing Strategy

## Phase 1 Testing - Foundation

### Unit Tests (src/mappings.zig)

#### File Format Versioning

- Test reading mapping files with version field
- Test writing mapping files with version field
- Test rejecting files with unsupported version numbers
- Test handling missing version field (backward compatibility consideration)

#### MapStore Data Structure

- Test `FxMaps` initialization with allocator
- Test `FxMaps.deinit()` properly frees nested hashmap
- Test MapStore initialization creates empty FxMaps for each module
- Test MapStore.deinit() properly cleans up all nested structures
- Test memory leak detection (no leaks after deinit)

#### File Path Handling

- Test `getMap()` constructs correct directory-based paths
- Test `saveToFile()` creates directory structure if it does not exist
- Test `saveToFile()` writes to correct directory-based path
- Test `sanitizeFxName()` handles special characters in FX names
- Test path construction with various FX name formats

#### New MapStore Methods

- Test `getMappingNames()` returns empty list for FX with no mappings
- Test `getMappingNames()` returns correct list of mapping files
- Test `setPreferredMapping()` updates preferred_mapping field
- Test `getPreferredMapping()` returns correct filepath
- Test `get()` returns preferred mapping when no filepath specified
- Test `get()` returns specific mapping when filepath provided
- Test `get()` returns null for missing files (optional Comp handling)
- Test lazy loading still works with new structure
- Test caching works correctly with multiple mappings per FX

#### Edge Cases

- Test handling FX with zero mappings
- Test handling FX with many mappings (10+)
- Test handling very long FX names
- Test handling FX names with special characters (slashes, colons, etc.)
- Test concurrent access (if applicable)
- Test disk full scenarios (save failures)
- Test corrupted mapping files (parse errors)

### Integration Tests

#### Full Workflow Tests

- Test loading default mapping for new FX
- Test saving mapping creates correct file structure
- Test loading saved mapping reads correct data
- Test switching between multiple mappings for same FX
- Test preferred mapping is used when loading FX
- Test MapStore survives across init/deinit cycles

#### fs_helpers Integration

- Test embedded defaults are copied to correct directory structure
- Test `ensureConfigPath()` creates all necessary directories
- Test resource embedding works with new subdirectory structure

---

## Phase 2 Testing - Preset UI

### Unit Tests

#### Preset Browser Logic

- Test directory listing reads correct FX names
- Test mapping listing reads correct mapping names for FX
- Test navigation state tracking (current module, FX, mapping)
- Test filtering by module type
- Test breadcrumb generation

#### Preset Selection Logic

- Test `applyPreset()` with matching FX (replaces mapping, keeps FX)
- Test `applyPreset()` with non-matching FX (assigns new FX, loads mapping)
- Test detecting when FX matches current track FX
- Test loading mapping from filepath

#### Save Dialog Logic

- Test listing existing mappings for current FX
- Test default name pre-fill
- Test name validation (empty names, invalid characters)
- Test save path construction

#### Overwrite Protection

- Test detecting existing file before save
- Test user confirmation flow (yes/no)
- Test save proceeds after confirmation
- Test save cancels without confirmation

### Integration Tests

#### Browser Workflow

- Test opening preset browser
- Test navigating through modules
- Test selecting FX
- Test viewing mappings for FX
- Test confirming selection
- Test canceling selection

#### Save Workflow

- Test opening save dialog from mapping panel
- Test entering mapping name
- Test saving new mapping
- Test saving with existing name triggers confirmation
- Test overwrite after confirmation
- Test cancel returns to dialog

#### MIDI Button Integration

- Test Preset button opens browser
- Test Mode+Preset opens save dialog
- Test encoder scrolls through lists
- Test track buttons select items
- Test module buttons filter by type
- Test navigation with hardware controls

### Manual Testing Required

- Visual layout of preset browser
- Encoder responsiveness
- Button feedback
- UI performance with many mappings
- Error message clarity

---

## Phase 3 Testing - Mapping Panel UI

### Unit Tests

#### Mapping Panel State

- Test `mapping_panel_state` creation in globals
- Test window visibility tracking
- Test state persistence while window open
- Test state cleanup on close

#### Mapping Selection

- Test `getMappingNames()` populates dropdown
- Test selecting different mapping updates `target_mapping_filepath`
- Test loading selected mapping into panel

### Integration Tests

#### Auto-Open Removal

- Test mapping panel does not open automatically on FX selection
- Test mapping panel does not open on track change
- Test mapping panel only opens on explicit user action

#### Floating Window Behavior

- Test window is movable
- Test window is closable via X button
- Test window can be reopened after closing
- Test window persists position (if applicable)

#### Manual Trigger

- Test button in FX Control panel opens mapping panel
- Test keyboard shortcut opens mapping panel (if added)
- Test MIDI button opens mapping panel (if added)

### Manual Testing Required

- Window positioning and sizing
- Visual appearance of floating window
- Dropdown usability
- Close button functionality

---

## Phase 4 Testing - Polish and Error Handling

### Unit Tests

#### Bug Fixes

- Test + button does not crash (specific fix for ButtonsBar.zig:71)
- Test bounds checking works correctly
- Test null handling works correctly

#### Missing Files UI

- Test detecting null mappings from MapStore
- Test error message display includes correct details (module, FX, mapping)
- Test error dismissal
- Test creating new mapping from error state

#### Preset Browser Enhancements

- Test delete functionality removes file from disk
- Test delete updates browser display
- Test delete confirmation dialog
- Test metadata display (if implemented)
- Test search/filter functionality (if implemented)

### Integration Tests

#### Error Handling Paths

- Test loading missing mapping shows error
- Test multiple missing mappings display correctly
- Test error recovery (choosing different mapping)
- Test error recovery (creating new mapping)

#### Delete Workflow

- Test deleting mapping from browser
- Test confirmation before deletion
- Test mapping removed from disk
- Test browser updates after deletion
- Test cannot delete last mapping (if applicable)

#### MIDI Learn Workflow (if implemented)

- Test enabling MIDI learn mode
- Test capturing MIDI CC messages
- Test mapping CC to parameter
- Test visual feedback during learn
- Test disabling MIDI learn mode

### Manual Testing Required

- All error messages are clear and helpful
- Delete confirmation is not annoying
- Visual polish of all UI elements
- Tooltips are helpful
- Consistent styling across features

---

## Testing Tools and Approaches

### Property-Based Testing (zlowcheck)

Because the codebase uses zlowcheck for property-based testing, we should add properties for:

#### MapStore Properties

- Property: Any mapping saved can be loaded back with identical data
- Property: Preferred mapping is always in the mappings list
- Property: `getMappingNames()` always returns valid filepaths
- Property: Deinit after init leaves no memory leaks
- Property: File system operations are idempotent (save twice = save once)

#### State Machine Properties

- Property: Opening then closing mapping panel returns to previous state
- Property: Switching mappings preserves other state
- Property: Invalid mapping names are rejected consistently

### Model-Based Testing

Because the codebase uses model-based testing (src/tests/, src/models/reaper_mock.zig), we should create models for:

#### MapStore Model

- Simple in-memory representation of mappings
- Compare MapStore behavior to model behavior
- Generate random sequences of operations (save, load, delete, switch)

#### Preset Browser Model

- Simple navigation state machine
- Compare browser state to model state
- Generate random navigation sequences

### Regression Testing

After each phase, run ALL tests from previous phases to catch regressions:

- Phase 2 testing includes Phase 1 tests
- Phase 3 testing includes Phases 1-2 tests
- Phase 4 testing includes Phases 1-3 tests

### Continuous Testing

- Run `zig build test` after every code change
- Use `zig fmt` to catch formatting issues
- Build with `zig build` to catch compiler errors
- Test on actual hardware (Console1) regularly during Phase 2-4

### Test Coverage Goals

- Unit test coverage: 80%+ for core logic (MapStore, preset browser)
- Integration test coverage: All major workflows
- Manual test coverage: All UI interactions
- Regression test coverage: All previously fixed bugs

---

## Test Organization

### Test File Structure

```
src/
  mappings.zig          # Contains MapStore unit tests
  preset_browser.zig    # Contains preset browser unit tests
  tests/
    mapstore_integration_test.zig
    preset_workflow_test.zig
    mapping_panel_test.zig
```

### Test Naming Convention

- Unit tests: `test "Component - specific behavior"`
- Integration tests: `test "Workflow - end to end scenario"`
- Property tests: `test "Property: invariant description"`

### Running Tests

```bash
# Run all tests
zig build test

# Run specific test file
zig test src/mappings.zig

# Run with memory leak detection
zig build test -Doptimize=Debug

# Run with verbose output
zig build test --summary all
```

---

## Definition of Done for Each Phase

### Phase 1 Complete When:

- All unit tests pass
- All integration tests pass
- No memory leaks detected
- `zig build` succeeds
- All existing tests still pass (no regressions)
- Code is formatted with `zig fmt`

### Phase 2 Complete When:

- All Phase 1 criteria met
- All Phase 2 unit tests pass
- All Phase 2 integration tests pass
- Manual testing confirms UI works correctly
- Preset browser works on actual hardware
- Save workflow works end-to-end

### Phase 3 Complete When:

- All Phase 1-2 criteria met
- All Phase 3 tests pass
- Mapping panel no longer auto-opens
- Floating window behaves correctly
- Manual trigger works from UI and hardware

### Phase 4 Complete When:

- All Phase 1-3 criteria met
- All Phase 4 tests pass
- All bugs fixed and validated
- Error handling tested thoroughly
- UI polish complete
- All manual testing checklist items verified
