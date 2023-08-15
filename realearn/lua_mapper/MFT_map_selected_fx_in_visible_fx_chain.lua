-- @description Midi-fighter-twister: map selected fx in visible fx chain
-- @version 0.0.3
-- @author Perken
-- @provides
--  dependencies/serpent.lua
--  dependencies/utils.lua
--  main_compartment_mapper.lua
--  MFT_controller_compartment.lua
-- @about
--   # MFT_map_selected_fx_in_visible_fx_chain
--   HOW TO USE:
--   - have a realearn instance with the Midi fighter's preset loaded in the main compartment.
--   - select some FX in current chain,
--   - focus the arrange view,
--   - call the script
--   - focus realearn
--   - click button «import from clipboard»
--
--   Each parameter of the selected FX gets assigned a knob on the Midi Fighter Twister.
--   Paging is done with side-buttons.
--   Only basic jsfx seem to work correctly atm.
-- @links
--  Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
-- @changelog
--   0.0.3 Fix coloring per fx in pages
--   0.0.2 Fix paging in auto-mapper
--   0.0.1 Setup the script



-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local info = debug.getinfo(1, "S")

local internal_root_path = info.source:match(".*perken.realearn.lua_mapper."):sub(2)

local windows_files = internal_root_path:match("\\$")
if windows_files then
  package.path = package.path .. ";" .. internal_root_path .. "\\?.lua"
else
  package.path = package.path .. ";" .. internal_root_path .. "/?.lua"
end
local serpent = require("dependencies.serpent")
local Main_compartment_mapper = require("main_compartment_mapper")


local MFT = {}

function MFT.create_fx_map()
  local ENCODERS_COUNT = 16
  local main_compartment = Main_compartment_mapper.Map_selected_fx_in_visible_chain(ENCODERS_COUNT)

  -- local MFT_MAPPING = { MFT_controller_compartment, main_compartment }

  local lua_table_string = serpent.serialize(main_compartment, { comment = false }) -- stringify the modulator
  reaper.CF_SetClipboard(lua_table_string)
end

MFT.create_fx_map()
