-- @noindex
-- @description Drum flam: create a flam on the selected item
-- @version 0.0.1
-- @author Perken
-- @provides
--  utilities/drums.lua
-- @about
--   # flam
--   HOW TO USE:
--   - in arrange view, select an item and call the action
--
--   BEHAVIOUR:
--   - create a flam right before the selected item, at a lower volume
-- @links
--  Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
-- @changelog
--   0.0.1 Setup the script

local info = debug.getinfo(1, "S")

local internal_root_path = info.source:match(".*perken.main."):sub(2) .. "utilities"

local windows_files = internal_root_path:match("\\$")
if windows_files then
  package.path = package.path .. ";" .. internal_root_path .. "\\?.lua"
else
  package.path = package.path .. ";" .. internal_root_path .. "/?.lua"
end

local drums = require("drums")

drums.flam()
