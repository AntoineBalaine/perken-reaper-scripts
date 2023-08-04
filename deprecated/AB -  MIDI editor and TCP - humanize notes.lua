  -- @noindex
  

reaper.Undo_BeginBlock() -- to create a consolidated undo point in the Undo History

-- run Main window actions:
reaper.Main_OnCommand(reaper.NamedCommandLookup("_ BR_SAVE_CURSOR_POS_SLOT_1"), 0) -- SWS/BR: Save edit cursor position, slot 01

reaper.Main_OnCommand(40153, 0) -- Item: Open in built-in MIDI editor

hwnd = reaper.MIDIEditor_GetActive() -- get active MIDI editor
-- run MIDI editor actions:
reaper.MIDIEditor_OnCommand(hwnd, 40006) -- Edit: Select all events
reaper.MIDIEditor_OnCommand(hwnd, 40457) -- Humanize notes
reaper.MIDIEditor_OnCommand(hwnd, 40477) -- File: Close window or change focus if docked

-- run Main window actions:
reaper.Main_OnCommand(reaper.NamedCommandLookup("_ BR_RESTORE_CURSOR_POS_SLOT_1"), 0) -- SWS/BR: Restore edit cursor position, slot 01

reaper.Undo_EndBlock("Script: Glue Items and Join Notes", -1 )

