-- @description 2 stroke: create a drum 2 stroke-flush on the selected item
-- @version 0.0.1
-- @noindex

-- @author Perken
-- @provides
--  utilities/drums.lua
-- @about
--   # flam
--   HOW TO USE:
--   - in arrange view, select an item and call the action
--   - works with midi too
--
--   BEHAVIOUR:
--   - create a 2stroke right before the selected item
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

drums.ras3()
