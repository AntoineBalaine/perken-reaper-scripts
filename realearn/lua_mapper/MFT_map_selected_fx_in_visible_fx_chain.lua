dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local info = debug.getinfo(1, "S")

local internal_root_path = info.source:match(".*perken.realearn.lua_mapper."):sub(2)

local windows_files = internal_root_path:match("\\$")
if windows_files then
  package.path = package.path .. ";" .. internal_root_path .. "\\?.lua"
else
  package.path = package.path .. ";" .. internal_root_path .. "/?.lua"
end
local serpent = require("dependencies.serpent")
local utils = require("dependencies.utils")
local Main_compartment_mapper = require("main_compartment_mapper")
-- local MFT_controller_compartment = require("MFT_controller_compartment")

ENCODERS_COUNT = 16
local main_compartment = Main_compartment_mapper.Map_selected_fx_in_visible_chain(16)

-- local MFT_MAPPING = { MFT_controller_compartment, main_compartment }

local lua_table_string = serpent.serialize(main_compartment, { comment = false }) -- stringify the modulator
reaper.CF_SetClipboard(lua_table_string)
