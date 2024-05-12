--[[
run a background script that will retrieve external state changes.
state has to check that we're still on the same track.
De-map the current track:
    remove any midi links between realearn params and the current track's channel strip.
Upon new track,
    check whether the channel strip's already loaded.
    If not, load the default channel strip.
    Retrieve the values of controlled params of the channel strip.
    Set the realearn params to match them,
    and link the realearn params to the channel strip.
]]

local state_interface = require("state_machine.state_interface")
local constants = require("state_machine.constants")
local loader = require("state.ControllerConfigLoader")
-- hard for the default controller to be console 1, for now.
--[[
    Would be good to include the mechanic for handling multiple controllers in the future
    Setup could be:
        perken_controller.lua: on input,
            push to dedicated controller command stack,
        On controller state start:
            store the controllers' state in its own table and run it.
    This implies that states aren't singletons: there should be one per controller,
        each controlling its own UI and querying its own
    This also implies that perken_controller is meant to control elements on a per-track basis.
        We'll have to see how feasible it is to have global settings.
    Since this is a little out of the scope of the Console1 POC,
    I'll keep everything setup for a single controller for now.
]]
local controller = constants.ControllerId.Console1
local config = loader.load(controller)

---@class State
local state = {}


---TODO
--- retrieve external state changes.
--- run any actions that are stored in the external state.
--- this is the hook to the state machine
function state:queryExtStateActions()
    error("not implemented")

    local state = state_interface.get(controller)
    -- state.btn_sequence
    -- get the newly pressed button from the ext state
    --
end

--- remove any midi links between realearn params and the current track's channel strip.
function state:DeMapTrack()
    if self.Track then
        error("not implemented")
        for _, fx in ipairs(self.Track.fx_list) do
            -- REMOVE mappings from realearn
        end
    end
end

--- if the channel strip's not loaded, load the default channel strip
function state:loadChannelStrip()
    error("not implemented")
    if not self:getTrackFx() then
        --[[
            Read from current config:
            - the .rfx chain that is to be appended to the track
            - the params mappings that are to be used
           Append the chain to the track
           Create the fx instances for the track
           and query the fx params that need to be controlled
        ]]
        local path = config.rfxChain
        -- reaper load fx chain
        -- TODO find in rack's FX browser where this functionality is
        --Get current directory's ptah

        local info = debug.getinfo(1, "S")
        local Os_separator = package.config:sub(1, 1)
        local source = table.concat({ info.source:match(".*PrknController" .. Os_separator) })
        local internal_root_path = source:sub(2)
        local extension = "rfxChain"
        package.path = package.path .. ";" .. internal_root_path .. "?.lua"
        local chain_path = table.concat({ source, "config", "controller", path, extension }, Os_separator)
        reaper.TrackFX_AddByName(self.track, chain_path,
            false,
            -1000 - reaper.TrackFX_GetCount(self.track))
    end
end

--- Retrieve the values of controlled params of the channel strip.
--- Set the realearn params to match them,
--- and link the realearn params to the channel strip.
function state:createRealearnLink()
    error("not implemented")
end

--- check whether the channel strip's already loaded.
---@return boolean is_loaded is the channel strip with the corresponding FX loaded?
function state:getTrackFx()
    -- check that the track has the container with the correct containername
    local containerName = "prknctrl" .. controller
    local fx_count = reaper.TrackFX_GetCount(self.Track.track)
    for i = 0, fx_count - 1 do
        local _, fx_name = reaper.TrackFX_GetFXName(self.Track.track, i)
        if fx_name == containerName then
            return true
        end
    end
    return false
end

---@param track MediaTrack
function state:handleNewTrack(track)
    self:updateTrack(track)
    self:loadChannelStrip()
    self:createRealearnLink()
end

---Create the new track's table and store it.
---@param track MediaTrack
function state:updateTrack(track)
    local fx_chain_enabled = reaper.GetMediaTrackInfo_Value(track, "I_FXEN") ~= 0.0
    -- 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    local automation_mode  = reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE")

    ---TODO do we really need to re-query the details at every frame ?
    ---how likely to change are things such as `trackGuid`
    local trackGuid        = reaper.GetTrackGUID(track) -- get the track's GUID
    local _, trackName     = reaper.GetTrackName(track)

    local trackFxCount     = reaper.TrackFX_GetCount(track)
    local trackNumber      = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

    local bypass           = reaper.GetMediaTrackInfo_Value(track, "I_FXEN") == 1

    if not self.Track and track then
        self.Track = {
            track = track,
            number = trackNumber or -1,
            name = trackName,
            guid = trackGuid,
            fx_count = trackFxCount,
            bypass = bypass,
            fx_list = {},
            fx_by_guid = {},
            fx_chain_enabled = fx_chain_enabled,
            automation_mode = automation_mode
        }
    elseif self.Track and track then
        self.Track.track = track
        self.Track.number = trackNumber or -1
        self.Track.name = trackName
        self.Track.bypass = bypass
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
        self.Track.fx_chain_enabled = fx_chain_enabled
        self.Track.automation_mode = automation_mode
    else
        self.Track = nil
    end
end

--- get the selected track,
-- search for the container with the channel strip
-- and store them in the state.
function state:update()
    self:queryExtStateActions()
    local track = reaper.GetSelectedTrack2(0, 0, false)
    if not track then
        self:DeMapTrack()
        self.Track = nil
        return self
    end -- if there's no selected track, move on

    self:handleNewTrack(track)

    return self
end

--- Initialize the state: get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters.
---@param project_directory string
function state:init(project_directory, user_settings)
    self.project_directory = project_directory
    self.user_settings = user_settings
    ---@type Track|nil
    self.Track = nil
    self:update():getTrackFx()
    return self
end

return state
