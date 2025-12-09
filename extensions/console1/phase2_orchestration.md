# Phase 2 Implementation Orchestration

This document tracks the automated multi-agent orchestration for implementing phase2_revised.plan.md.

## Orchestration Strategy

### Context Gathering Phase
**Agent:** context-gathering
**Task file:** phase2_revised.plan.md
**Output:** Context Manifest section added to task file
**Checkpoint:** User approval after context gathering completes

### Implementation Steps (0-10)

For each step, we follow this loop:
1. Invoke implementation agent with step-specific requirements
2. Invoke code-review agent on modified files
3. If review fails: re-invoke implementation agent with fixes
4. Run `zig build` to verify compilation
5. Checkpoint with user before proceeding to next step

---

## Step 0: Remove Obsolete Files and Modes

**Implementation Agent:**
- Model: haiku (straightforward deletions)
- Task: Remove obsolete files and mode references
- Files to remove:
  - src/preset_browser_panel.zig
  - src/preset_browser_actions.zig
  - src/tests/preset_browser_tests.zig
- Files to modify:
  - src/statemachine.zig (remove preset_browser and midi_learn modes)
  - Search and remove references in: src/actions.zig, src/csurf/midi_events.zig, src/gui_lib.zig

**Code Review Agent:**
- Focus: Verify all references removed, no dangling imports
- Files: All modified files from implementation

---

## Step 1: Refactor State Machine

**Implementation Agent:**
- Model: sonnet
- Task: Add hierarchical state machine structure
- Requirements: Lines 87-127 of phase2_revised.plan.md
- Files to modify: src/statemachine.zig
- Add: MappingPanelMode enum, MappingPanelState struct with BrowseState, AssignState, SaveState

**Code Review Agent:**
- Focus: State structure correctness, nested struct definitions match spec
- Files: src/statemachine.zig

---

## Step 2: Update Actions

**Implementation Agent:**
- Model: sonnet
- Task: Implement action hierarchy and dispatch flow
- Requirements: Lines 177-272 of phase2_revised.plan.md
- Files to modify:
  - src/actions.zig
  - src/mapping_panel_actions.zig (create or consolidate)
- Add: MappingPanelAction union, dispatch handlers for sub-mode transitions

**Code Review Agent:**
- Focus: Action completeness, dispatch flow correctness, all transitions handled
- Files: src/actions.zig, src/mapping_panel_actions.zig

---

## Step 3: Implement Stateful Tests

**Implementation Agent:**
- Model: sonnet
- Task: Implement zlowcheck model-based stateful tests
- Requirements: Lines 274-354 of phase2_revised.plan.md
- Skill: zlowcheck-stateful
- Files to create: src/tests/mapping_panel_stateful_test.zig
- Define: Test model (mode, track, browser, edit states), commands mirroring actions, properties

**Code Review Agent:**
- Focus: Test coverage completeness, command preconditions, model synchronization
- Files: src/tests/mapping_panel_stateful_test.zig
- Run: `zig build test` to verify tests compile and pass

---

## Step 4: Create Module Selection Panel

**Implementation Agent:**
- Model: sonnet
- Task: Create new module selection panel as pure function
- Requirements: Lines 360-394 of phase2_revised.plan.md
- Files to create: src/module_selection_panel.zig
- Signature: drawModuleSelectionPanel(ctx, state, track_state, style_manager, translations) -> ?MappingPanelAction
- Display: All 5 modules with FX names, scrollable, highlight selected

**Code Review Agent:**
- Focus: Pure function pattern, no state mutation, returns correct actions
- Files: src/module_selection_panel.zig

---

## Step 5: Refactor Mapping Panel

**Implementation Agent:**
- Model: sonnet
- Task: Refactor mapping panel to pure function
- Requirements: Lines 396-424 of phase2_revised.plan.md
- Files to modify: src/mapping_panel.zig
- Changes: Remove struct method, convert to pure function, remove auto-open, add Save/Cancel buttons

**Code Review Agent:**
- Focus: Pure function pattern, no auto-open behavior, correct action returns
- Files: src/mapping_panel.zig

---

## Step 6: Refactor Save Preset Dialog

**Implementation Agent:**
- Model: sonnet
- Task: Refactor save dialog to pure function
- Requirements: Lines 426-455 of phase2_revised.plan.md
- Files to modify: src/save_preset_dialog.zig, src/statemachine.zig
- Changes: Move state to SaveState, convert to pure function, keep UI layout

**Code Review Agent:**
- Focus: Pure function pattern, state moved to state machine, no struct methods
- Files: src/save_preset_dialog.zig

---

## Step 7: Implement Window Consolidation

**Implementation Agent:**
- Model: sonnet
- Task: Create unified window that switches between sub-panels
- Requirements: Lines 457-489 of phase2_revised.plan.md
- Files to create: src/mapping_panel_window.zig
- Main function: drawMappingPanelWindow() that dispatches based on sub_mode

**Code Review Agent:**
- Focus: Window reuse pattern, correct sub-mode dispatching, styling consistency
- Files: src/mapping_panel_window.zig

---

## Step 8: Update MIDI Handlers

**Implementation Agent:**
- Model: sonnet
- Task: Add sub-mode-specific MIDI button mappings
- Requirements: Lines 627-638 of phase2_revised.plan.md
- Files to modify: src/csurf/midi_events.zig
- Add: PRESET button handler, sub-mode-specific encoder/button routing

**Code Review Agent:**
- Focus: Button mappings correct for each sub-mode, encoder routing
- Files: src/csurf/midi_events.zig

---

## Step 9: Integrate into Main GUI Loop

**Implementation Agent:**
- Model: sonnet
- Task: Integrate mapping panel window into main rendering loop
- Requirements: Lines 640-650 of phase2_revised.plan.md
- Files to modify: src/gui_lib.zig
- Add: mapping_panel mode rendering, call drawMappingPanelWindow(), handle actions

**Code Review Agent:**
- Focus: Correct mode rendering, action handling, no rendering leaks
- Files: src/gui_lib.zig

---

## Step 10: Update Integration Tests

**Implementation Agent:**
- Model: haiku
- Task: Update or remove obsolete integration tests
- Requirements: Lines 652-662 of phase2_revised.plan.md
- Files to modify: src/tests/mappings_integration_tests.zig
- Files to verify removed: src/tests/preset_browser_tests.zig (already removed in Step 0)

**Code Review Agent:**
- Focus: Test coverage, no obsolete test references
- Files: src/tests/mappings_integration_tests.zig

---

## Checkpoints

After each step completes and passes review:
1. Run `zig build` to verify compilation
2. Report status to user
3. Get approval to proceed to next step

If review fails multiple times (>2):
1. Report issue to user
2. Get guidance on how to proceed
