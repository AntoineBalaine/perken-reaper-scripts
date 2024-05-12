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

local state_interface = require("internals.state_machine.state_interface")
local constants = require("internals.state_machine.constants")
local loader = require("internals.state.ControllerConfigLoader")
local fs_helpers = require("internals.helpers.fs_helpers")
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

local realearn_instance_name = "prknctrl_realearn_console1"
local containerName = "prknctrl" .. controller

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
---@param realearn_idx number
function state:DeMapTrack(realearn_idx)
    if self.Track then
        if not realearn_idx then return nil end
        error("not implemented")
        for _, fx in ipairs(self.Track.fx_list) do
            -- REMOVE mappings from realearn
        end
        return realearn_idx
    end
end

---  load the default channel strip
function state:loadChannelStrip()
    if self:hasChannelStrip() then return end
    --[[
            Read from current config:
            - the .rfx chain that is to be appended to the track
            - the params mappings that are to be used
           Append the chain to the track
           Create the fx instances for the track
           and query the fx params that need to be controlled
        ]]
    if not config then
        reaper.MB("Couldn't find/load default channel strip for this controller\nWill exit now.",
            "Couldn't find the default channel strip", 2)
        return
    end

    local path = config.rfxChain
    local extension = "rfxChain"
    local chain_path = fs_helpers.build_prknctrl_path(path, extension)

    local rv = reaper.TrackFX_AddByName(self.Track.track, chain_path,
        false,
        -1000 - self.Track.fx_count)
end

--- Retrieve the values of controlled params of the channel strip.
--- Set the realearn params to match them,
--- and link the realearn params to the channel strip.
---@param realearn_idx number
function state:createRealearnLink(realearn_idx)
    error("not implemented")
    --[[
    for each param in the config,
    query the value of the matching in the matching fx's matching param in the channel strip
    set the realearn param to match the value
    and link the realearn param to the channel strip
    ]]

end

--- check whether the channel strip's already loaded.
---@return boolean is_loaded is the channel strip with the corresponding FX loaded?
---@return number|nil index
function state:hasChannelStrip()
    -- check that the track has the container with the correct containername
    local fx_count = reaper.TrackFX_GetCount(self.Track.track)
    local idx      = reaper.TrackFX_GetByName(self.Track.track, containerName, false)
    return idx > -1 and true or false
end

---@param track MediaTrack
---@param realearn_idx number
function state:handleNewTrack(track, realearn_idx)
    self:updateTrack(track)
    self:loadChannelStrip()
    self:createRealearnLink(realearn_idx)
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
    local realearn_idx = self:getRealearnInstance()
    if not realearn_idx then
        reaper.MB("Couldn't find/load realearn instance for this controller\nWill exit now.",
            "Couldn't find the realearn instance", 2)
        return
    end
    self:DeMapTrack(realearn_idx)
    if not track then -- if there's no selected track, move on
        self.Track = nil
        return self
    else
        self:handleNewTrack(track, realearn_idx)
    end


    return self
end

function state:loadRealearnInstance()
    --[[
    load the realearn instance
    from Fx chain
    ]]
    if not config then return end
    local path = config.realearnRfxChain
    local extension = "rfxChain"
    local chain_path = fs_helpers.build_prknctrl_path(path, extension)
    local rv = reaper.TrackFX_AddByName(self.Track.track, chain_path,
        false,
        -1000 - self.Track.fx_count)
end

---TODO should this be memoized instead ?
--- get the realearn instance fx
---@return number|nil index
function state:getRealearnInstance()
    local master = reaper.GetMasterTrack(0)
    local idx    = reaper.TrackFX_GetByName(master, realearn_instance_name, false)
    return idx > -1 and idx or nil
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
    self:update():hasChannelStrip()
    return self
end

return state
