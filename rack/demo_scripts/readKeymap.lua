local info = debug.getinfo(1, "S")

local os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
---@type string
CurrentDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
package.path = CurrentDirectory .. "?.lua;"

local keymap = require("parsers.reaper-kb_ini")    -- get the scanner/parser for the keymap file
local process = require("shortcuts.processKeymap") -- get the function that maps the keymap file into named tables


local path = "/home/antoine/.config/REAPER" ..
    os_separator ..
    "reaper-kb.ini"                                                -- pull the path for the reaper-kb.ini file, the key map file
local lines = keymap.readFile(path)                                -- split the file into lines
if not lines then return end
local scannedLines = keymap.KeyMapScanner(lines):scanLines()       -- scan the lines into an array of string arrays
local actions, keys, scripts = process.processKeymap(scannedLines) -- map each of the string arrays into a KeyLine object

--[[ TODO mapper for the keys scripts:
for each of the keys,
find the corresponding imGui Function with its modifiers
and register it in the shortcuts manager,
and then read through the key-hits at every frame.
]]
print("done")
