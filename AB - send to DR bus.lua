-- @noindex

package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
require 'sr_Send selected track(s) to BUS and remove master send function'

local bus_prefix = "DR BUS"

SendTrackToBUS(bus_prefix) -- call function
