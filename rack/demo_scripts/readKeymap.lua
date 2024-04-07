--- Move this to the rack's root directory in order to use.
local info = debug.getinfo(1, "S")

local os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
---@type string
CurrentDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
package.path = CurrentDirectory .. "?.lua;"

local keymap = require("lib.reaper-kb_ini")    -- get the scanner/parser for the keymap file
local process = require("shortcuts.processKeymap") -- get the function that maps the keymap file into named tables


local path = "/home/antoine/.config/REAPER" ..
    os_separator ..
    "reaper-kb.ini"                 -- pull the path for the reaper-kb.ini file, the key map file
local lines = keymap.readFile(path) -- split the file into lines
if not lines then return end
local start = reaper.time_precise()
local scannedLines = keymap.KeyMapScanner(lines):scanLines()       -- scan the lines into an array of string arrays
local end_time = reaper.time_precise()
local actions, keys, scripts = process.processKeymap(scannedLines) -- map each of the string arrays into a KeyLine object
reaper.ShowConsoleMsg("actions: " .. #actions .. "\n")
reaper.ShowConsoleMsg("keys: " .. #keys .. "\n")
reaper.ShowConsoleMsg("scripts: " .. #scripts .. "\n")
reaper.ShowConsoleMsg("start: " .. start .. "\n")
reaper.ShowConsoleMsg("end: " .. end_time .. "\n")
reaper.ShowConsoleMsg("total time: " .. end_time - start .. "\n")

--[[ TODO mapper for the keys scripts:
for each of the keys,
find the corresponding imGui Function with its modifiers
and register it in the shortcuts manager,
and then read through the key-hits at every frame.
]]
print("done")
