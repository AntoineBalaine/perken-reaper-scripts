  -- @noindex
  
reaper.Undo_BeginBlock() -- to create a consolidated undo point in the Undo History


hwnd = reaper.MIDIEditor_GetActive() -- get active MIDI editor
-- run MIDI editor actions:
reaper.MIDIEditor_OnCommand(reaper.NamedCommandLookup("_BR_ME_CC_TO_ENV_LINEAR_CLEAR"), 0) -- Edit: Select all events

