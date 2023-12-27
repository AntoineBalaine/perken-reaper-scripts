local utils = require("custom_actions.utils")
local fx = {}
---@param slot integer | nil
---@param dummy_track MediaTrack
---@param selected_tracks MediaTrack[]
---@return integer
local function wait_until_has_added_fx(slot, dummy_track, selected_tracks)
  if slot ~= nil then
    local choose_slot = string.match(reaper.Undo_CanUndo2(0), "Add FX: [%w:]+ %w+")
    if choose_slot then
      local choose_slot2 = math.tointeger(string.match(choose_slot, "%d+"))
      local undo_fx_name = string.match(reaper.Undo_CanUndo2(0), "Track [%w:]+.+")
      local undo_fx_name = string.sub(string.match(undo_fx_name, ":.+"), 3)
      if not choose_slot2 then
        local choose_slot2 = string.match(choose_slot, "Master")
        if choose_slot2 == "Master" then
          undo_fx_name = string.match(reaper.Undo_CanUndo2(0), "Master[%w:]+.+")
          undo_fx_name = string.sub(string.match(undo_fx_name, ":.+"), 3)
          local choose_slot2 = -1
        end
      end
      local sel_tr_n = math.tointeger(reaper.GetMediaTrackInfo_Value(dummy_track, 'IP_TRACKNUMBER'))
      local fx_count = reaper.TrackFX_GetCount(dummy_track)
      local fx_name_ok, fx_name = reaper.TrackFX_GetFXName(dummy_track, fx_count - 1)
      if sel_tr_n and sel_tr_n == choose_slot2 and string.match(fx_name, undo_fx_name) then
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS5"), 0) -- close fx chain window for selected track
        for i, track in ipairs(selected_tracks) do
          reaper.TrackFX_CopyToTrack(dummy_track, fx_count - 1, track, slot, false)
        end
        -- check if dummy track has fx chain
        -- reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_COPYFXCHAIN5"), 0)               -- copy selected track’s fx chain
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTORESEL"), 0) -- restore track selection
        -- reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_PASTE_TRACKFXCHAIN" .. slot), 0) -- paste fx chain to selected track ]]
        reaper.DeleteTrack(dummy_track)                                        -- delete dummy track
        return 0
      end
    end
  end
  reaper.defer(function() wait_until_has_added_fx(slot, dummy_track, selected_tracks) end)
end

function fx.insertFXAtSlot()
  -- prompt user in reaper for a slot number
  local ok, retval = reaper.GetUserInputs("insert fx at slot", 1, "which slot should this fx be inserted in", "")
  if not ok then return end

  local slot = math.tointeger(retval)
  if not slot then return end
  --get selected tracks
  local selected_tracks = utils.getSelectedTracks()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVESEL"), 0) -- save current track selection
  reaper.InsertTrackAtIndex(0, false)                                 -- insert a dummy track
  reaper.SetOnlyTrackSelected(reaper.GetTrack(0, 0))                  -- select dummy track
  local dummy_track = reaper.GetSelectedTrack(0, 0)                   -- focus dummy track
  reaper.Main_OnCommand(40271, 0)                                     -- open fx browser

  wait_until_has_added_fx(slot, dummy_track, selected_tracks)
end

return fx
