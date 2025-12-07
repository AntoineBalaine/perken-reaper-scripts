# FEATURES
- mapping panel
- single fx mode - would allow for more flexibility.
- save preset?
- display extended controls in GUI (user’s in the blind about features)
- implement backwards compat’ for mapping versions
# BUGS
- jog grid lines
- meters
- csurf’s update_param_value() is too slow, switch to `CC.toModule()`
- add check for existence of imgui on user’s system
# ARCH
- [x] Error handling: file reading, allocations
- Handle case of imgui missing on user’s system.
- [x] use `.empty` for empty data structures by default
# Default fx mode: Channel Strip Panel
  * Open from settings menu
    Add a default channel strip mode. Settings can transition to it, and it can only transition back to it.
    When open, it's assigned to a ModuleList, similar to the fx_sel mode.
    Buttons track 1 through track 5 can open it.
  * FX selection interface
    Modify (again) the fx_browser so that it returns the fx selection
    the fx_sel_panel should be re-used by the default fx for selecting a default fx.
    Update the UI from settings menu: default fX should have a circled numbered button that shows which track btns to click to open the panel.
  * Order configuration
    should be selectable from the settings menu

# Optionnels
- jog items: remove sws dependency
- Traductions à revoir
- Manuel utilisateur
- Skins/Themes?
- utility actions:
  - insert default c1 chain on all tracks
  - swap INPT/SHP/EQ/CMP/OUTPT module on all tracks
  - set INPT/SHP/EQ/CMP/OUTPT default module to... (selection screen)
  - set all default fx to none
  - Hide GUI
  - Insert by default or wait until input?
  - Unlink all FX (remove all suffixes)
  - Unlink fx on selected track
