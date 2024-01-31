---This the rack's global state. It is NOT the same as the ImGui_Context
-- The rack's state is used to store global variables
---@class State
local state = {}

local r = reaper

---@class TrackFX
---@field enabled boolean
---@field guid string
---@field name string
---@field number integer
---@field param? table
---@field index integer

---@class Track
---@field last_fx TrackFX --- last touched fx
---@field fx_by_guid table<string, TrackFX> --- all fx in the track, using GUID as key. Duplicate of fx_list for easier access.
---@field fx_list TrackFX[] --- array of fx in the track. duplicate of fx_by_guid for easier iteration.
---@field fx_count integer
---@field guid string
---@field name string
---@field number integer --- 0-indexed track index (0 is for master track)
---@field track MediaTrack

---Retrieve all the necessary information about the current track.
---@return Track|nil
function state:query()
    local track = reaper.GetSelectedTrack2(0, 0, false)
    if not track then return nil end                                       -- if there's no selected track, move on
    local trackGuid                                = r.GetTrackGUID(track) -- get the track's GUID
    local _, trackName                             = reaper.GetTrackName(track)

    local trackFxCount                             = r.TrackFX_GetCount(track)
    local _,
    trackNumber, --- 0-indexed track index (0 is for master track)
    fxNumber,    --- last touched fx number
    paramNumber  --- last touched parameter number
                                                   = r.GetLastTouchedFX()
    local _, fxName                                = r.TrackFX_GetFXName(track, fxNumber)
    local _, paramName                             = r.TrackFX_GetParamName(track, fxNumber, paramNumber)
    local fxGuid                                   = r.TrackFX_GetFXGUID(track, fxNumber or 0)
    local fxEnabled                                = r.TrackFX_GetEnabled(track, fxNumber)

    return {
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
        fx_list = {},
        fx_by_guid = {}
    }
end

--- get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters,
-- and store them in the state.
function state:update()
    local state_query = self:query()
    if not self.Track and state_query then
        self.Track = state_query
    elseif self.Track and state_query then
        self.Track.track = state_query.track
        self.Track.number = state_query.number
        self.Track.name = state_query.name
        self.Track.guid = state_query.guid
        self.Track.fx_count = state_query.fx_count
        self.Track.last_fx.number = state_query.last_fx.number
        self.Track.last_fx.name = state_query.name
        self.Track.last_fx.guid = state_query.guid
        self.Track.last_fx.enabled = state_query.last_fx.enabled
        self.Track.last_fx.param.number = state_query.last_fx.param.number
        self.Track.last_fx.param.name = state_query.last_fx.param.name
    end

    return self
end

---List all fx in the current track, and store them in the state.
-- Also update the state if fx have been added, moved or deleted.
function state:getTrackFx()
    if not self.Track or not self.Track.fx_list or not self.Track.fx_count then
        return self
    end

    ---use this to update the state
    ---if fx have been added, moved or deleted
    local updated_fx_list

    ---use this to keep track of any deleted guids.
    -- When the table is instantiated, it means that there are fx that have been deleted.
    -- Remove any found guids while updating the state,
    -- and after that, remove any leftover guids from the state.
    ---@type table<string, boolean|nil>
    local guids
    --- if one of the fx has been deleted
    if self.Track.fx_count < #self.Track.fx_list then
        updated_fx_list = {}
        guids = {}
        for guid, _ in pairs(self.Track.fx_by_guid) do
            guids[guid] = true
        end
    end

    for idx = 0, self.Track.fx_count - 1 do
        local fxGuid = r.TrackFX_GetFXGUID(self.Track.track, idx)
        -- if an item has been deleted,
        -- we want to find which one it is by removing all the guids that have been found
        if guids then
            guids[fxGuid] = nil
        end
        local index = idx + 1 -- lua is 1-indexed
        local item = self.Track.fx_by_guid[fxGuid]
        local exists_in_fx_list = self.Track.fx_list[index] ~= nil and self.Track.fx_list[index].guid == fxGuid
        -- what to do if fx exists but is at the wrong index?
        -- update the table
        -- how to update the table?
        if item then
            if not exists_in_fx_list then   -- fx has been moved
                -- assign all the items after current idx into updated_fx_list
                if not updated_fx_list then -- assign all the items up to current idx into updated_fx_list
                    updated_fx_list = { table.unpack(self.Track.fx_list, 1, idx) }
                end
                item.index = index
                table.insert(updated_fx_list, item) -- assign the current fx into updated_fx_list
            end
        else                                        -- fx is new
            local _, fxName = r.TrackFX_GetFXName(self.Track.track, idx)
            local fxEnabled = r.TrackFX_GetEnabled(self.Track.track, idx)
            ---@type TrackFX
            local Fx = {
                number = idx,
                name = fxName,
                guid = fxGuid,
                enabled = fxEnabled,
                index = index
            }
            self.Track.fx_by_guid[fxGuid] = Fx
            self.Track.fx_list[index] = Fx
        end
    end

    -- find the leftover guids, which points to any deleted fx
    if guids then
        for guid, _ in pairs(guids) do
            self.Track.fx_by_guid[guid] = nil
        end
    end

    if updated_fx_list then
        self.Track.fx_list = updated_fx_list
    end
    return self
end

function state:deleteFx(idx)
    if not self.Track then
        return self
    end
    local fx = self.Track.fx_list[idx]
    if not fx then
        return self
    end
    local has_deleted = reaper.TrackFX_Delete(self.Track.track, fx.index - 1)
    if has_deleted then
        self.Track.fx_by_guid[fx.guid] = nil
        table.remove(self.Track.fx_list, idx)
    end
    return self
end

--- Initialize the state: get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters.
function state:init()
    ---@type Track|nil
    self.Track = nil
    self:update():getTrackFx()
    return self
end

return state

