-- Select track 0 and park the edit cursor at project start.
local tr = reaper.GetTrack(0, 0)
if tr then reaper.SetOnlyTrackSelected(tr) end
reaper.SetEditCurPos(0, false, false)
reaper.UpdateArrange()
