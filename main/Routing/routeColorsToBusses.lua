-- @noindex
-- @description Route tracks to busses with same colours
-- @version 0.0.1
-- @author Perken
-- @about
--   # Route colours to busses
--   HOW TO USE:
--   - call action from arrange view
--
--   BEHAVIOUR:
--   - assuming all the needed busses are already in the session,
--   - route all tracks with "bus" in name to receive from other tracks with same color
-- @links
--  Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
-- @changelog
--   0.0.1 Setup the script

---get all tracks with "bus" in name
---@return MediaTrack[]
local function getTracksNamesContainBus()
  ---@type MediaTrack[]
  local busses = {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if track_name:find("bus") then
      table.insert(busses, track)
    end
  end
  return busses
end


---Route all tracks to their corresponding busses.
---In order to find the tracks that should be routed to a bus,
---the function will look for tracks with the same color as the bus.
---@param bus_tr MediaTrack
local function sendColorToMatchingBuss(bus_tr)
  local bus_color = reaper.GetMediaTrackInfo_Value(bus_tr, 'I_CUSTOMCOLOR')
  local bus_idx = reaper.GetMediaTrackInfo_Value(bus_tr, 'IP_TRACKNUMBER')
  local all_trks = reaper.CountTracks(0)
  for tr_idx = 0, all_trks - 1 do
    -- get sel_tr index
    local tr = reaper.GetTrack(0, tr_idx)
    local tr_color = reaper.GetMediaTrackInfo_Value(tr, 'I_CUSTOMCOLOR')   -- find color
    local tr_nmbr = reaper.GetMediaTrackInfo_Value(tr, 'IP_TRACKNUMBER')
    local parent = reaper.GetParentTrack(tr)                               -- find if has parent
    if parent == nil and tr_color == bus_color and tr_nmbr ~= bus_idx then -- if is not a child track, and has same color
      reaper.CreateTrackSend(tr, bus_tr)                                   -- route tr to sel_tr
      reaper.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)                  -- remove master send
    end
  end
end

---assuming all the needed busses are already in the session,
---route all tracks with "bus" in name to receive from other tracks with same color
local function routeTracksToBusses()
  local busses = getTracksNamesContainBus()
  for _, bus_tr in ipairs(busses) do
    sendColorToMatchingBuss(bus_tr)
  end
end

routeTracksToBusses()
