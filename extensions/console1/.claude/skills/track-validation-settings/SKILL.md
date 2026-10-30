---
name: track-validation-settings
description: Describes the new track validation toggles to be implemented
---

# Track Validation Settings Design

## Overview

Currently, track validation in `reorderFx2()` always inserts missing modules and reorders them to a canonical order. This document outlines potential user-configurable settings to provide more control over this behavior.

Here's a schematic of the options:
```
[ ] Auto-insert missing modules on track selection
    └─ [ ] Insert new modules as bypassed

[ ] Auto-reorder modules to canonical order
    └─ Preferred order: [S-C-EQ ▼] (dropdown with 3 options)
```

## Current Behavior

When selecting a track with Console1 modules:
1. Missing modules are automatically inserted (INPUT, GATE, COMP, EQ, OUTPT)
2. Existing modules are reordered to canonical order: INPUT < GATE < COMP < EQ < OUTPT
3. All inserted modules are active (not bypassed)

## Proposed Settings

### 1. Auto-insert Missing Modules
**Type**: Boolean toggle
**Default**: `true`

Controls whether missing modules are automatically added when selecting a track.

- **Enabled**: Missing modules are inserted automatically
- **Disabled**: Only work with modules already present on the track

#### Sub-option: Insert as Bypassed
**Type**: Boolean toggle (only available when auto-insert is enabled)
**Default**: `false`

- **Enabled**: Newly inserted modules are bypassed (present but not processing audio)
- **Disabled**: Newly inserted modules are active

### 2. Auto-reorder Modules
**Type**: Boolean toggle
**Default**: `true`

Controls whether existing modules are reordered to maintain canonical order.

- **Enabled**: Modules are reordered to ensure INPUT first, GATE before COMP, OUTPT last
- **Disabled**: Modules stay in their current positions (only missing modules are inserted at default positions)

#### Sub-option: Preferred Module Order
**Type**: Dropdown (only available when auto-reorder is enabled)
**Default**: `S-C-EQ`
**Options**:
- `S-C-EQ`: GATE, COMP, EQ
- `S-EQ-C`: GATE, EQ, COMP
- `EQ-S-C`: EQ, GATE, COMP

Determines the default ordering for the middle section (EQ/GATE/COMP relationship).

## Example Configurations

### Minimal Intervention
```
[✓] Auto-insert missing modules
    [✓] Insert new modules as bypassed
[ ] Auto-reorder modules
```
**Result**: Completes missing modules in the chain. New modules do not affect audio until enabled.

### Conservative
```
[ ] Auto-insert missing modules
[ ] Auto-reorder modules
```
**Result**: Manual workflow - user must add modules themselves. System does not change existing arrangements.

### Aggressive (Current Behavior)
```
[✓] Auto-insert missing modules
    [ ] Insert new modules as bypassed
[✓] Auto-reorder modules
    Preferred order: [S-C-EQ ▼]
```
**Result**: Every track gets full Console1 chain in canonical order, modules active by default.

## Implementation Considerations

### Settings Storage
Store in `src/settings.zig` as part of `Preferences`:
```zig
pub const Preferences = struct {
    // ... existing fields ...

    auto_insert_modules: bool = true,
    auto_insert_bypassed: bool = false,
    auto_reorder_modules: bool = true,
    preferred_module_order: ModulesOrder = .@"S-C-EQ",
};
```

### Validation Logic Changes
Modify `reorderFx2()` in `src/track_state.zig`:
1. Check `auto_insert_modules` before inserting missing modules
2. Apply bypass state to newly inserted modules if `auto_insert_bypassed`
3. Check `auto_reorder_modules` before the reordering block (lines 1245-1288)
4. Use `preferred_module_order` in the reordering logic

### UI Integration
Add to settings panel (`src/settings_panel.zig`):
- Checkbox for auto-insert with indented sub-options
- Checkbox for auto-reorder with dropdown for preferred order
- Preview text showing what each configuration does

## Alternative: Manual Actions

Instead of (or in addition to) settings, provide explicit actions:
- "Setup Console1 Chain on Track" - one-time full setup
- "Complete Console1 Chain" - insert missing without reordering
- "Reorder Console1 Modules" - fix ordering without inserting

These could be MIDI-mappable or accessible via the settings mode.

## Migration Strategy

If implementing these settings:
1. Default to current behavior (aggressive mode) for existing users
2. Show settings dialog on first launch after update
3. Provide presets: "Minimal", "Conservative", "Aggressive"

## Open Questions

1. Should reordering respect user's custom module positions if they are already in a valid order (just not canonical)?
ABSOLUTELY. We should leave any valid ordering UNTOUCHED.
