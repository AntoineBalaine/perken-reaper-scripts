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

--[[
 * ReaScript Name: Rename tracks with first VSTi preset name
 * Description: A way to quickly rename and recolor tracks in a REAPER project from its instrument.
 * Instructions: Select tracks. Run.
 * Screenshot: http://i.giphy.com/l41lMgnQVFZp2qfjW.gif
 * Author: X-Raym
 * Author URI: http://extremraym.com
 * Repository: GitHub > X-Raym > EEL Scripts for Cockos REAPER
 * Repository URI: https://github.com/X-Raym/REAPER-EEL-Scripts
 * File URI:
 * Licence: GPL v3
 * Forum Thread: Video & Sound Editors Will Really Like This
 * Forum Thread URI: http://forum.cockos.com/showthread.php?p=1539710
 * Extensions: None
 * Version: 1.0
--]]
function tracks.renameTrackToVstiPresetName()
  utils.cycleSelectedTracks(
    function(track)
      local vsti_id = reaper.TrackFX_GetInstrument(track)

      if vsti_id >= 0 then
        local retval, fx_name = reaper.TrackFX_GetFXName(track, vsti_id)

        fx_name = fx_name:gsub("VSTi: ", "")

        fx_name = fx_name:gsub(" %(.-%)", "")

        local retval, presetname = reaper.TrackFX_GetPreset(track, vsti_id)

        if retval == 0 then
          local track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", fx_name, true)
        else
          local track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", presetname, true)
        end
      end
    end
  )
end

return tracks
