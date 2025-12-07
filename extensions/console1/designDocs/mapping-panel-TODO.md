# Mapping Panel TODO

This document tracks all remaining work for the mapping panel feature, including design decisions that need clarification before implementation.

## 🔴 CRITICAL BUGS

- [ ] **+ Button Crashes REAPER** (src/ButtonsBar.zig:71)
  - The manual mapping panel trigger button causes crashes
  - Need to investigate what is causing the crash
  - May need to remove this debug/testing entry point

## 🤔 DESIGN DECISIONS NEEDED

These items require discussion and design before implementation can proceed.

### 1. Multiple Mappings Per FX

**Current state:** One mapping per FX per module (e.g., one INPUT mapping for ReaComp)

**Question:** Should we support multiple named mappings per FX?
  - Example: User could have "Aggressive" and "Gentle" mappings for the same compressor
  - This would require UI for selecting which mapping to use when adding an FX
  - This would change folder structure from `maps/COMP/VST: ReaComp.ini` to `maps/COMP/VST: ReaComp/default.ini`, `maps/COMP/VST: ReaComp/aggressive.ini`, etc.

**Implications:**
  - [ ] Decide on folder structure: `maps/<module>/<fx_name>/<mapping_name>.ini` vs current `maps/<module>/<fx_name>.ini`
  - [ ] If yes to multiple mappings: need UI to select which mapping when adding FX
  - [ ] If yes to multiple mappings: need UI to manage (rename, delete, set default) mappings
  - [ ] Clarify relationship between "mappings" (parameter assignments) and "presets" (parameter values)

### 2. Folder Structure Confusion

**Current state:** We have both `<config>/maps/` and `<config>/resources/maps/`

**Question:** Which folder is the canonical location?
  - `resources/` appears to be for shipped defaults
  - `maps/` appears to be for user-created mappings
  - Need to clarify and document this distinction
  - Should we merge them or keep them separate?

**Tasks:**
  - [ ] Document the purpose of each directory
  - [ ] Verify loading order (user maps override shipped maps?)
  - [ ] Consider renaming for clarity if needed

### 3. Preset System Architecture

**Current state:** No preset system exists yet

**Proposal:** Support saving/loading both individual module settings and entire channel strips

**Questions to resolve:**
  - How do presets relate to mappings?
    - Mappings = which parameter goes to which control (e.g., "Threshold → Comp_Thresh")
    - Presets = actual parameter values (e.g., "Threshold = -12dB")
  - Should presets be per-FX or per-module?
  - Should channel stripw presets include which FX are assigned to each module?
  - Where should preset files be stored?

**UI Design needed:**
  - [ ] Design save/load windows (see mockup below)
  - [ ] Determine Console1 button mappings for preset operations
  - [ ] Decide on preset browser UI (similar to FX browser?)

**Mockup:**
```
Load/Save preset windows:

┌───────────────────────────┐         ┌───────────────────────────┐
│Load preset          Xbtn  │         │Save preset          Xbtn  │
│                           │         │                           │
│input                 tr1  │         │input                 tr1  │ ◄── Selectable lines
│output                tr2  │         │output                tr2  │     like in fx selector
│shape                 tr3  │         │shape                 tr3  │
│eq                    tr4  │         │eq                    tr4  │     Also clickable
│comp                  tr5  │         │comp                  tr5  │     like track list
│channel strip         tr6  │         │channel strip         tr6  │
│                           │         │                           │
│    Select    Cancel       │         │     Save     Cancel       │
└───────────────────────────┘         └───────────────────────────┘
```

**Console1 integration:**
  - Preset button behavior:
    - Normal mode: load preset
    - Alternate view (Mode button pressed): save preset
  - Need to design menu navigation with Console1 controls

### 4. How Users Create/Edit Mappings

**Current workflow:** Automatic only - mapping panel opens when selecting unmapped FX

**Questions:**
  - [ ] Should users be able to manually edit existing mappings?
  - [ ] Should users be able to create mappings without adding an FX to a track?
  - [ ] How do users switch between multiple mappings (if we support that)?
  - [ ] Should there be a "duplicate mapping" feature?

**Possible triggers to add:**
  - [ ] Right-click menu on FX in track state?
  - [ ] Button in settings panel to manage mappings?
  - [ ] "Edit mapping" option when an FX is already assigned?

## 📋 IMPLEMENTATION TASKS

These can be implemented once design decisions are made.

### Core Missing Features

- [ ] **MIDI Learn Implementation** (HIGH PRIORITY)
  - [ ] Add mapping_panel case to OnMidiEvent (src/csurf/midi_events.zig:138)
  - [ ] When midi_learn_active and selected_parameter are set:
    - Detect incoming CC message
    - Determine which Console1 control it corresponds to
    - Call add_mapping action automatically
    - Exit MIDI learn mode
    - Show visual feedback on successful mapping
  - [ ] Add visual feedback when MIDI learn is active (flash LEDs?)

- [ ] **Parameter List Display** (MEDIUM PRIORITY)
  - [ ] Integrate params() function into mappingPanel layout (src/mapping_panel.zig:73)
  - [ ] Create two-column layout: controls on left, parameters list on right
  - [ ] Make parameter list scrollable
  - [ ] Show "(Mapped)" indicator for assigned parameters
  - [ ] Implement parameter selection from list

### Polish & UX Improvements

- [ ] **State Management Cleanup**
  - [ ] Fix commented-out cleanup code in cancel_mapping (src/mapping_actions.zig:218)
  - [ ] Ensure proper memory deallocation when canceling
  - [ ] Add validation that mapping_panel exists before accessing it

- [ ] **Visual Feedback**
  - [ ] Highlight selected parameter in list
  - [ ] Highlight selected control in control panel
  - [ ] Show connection animation when mapping is created
  - [ ] Better "mapped" indicators

- [ ] **Error Handling**
  - [ ] Handle case where FX parameters change while mapping panel is open
  - [ ] Handle case where FX is removed while mapping panel is open
  - [ ] Validate mappings before saving (no duplicate assignments?)

- [ ] **Help & Documentation**
  - [ ] Add tooltips explaining MIDI learn workflow
  - [ ] Add help text in mapping panel UI
  - [ ] Document mapping file format
  - [ ] Create user guide for creating custom mappings

### Testing

- [ ] Test MIDI learn with various FX plugins
- [ ] Test mapping panel with FX that have many parameters (>100)
- [ ] Test mapping panel with FX that have few parameters (<5)
- [ ] Test save/cancel workflows
- [ ] Test module switching within mapping panel
- [ ] Test that mappings persist across REAPER restarts
- [ ] Test that mappings work correctly in FX control mode

## 📝 NOTES

### Original Design Intent

Per .claude/skills/mapping-panel-mode/SKILL.md:
- "The mapping panel mode is entered automatically when a user selects an FX plugin that does not have predefined parameter mappings"
- This is fully implemented and working
- Users do not need to manually open mapping panel for new FX

### Current File Structure

```
<config>/
├── maps/                          # User-created mappings (?)
│   ├── COMP/
│   │   └── VST: ReaComp (Cockos).ini
│   └── ...
└── resources/
    ├── maps/                      # Shipped default mappings (?)
    │   ├── COMP/
    │   │   └── VST: ReaComp (Cockos).ini
    │   └── ...
    └── ...
```

**Question:** Which is deprecated? Need to clarify.

### If Supporting Multiple Mappings Per FX

Proposed structure:
```
<config>/maps/<module>/<fx_name>/<mapping_name>.ini

Example:
maps/COMP/VST: ReaComp (Cockos)/default.ini
maps/COMP/VST: ReaComp (Cockos)/aggressive.ini
maps/COMP/VST: ReaComp (Cockos)/gentle.ini
```

This requires:
- Changes to MapStore loading/saving logic
- UI for selecting mapping when adding FX
- UI for managing mappings (rename, delete, set default)
- File path handling updates throughout codebase

## 🎯 RECOMMENDED NEXT STEPS

1. **Clarify design decisions** - Discuss and decide on:
   - Multiple mappings per FX (yes/no)
   - Folder structure cleanup
   - Preset system scope and architecture

2. **Fix critical bug** - Investigate and fix the + button crash

3. **Implement MIDI learn** - This is the biggest missing piece for usability

4. **Add parameter list display** - Makes mapping creation much easier

5. **Consider preset system** - This may be a separate feature ticket


# 1. multi maping per fx.

- yes, change folder structure to : `maps/<module>/<fx_name>/<mapping_name>.ini` vs current `maps/<module>/<fx_name>.ini`.
- mappings are the same as presets. C1 legacy app uses «preset» terminology, we use «mappings.»

# 2. Folder Structure Confusion
  - `resources/` appears to be for shipped defaults
  - `maps/` appears to be for user-created mappings

-> your task is to find the answer to that question by reading the code. Which of the two locations is being read?


# 3. Preset System Architecture
- How do presets relate to mappings? they’re the same.
  A preset is a _mapping preset file_. they can exist for a specifc FX or for a channel strip. The app currently only allows 1 mapping preset file per fx. 

About what the channel strip presets files should include:
  - Yes, channel strip presets should include which FX are assigned to each module. 

  - they should probably include ALL the mappings from the individual modules in some way: either by indicating the mapping files’ paths of the individual modules, or by embedding their contents directly. So far, I’m most favorable to the former, because it is most compatible with our setup: it’s stateless, and thus avoids any possible data corruption issues between reaper session restarts.
  - if we include mappings paths in the strip preset file, then we need to have some protection against missing files: we shouldn’t let the app crash by trying to load non-existent files on disk. 
  - There is also the case in which _multiple_ mapping files might be missing on disk upon trying to load a channel strip. In this case, the UI can’t just load up the mapping panel automatically - this behaviour was initially conceived for dealing with a single missing module at a time. This implies that the original behaviour needs to be modified: instead of automatically opening the panel when we can’t find a mapping, we should first indicate it to the user, and let the user decide when he was to press the «save preset» button to open the mapping panel.



- Should presets be per-FX or per-module?  A mapping preset file must be per module. There’s no module that can be represented by multiple FX.  For now also, it’s not possible to represent multiple modules with a single FX.
- preset files are stored in the data folder path that we retrieve from reaper at startup.

- UI design is needed, but not only: we should also be designing the interaction between the console input and the UI when the user is trying to do something, as well as the midi learn mode. 



# 4. How Users Create/Edit Mappings
As discussed previously, I think it is reasonable to drop the behaviour in which we automatically open the mapping panel upon the user selecting an FX that doesn’t have a corresponding mapping.

- Should users be able to manually edit existing mappings? 
  YES.
- Should users be able to create mappings without adding an FX to a track?
  NO. The FX has to be present on the track for the extension to call the reaper API and query the list of available FX params.
- How do users switch between multiple mappings (if we support that)?
  Using the UI «load preset» feature. 
- Should there be a "duplicate mapping" feature?
  Not very important: the way that I see it, the user can do «save preset», selects for which module he wants to create, it loads the current module mapping, the user can tweak, then hit save, and then can decide whether he wants to replace a pre-existing mapping by re-using the mapping’s file name.

This also means that at some point, the user is going to want to be testing the mappings while tweaking them. This means that the mapping panel should be in a floating window, and the main docked window should still be displaying the fx_ctrl mode window.


So, there’s a fair amount of detail here to be ironed out:
- in which order do we need to be addressing implementations?
- what are the overall epics, tasks and sub-tasks that we need to be addressing?
- below these tasks and sub-tasks, are there any changes that need to be made to the data structures that power the app?

