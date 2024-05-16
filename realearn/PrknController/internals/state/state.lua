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


---map the current state's data into a
--simplified format to be stored in ext state
---this is so we can persist data across restarts.
function state:format_ext_state()
    error("format ext state")
end

function state:persist_ext_state()
    local new_ext_state = self:format_ext_state()
    state_interface.set(controller.id, new_ext_state)
end

--- retrieve external state changes.
--- run any actions that are stored in the external state.
--- this is the hook to the state machine
---@return boolean|nil doExit
function state:queryExtStateActions()
    error("query ExtState actions")

    local ext_state = state_interface.get(controller)
    if ext_state.button_press then
        if ext_state.button_press == "exit" then
            return true
        end
        -- handle the action
        error("handle the action")
        self:persist_ext_state()
    end
end

---load the modules for the currently selected track into realearn.
---if not selected, do nothing.
function state:LoadRealearnPresets()
    if self.Track.track == nil then
        return
    end
    for module_name, module in ipairs(self.Track.modules) do
        -- get the needed strip for the current track
        -- find the matching json maps,
        -- load them into realearn
        --
        local preset = module.realearnPreset
        local preset_json = getRelearnPreset(preset)
        reaper.TrackFX_SetNamedConfigParm(reaper.GetSelectedTrack(0, 0), 0, "set-state", preset_json)
        -- ok, current_state = reaper.TrackFX_GetNamedConfigParm(reaper.GetSelectedTrack(0 , 0),0,"set-state")
    end
end

---  load the default channel strip
function state:loadChannelStrip()
    --[[
            Read from current config:
           Append the chain to the track
           Create the fx instances for the track
           and query the fx params that need to be controlled
        ]]
    if not config then
        reaper.MB("Couldn't find/load default channel strip for this controller\nWill exit now.",
            "Couldn't find the default channel strip", 2)
        return
    end
    if self.Track then

    end
    if self:hasChannelStrip() then
        return
    else
        -- load channel strip?
        -- or wait until user clicks activates one of the modules to start it ?
    end
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

---@param realearn_idx number
function state:handleNewTrack()
    self:getRealearnInstances()
    self:updateTrack()
    if not self:validateChannelStrip() then
        self:loadChannelStrip()
    end
    self:LoadRealearnPresets()
end

---Create the new track's table and store it.
function state:updateTrack()
    local track            = self.Track.track
    local fx_chain_enabled = reaper.GetMediaTrackInfo_Value(track, "I_FXEN") ~= 0.0
    -- 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    local automation_mode  = reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE")

    ---TODO do we really need to re-query the details at every frame ?
    ---how likely to change are things such as `trackGuid`
    local trackGuid        = reaper.GetTrackGUID(track) -- get the track's GUID
    local _, trackName     = reaper.GetTrackName(track)

    local trackFxCount     = reaper.TrackFX_GetCount(track)
    local trackNumber      = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")


    if not self.Track and track then
        self.Track = {
            track = track,
            number = trackNumber or -1,
            name = trackName,
            guid = trackGuid,
            fx_count = trackFxCount,
            fx_list = {},
            fx_by_guid = {},
            fx_chain_enabled = fx_chain_enabled,
            automation_mode = automation_mode
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
        self.Track.fx_chain_enabled = fx_chain_enabled
        self.Track.automation_mode = automation_mode
    else
        self.Track = nil
    end
end

--- get the selected track,
-- search for the container with the channel strip
-- and store them in the state.
---@return boolean|nil doExit
function state:update()
    if self:queryExtStateActions() then
        return true
    end
    local track = reaper.GetSelectedTrack2(0, 0, false)

    if track ~= self.Track.track then
        if not track then -- if there's no selected track, move on
            self.Track = nil
        else
            self.Track.track = track
            self:handleNewTrack()
        end
    end
end

---there's 1 realearn instance per module,
---so query the three instances
---and store them.
---@return number|nil index
function state:getRealearnInstances()
    local master = reaper.GetMasterTrack(0)
    for instance_name, instance in pairs(controller.modules.realearnInstances) do
        local idx = reaper.TrackFX_AddByName(master, instance_name, true, 1)
        if idx == -1 then
            reaper.MB("failed to load realearn instance",
                "Couldn't load the realearn instance", 2)
            return
        end
        if instance.idx ~= idx then
            instance.idx = reaper.TrackFX_GetByName(master, instance_name, false)
        end
    end
end

---event loop
function state:Main()
    if self:update() then
        -- exit the script.
        reaper.set_action_options(8) -- toggle state OFF
        return
    end

    reaper.defer(function() self:Main() end)
end

--- Initialize the state: get the selected track,
-- the last touched fx,
-- the fx list for current track and parameters.
---@param project_directory string
function state:init(project_directory, user_settings)
    self.project_directory = project_directory
    self.user_settings = user_settings
    self.tracks = {}
    ---@type Track|nil
    self.Track = nil
    reaper.set_action_options(4) -- toggle state ON

    self:getRealearnInstances()

    local ext_state = state_interface.get(controller)
    --- restore state from ext state if any, on first load.
    self:Main()
    return self
end

return state
