-- @noindex
-- @description Decrescendo: Crescendo item volumes
-- @version 0.0.1
-- @author Perken
-- @provides
--  utilities/drums.lua
-- @about
--   # flam
--   HOW TO USE:
--   - in arrange view, select some items (preferably next to each other) and call the action
--
--   BEHAVIOUR:
--   - Tweaks the volume of the selected items to create a crescendo
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

drums.crescendo()
