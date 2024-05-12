--[[
@description PrknCtrl: Midi control mode for realern
@version
  0.0.1
@author Perken
@provides
    ./**/*.lua
@about
    # PrknCtrl
    HOW TO USE:
    
@links
    Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
@changelog
    0.0.1 Setup the script
]]
local info = debug.getinfo(1, "S")

local Os_separator = package.config:sub(1, 1)
local source = table.concat({ info.source:match(".*reavim"..Os_separator), "internal", Os_separator, })
local internal_root_path = source:sub(2)
package.path = package.path .. ";" .. internal_root_path .. "?.lua"

-- TODO REMOVE these imports?
local windows_files = internal_root_path:match("\\$")
if windows_files then
    package.path = package.path .. ";" .. internal_root_path .. "..\\definitions\\?.lua"
    package.path = package.path .. ";" .. internal_root_path .. "?\\?.lua"
    package.path = package.path .. ";" .. internal_root_path .. "vendor\\share\\lua\\5.3\\?.lua"
    package.path = package.path .. ";" .. internal_root_path .. "vendor\\share\\lua\\5.3\\?\\init.lua"
    package.path = package.path .. ";" .. internal_root_path .. "vendor\\scythe\\?.lua"
else
    package.path = package.path .. ";" .. internal_root_path .. "../definitions/?.lua"
    package.path = package.path .. ";" .. internal_root_path .. "?/?.lua"
    package.path = package.path .. ";" .. internal_root_path .. "vendor/share/lua/5.3/?.lua"
    package.path = package.path .. ";" .. internal_root_path .. "vendor/share/lua/5.3/?/init.lua"
    package.path = package.path .. ";" .. internal_root_path .. "vendor/scythe/?.lua"
end

local input = require("state_machine")
local log = require("utils.log")

local function errorHandler(err)
    log.error(err)
    log.error(debug.traceback())
end

---@param controllerId ControllerId
---@param actionId ActionId
local function doInput(controllerId, actionId)
    xpcall(input, errorHandler, controllerId, actionId)
end

return doInput
