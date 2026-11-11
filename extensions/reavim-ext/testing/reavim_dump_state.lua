-- External state probe: writes REAPER API values to /tmp/reaper-state.txt.
-- Trigger by action (command id) and read the file from the shell.
local f = io.open("/tmp/reaper-state.txt", "w")
f:write(string.format("cursor=%.6f\n", reaper.GetCursorPosition()))
f:write(string.format("tracks=%d\n", reaper.CountTracks(0)))
f:write(string.format("sel_tracks=%d\n", reaper.CountSelectedTracks(0)))
for ti = 0, reaper.CountTracks(0) - 1 do
  local tr = reaper.GetTrack(0, ti)
  local sel = reaper.GetMediaTrackInfo_Value(tr, "I_SELECTED")
  local nitems = reaper.CountTrackMediaItems(tr)
  f:write(string.format("track[%d] sel=%d items=%d\n", ti, sel, nitems))
  for ii = 0, nitems - 1 do
    local it = reaper.GetTrackMediaItem(tr, ii)
    local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
    f:write(string.format("  item[%d] pos=%.3f len=%.3f\n", ii, pos, len))
  end
end
f:close()
