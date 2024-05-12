--[[
allow loading configs from a file
validate configs upon loading
]]
local constants = require("internals.state_machine.constants")
local fs_helpers = require("internals.helpers.fs_helpers")
local loader = {}

---@param controller ControllerId
---@return string|nil key
local function getkey(controller)
    local found_key = nil
    for k, v in pairs(constants.ControllerId) do
        if v == controller then
            found_key = k
            break
        end
    end
    return found_key
end

---@param controller_name string
---@return boolean valid
---@return string|nil channelStripPath
---@return string|nil realearnPath
---@return string|nil configPath
local function validateFiles(controller_name)
    local path = fs_helpers.getControllerConfigPath(controller_name)
    local rfx_extension = ".RfxChain"
    local channelStripPath = fs_helpers.concat(path, "prknCtrl_" .. controller_name .. "_channelStrip" .. rfx_extension)
    local realearnPath = fs_helpers.concat(path, "prknCtrl_" .. controller_name .. "_realearn" .. rfx_extension)
    local configPath = fs_helpers.concat(path, controller_name .. ".lua")
    if not fs_helpers.file_exists(channelStripPath)
        or not fs_helpers.file_exists(realearnPath)
        or not fs_helpers.file_exists(configPath)
    then
        reaper.MB([[ Missing files for controller: 
        channel strip fxchain, 
        realearn fxchain,  
        config file
        ]] .. controller_name, "Error", 0)
        return false
    end
    return true, channelStripPath, realearnPath, configPath
end

---@param controller_name string
---@return ControllerConfig|nil
local function validateConfig(controller_name)
    local is_valid, channelStripPath, realearnPath, configPath = validateFiles(controller_name)
    if not is_valid or not channelStripPath or not realearnPath or not configPath then
        return nil
    end
    local config = require(configPath)

    --- TODO make check for contents of data
    if config.paramData == nil or config.Modes == nil then
        reaper.MB([[ Invalid config file for controller ]] .. controller_name, "Error", 0)
        return nil
    end
    config.channelStripPath = channelStripPath
    config.realearnPath = realearnPath
    return config
end


---@param controller ControllerId
---@return ControllerConfig|nil config
function loader.load(controller)
    local controller_name = getkey(controller)
    if not controller_name then
        return nil
    end
    local config = validateConfig(controller_name)
    if not config then
        return nil
    end
    return config
end

return loader
