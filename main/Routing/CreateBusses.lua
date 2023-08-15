-- @noindex
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

Busses = {
  "BA",
  "BGV",
  "BR",
  "Choir",
  "DR",
  "FX",
  "FullMix",
  "GTR",
  "Keys",
  "LD",
  "PD",
  "PL",
  "PNO",
  "PRC ",
  "STR",
  "TXT",
  "WD",
}


---Create busses with all common prefixes found in "Busses" list.
---
---Then route all tracks to their corresponding busses, using matching colors.
---
---Remove any unused busses.
---Common Prefixes are:
---"BA",
---"BGV",
---"BR",
---"Choir",
---"DR",
---"FX",
---"FullMix",
---"GTR",
---"Keys",
---"LD",
---"PD",
---"PL",
---"PNO",
---"PRC ",
---"STR",
---"TXT",
---"WD",
local function buildBusses()
  -- insert busses from Busses list
  for _, bus_name in ipairs(Busses) do
    reaper.InsertTrackAtIndex(0, true)                                         -- insert track
    local bus_tr = reaper.GetTrack(0, 0)                                       -- get track
    reaper.GetSetMediaTrackInfo_String(bus_tr, "P_NAME", bus_name, true)       -- rename to bus_name
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWSAUTOCOLOR_APPLY"), 0) -- apply auto-color
    sendColorToMatchingBuss(bus_tr)                                            -- send all matching colored-tracks to bus
    -- if bus_tr gets not receives, then remove it
    local num_sends = reaper.GetTrackNumSends(bus_tr, -1)                      -- count receives
    if num_sends == 0 then                                                     -- if no receives
      reaper.DeleteTrack(bus_tr)                                               -- remove track
    end
  end
end

buildBusses()
