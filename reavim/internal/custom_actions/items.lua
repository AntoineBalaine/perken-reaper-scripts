local utils = require("custom_actions.utils")

local items = {}

-- paste item before edit cursor position

function items.paste_before()
  --[[
  paste item before edit cursor position
  tb revised
]]

  reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DOSTORECURPOS"), 0)  -- store edit cursor pos
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_SAVESEL"), 0)             -- store track selection

  reaper.Main_OnCommand(40001, 0)                                                 -- insert track
  reaper.Main_OnCommand(40058, 0)                                                 -- paste item
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DORECALLCURPOS"), 0) -- recall edit cursor pos
  reaper.Main_OnCommand(41307, 0)                                                 -- move right edge of item to cursor pos
  reaper.Main_OnCommand(40318, 0)                                                 -- move cursor to right edge of item
  reaper.Main_OnCommand(40699, 0)                                                 -- cut items
  reaper.Main_OnCommand(40005, 0)                                                 -- remove track
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_RESTORESEL"), 0)          -- restore track selection
  reaper.Main_OnCommand(40058, 0)                                                 -- paste item
end

---@param item MediaItem
local function Set2msFadesAtEnds(item)
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.002)
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.002)
end

function items.set2msFades()
  utils.cycleSelectedItemsInSelectedTracks(Set2msFadesAtEnds)
end

return items
