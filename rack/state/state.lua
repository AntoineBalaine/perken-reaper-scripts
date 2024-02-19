--[[
App-wide state. The rack's state contains a description of the currently selected track, as well as a table of track fx - their internal states and their layouts.

The state gets updated at every defer cycle:
At the beginning of the cycle, the state module queries the reaper api to find out
- what’s the currently-selected track
- what FX it has, have the FX changed (any deletions/additions) and do we need to update any of the data.

Tests for this module can be found in `spec/state_spec.lua`

TODO
- Q: what if there are multiple tracks selected?
- when selected track changes, should we store the previously-selected track’s data, so we can re-use it later?
]]
local fx_state = require("state.fx")

---This the rack's global state. It is NOT the same as the ImGui_Context
-- The rack's state is used to store global variables
---@class State
local state = {}

---This is the barebones trackFx info,
---Without the class functions that can be found in
---@see TrackFX
--This type is used for testing and for passing data when instantiating `TrackFX`
---@class FxData
---@field enabled boolean
---@field guid string
---@field name string
---@field number integer
---@field param? table
---@field index integer

---@class Track
---@field fx_by_guid table<string, TrackFX> --- all fx in the track, using GUID as key. Duplicate of fx_list for easier access.
---@field fx_list TrackFX[] --- array of fx in the track. duplicate of fx_by_guid for easier iteration.
---@field fx_count integer
---@field guid string
---@field name string
---@field number integer --- 0-indexed track index (0 is for master track)
---@field track MediaTrack

--- get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters,
-- and store them in the state.
function state:update()
    local track = reaper.GetSelectedTrack2(0, 0, false)
    if not track then
        self.Track = nil
        return self
    end -- if there's no selected track, move on
    ---TODO do we really need to re-query the details at every frame ?
    ---how likely to change are things such as `trackGuid`
    local trackGuid    = reaper.GetTrackGUID(track) -- get the track's GUID
    local _, trackName = reaper.GetTrackName(track)

    local trackFxCount = reaper.TrackFX_GetCount(track)
    local trackNumber  = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

    if not self.Track and track then
        self.Track = {
            track = track,
            number = trackNumber or -1,
            name = trackName,
            guid = trackGuid,
            fx_count = trackFxCount,
            fx_list = {},
            fx_by_guid = {}
        }
    elseif self.Track and track then
        self.Track.track = track
        self.Track.number = trackNumber or -1
        self.Track.name = trackName
        ---TODO: would it be worth saving any previous track’s state into a «other_tracks» table?
        ---That way we wouldn’t have to re-allocate a table every time the track changes.
        if self.Track.guid ~= trackGuid then
            for i in ipairs(self.Track.fx_list) do
                self.Track.fx_by_guid[self.Track.fx_list[i].guid] = nil
                self.Track.fx_list[i] = nil
            end
        end
        self.Track.guid = trackGuid
        self.Track.fx_count = trackFxCount
    else
        self.Track = nil
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
        guids = {}
        for guid, _ in pairs(self.Track.fx_by_guid) do
            guids[guid] = true
        end
    end

    for idx = 0, self.Track.fx_count - 1 do
        local fxGuid = reaper.TrackFX_GetFXGUID(self.Track.track, idx)
        -- if an item has been deleted,
        -- we want to find which one it is by removing all the guids that have been found
        if guids then
            guids[fxGuid] = nil
        end
        local index = idx + 1 -- lua is 1-indexed
        local item = self.Track.fx_by_guid[fxGuid]
        local exists_in_fx_list = self.Track.fx_list[index] ~= nil and self.Track.fx_list[index].guid == fxGuid
        if item and item.index ~= index then
            item.index = index
        end
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
            elseif updated_fx_list then
                table.insert(updated_fx_list, item) -- assign the current fx into updated_fx_list
            end
        else                                        -- fx is new
            local _, fxName = reaper.TrackFX_GetFXName(self.Track.track, idx)
            local fxEnabled = reaper.TrackFX_GetEnabled(self.Track.track, idx)
            ---@type FxData
            local Fx = {
                number = idx,
                name = fxName or "",
                guid = fxGuid,
                enabled = fxEnabled,
                index = index
            }

            local my_fx = fx_state.new(self, Fx, self.theme)
            self.Track.fx_by_guid[fxGuid] = my_fx
            self.Track.fx_list[index] = my_fx
        end
    end

    -- find the leftover guids, which points to any deleted fx
    if guids then
        for guid, _ in pairs(guids) do
            local deleted_fx = self.Track.fx_by_guid[guid]
            self.Track.fx_list[deleted_fx.index] = nil
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
        self.Track.fx_count = self.Track.fx_count - 1
        --- update all indexes in the fx_list
        for idx, fx in ipairs(self.Track.fx_list) do
            fx.index = idx
        end
    end
    return self
end

--- Initialize the state: get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters.
---@param project_directory string
---@param theme Theme
function state:init(project_directory, theme)
    self.project_directory = project_directory
    self.theme = theme
    ---@type Track|nil
    self.Track = nil
    self:update():getTrackFx()
    return self
end

return state
