local utils = require("custom_actions.utils")
local tracks = {}


reaper = reaper
---@param track MediaTrack
---@param db number
local function nudgeTrackVolumeAmount(track, db)
  local tr_vol = reaper.GetMediaTrackInfo_Value(track, 'D_VOL')
  reaper.SetMediaTrackInfo_Value(track, 'D_VOL', tr_vol * 10 ^ (0.05 * db))
  -- reaper.UpdateItemInProject(track)
end

function tracks.trackVolumeDown3()
  utils.cycleSelectedTracks(
    function(track)
      nudgeTrackVolumeAmount(track, -3)
    end
  )
end

function tracks.trackVolumeUp3()
  utils.cycleSelectedTracks(
    function(track)
      nudgeTrackVolumeAmount(track, 3)
    end
  )
end

return tracks
