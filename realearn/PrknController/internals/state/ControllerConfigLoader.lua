--[[
allow loading configs from a file
]]
local constants = require("state_machine.constants")
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
    error("not implemented")
end

---@param controller ControllerId
---@return ControllerConfig|nil config
function loader.load(controller)
    local controller_name = getkey(controller)
    local config = require("config.controller_mappings." .. controller_name)
    return config
end

return loader
