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

---@param action "fade" | "trim"
---@param edge "left" | "right"
local function editItemFromMouse(action, edge)
  -- store edit cursor position
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DOSTORECURPOS"), 0)
  -- move edit cursor to mouse cursor
  reaper.Main_OnCommand(40514, 0)
  local isSnapEnabled = reaper.GetToggleCommandStateEx(0, 1157) == 1

  if isSnapEnabled then
    -- Snap the edit cursor position to the nearest snap point
    local nearestSnapPoint = reaper.SnapToGrid(0, reaper.GetCursorPosition())
    reaper.MoveEditCursor(nearestSnapPoint - reaper.GetCursorPosition(), false)
  end
  -- select item under mouse cursor
  reaper.Main_OnCommand(40528, 0)
  if action == "fade" then
    if edge == "left" then
      -- fade item in to cursor
      reaper.Main_OnCommand(40509, 0)
    else
      -- fade item right
      reaper.Main_OnCommand(40510, 0)
    end
  else -- trim
    if edge == "left" then
      -- trim left edge of item to edit
      reaper.Main_OnCommand(41300, 0)
    else
      -- trim right edge of item to edit
      reaper.Main_OnCommand(41310, 0)
    end
  end
  -- unselect all items
  reaper.Main_OnCommand(40289, 0)
  -- restore edit cursor position
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_DORECALLCURPOS"), 0)
end

function items.fadeItemInFromMouse()
  editItemFromMouse("fade", "left")
end

function items.fadeItemOutFromMouse()
  editItemFromMouse("fade", "right")
end

function items.trimRightEdgeFromMouse()
  editItemFromMouse("trim", "right")
end

function items.trimLeftEdgeFromMouse()
  editItemFromMouse("trim", "left")
end

return items
