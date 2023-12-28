--@noindex
local info = debug.getinfo(1, "S")
local root_path = info.source:match([[([^@]*reavim[^\\/]*[\\/])]])
package.path = package.path .. ";" .. root_path .. "?.lua"

local doInput = require("internal.reaper-keys")

doInput({ ["key"] = "<CM-y>", ["context"] = "midi" })
