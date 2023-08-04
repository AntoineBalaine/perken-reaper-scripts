  -- @noindex
  
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
