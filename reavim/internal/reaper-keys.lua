--[[
    @description ReaVim: Vim mode for reaper
    @version 
      0.0.1
    @author Perken
    @provides
    ../**/*.lua
    ../reaper-keys-unix.ReaperKeyMap
    ../reaper-keys-windows.ReaperKeyMap
    @about
    # reavim
    HOW TO USE:
    Since this project is a fork of https://github.com/gwatcha/reaper-keys, please refer to the original documentation for installation and usage.
    @links
    Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
    Gwatcha's original reaper-keys repo https://github.com/gwatcha/reaper-keys
    @changelog
    0.0.1 Setup the script
]]
local info = debug.getinfo(1, "S")

local internal_root_path = info.source:match(".*reavim[^\\/]*[\\/]internal[\\/]"):sub(2)
package.path = package.path .. ";" .. internal_root_path .. "?.lua"

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

function errorHandler(err)
    log.error(err)
    log.error(debug.traceback())
end

function doInput(key_press)
    xpcall(input, errorHandler, key_press)
end

return doInput
