--[[
allow loading configs from a file
]]
local constants = require("internals.state_machine.constants")
local types = require("internals.types")
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

---@param config ControllerConfig
local function validateConfig(config)
    for k, _ in ipairs(types.ControllerConfigFields) do
        if not config[k] then
            reaper.MB("missing field in config: " .. k, "Config error", 2)
            return false
        end
    end
    if not
        fs_helpers.file_exists(fs_helpers.build_prknctrl_path(config.rfxChain, "rfxChain"))
        or fs_helpers.file_exists(fs_helpers.build_prknctrl_path(config.realearnRfxChain, "rfxChain")) then
        return false
    end
    return true
end

---@param controller ControllerId
---@return ControllerConfig|nil config
function loader.load(controller)
    local controller_name = getkey(controller)
    local config = require("config.controller_mappings." .. controller_name)
    if not validateConfig(config) then
        return nil
    end
    return config
end

return loader
