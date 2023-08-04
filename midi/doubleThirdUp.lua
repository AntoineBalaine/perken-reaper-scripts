  -- @noindex
  
local info = debug.getinfo(1, "S")

local internal_root_path = info.source:match(".*perken.midi."):sub(2)

local windows_files = internal_root_path:match("\\$")
if windows_files then
  package.path = package.path .. ";" .. internal_root_path .. "dependencies\\?.lua"
  package.path = package.path .. ";" .. internal_root_path .. "midi_utilities\\?.lua"
else
  package.path = package.path .. ";" .. internal_root_path .. "midi_utilities/?.lua"
end
local kawa = require("kawa")
kawa.doubleThirdUp()
