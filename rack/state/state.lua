---This the rack's global state. It is NOT the same as the ImGui_Context
-- The rack's state is used to store global variables
local state = {}

local r = reaper

---@class TrackFX
---@field enabled boolean
---@field guid string
---@field name string
---@field number integer
---@field param? table

---@class Track
---@field last_fx TrackFX --- last touched fx
---@field fx_list table<string, TrackFX> --- all fx in the track, using GUID as key
---@field fx_count integer
---@field guid string
---@field name string
---@field number integer --- 0-indexed track index (0 is for master track)
---@field track MediaTrack

--- get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters,
-- and store them in the state.
function state:updateState()
    local track = reaper.GetSelectedTrack2(0, 0, false)
    if not track then return self end                                      -- if there's no selected track, move on
    local trackGuid                                = r.GetTrackGUID(track) -- get the track's GUID
    local _, trackName                             = reaper.GetTrackName(track)

    local trackFxCount                             = r.TrackFX_GetCount(track)
    local retval,
    trackNumber, --- 0-indexed track index (0 is for master track)
    fxNumber,    --- last touched fx number
    paramNumber  --- last touched parameter number
                                                   = r.GetLastTouchedFX()
    local fxNameRv, fxName                         = r.TrackFX_GetFXName(track, fxNumber)
    local paramNameRv, paramName                   = r.TrackFX_GetParamName(track, fxNumber, paramNumber)
    local fxGuid                                   = r.TrackFX_GetFXGUID(track, fxNumber or 0)
    local fxEnabled                                = r.TrackFX_GetEnabled(track, fxNumber)
    if not self.Track then
        self.Track = {
            track = track,
            number = trackNumber,
            name = trackName,
            guid = trackGuid,
            fx_count = trackFxCount,
            last_fx = {
                number = fxNumber,
                name = fxName,
                guid = fxGuid,
                enabled = fxEnabled,
                param = {
                    number = paramNumber,
                    name = paramName
                }
            },
            fx_list = {}
        }
    else
        self.Track.track = track
        self.Track.number = trackNumber
        self.Track.name = trackName
        self.Track.guid = trackGuid
        self.Track.fx_count = trackFxCount
        self.Track.last_fx.number = fxNumber
        self.Track.last_fx.name = fxName
        self.Track.last_fx.guid = fxGuid
        self.Track.last_fx.enabled = fxEnabled
        self.Track.last_fx.param.number = paramNumber
        self.Track.last_fx.param.name = paramName
    end

    return self
end

---list all fx in the current track, and store them in the state.
function state:getTrackFx()
    if not self.Track then
        return self
    end
    for idx = 0, self.Track.fx_count - 1 do
        local fxGuid = r.TrackFX_GetFXGUID(self.Track.track, idx)
        local exists = self.Track.fx_list[fxGuid] ~= nil
        if exists then
            goto continue
        else
            local _, fxName = r.TrackFX_GetFXName(self.Track.track, idx)
            local fxEnabled = r.TrackFX_GetEnabled(self.Track.track, idx)
            ---@type TrackFX
            local Fx = {
                number = idx,
                name = fxName,
                guid = fxGuid,
                enabled = fxEnabled
            }
            self.Track.fx_list[fxGuid] = Fx
        end
        ::continue::
    end
    return self
end

--- Initialize the state: get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters.
function state:init()
    ---@type Track|nil
    self.Track = nil
    self:updateState():getTrackFx()
    return self
end

return state
