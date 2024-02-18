dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local info             = debug.getinfo(1, "S")

local Os_separator     = package.config:sub(1, 1)
local source           = info.source:match(".*rack" .. Os_separator):sub(2)
package.path           = package.path .. ";" .. source .. "?.lua"
---@type string
local projectDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]   -- GET DIRECTORY FOR REQUIRE
package.path           = projectDirectory .. "?.lua;"

local Rack             = require("components.Rack")
local rack             = Rack:init(projectDirectory)
reaper.defer(function() rack:main() end)
