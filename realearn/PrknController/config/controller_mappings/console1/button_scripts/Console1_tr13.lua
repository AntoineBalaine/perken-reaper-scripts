--[[
POC -- call the state machine with the current button’s identifier
]]

--@noindex
local info = debug.getinfo(1, "S")
local root_path = info.source:match([[([^@]*Console1[^\/]*[\/])]])
package.path = package.path .. ";" .. root_path .. "?.lua"

local doInput = require("perken_controller")

doInput(21)
