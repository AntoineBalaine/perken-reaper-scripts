  -- @noindex
  
local utils = require("utils")

local drums = {}

---@param item MediaItem
---@param track MediaTrack
---@param reps number | nil
function CreateFlams(item, track, reps)
  local flamLength = 0.04 -- 40ms
  local fadeInLength = 0.01
  local nudgeVolumeAmount = -16
  if reps == nil then reps = 1 end
  if reps > 1 then
    flamLength = 0.035
    fadeInLength = 0.006
  end
  -- Get the item's start position and length
  local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  -- Calculate the end position for the desired portion
  local endPos = itemPos + flamLength

  -- Adjust the item's end position to the desired portion
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", endPos - itemPos)
  -- loop for the number of reps, pasting the item at the desired position
  local flamPos = itemPos - flamLength
  local pitchTransposeAmount = -0.5
  for i = 1, reps do
    -- paste item at item position - flam length
    local new_item = utils.CopyMediaItemToTrack(item, track, flamPos)
    -- nudge volume by 12db
    utils.nudgeItemVolume(new_item, nudgeVolumeAmount)
    -- set fades on new item
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN", fadeInLength)
    reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", 0.001)
    local take = reaper.GetActiveTake(new_item) ---@type MediaItem_Take
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitchTransposeAmount)
    flamPos = flamPos - flamLength
    pitchTransposeAmount = pitchTransposeAmount - 0.15
    nudgeVolumeAmount = nudgeVolumeAmount - 3
  end

  -- restore item length
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", itemLength)
end

function drums.flam()
  local function fla(item, track)
    CreateFlams(item, track)
  end
  utils.cycleSelectedItemsInSelectedTracks(fla)
end

function drums.ras3()
  local function ras(item, track)
    CreateFlams(item, track, 2)
  end
  utils.cycleSelectedItemsInSelectedTracks(ras)
end

function drums.ras5()
  local function ras(item, track)
    CreateFlams(item, track, 4)
  end
  utils.cycleSelectedItemsInSelectedTracks(ras)
end

function drums.crescendo()
  utils.cycleSelectedTracks(CrescendoTrackSelectedItems)
end

function drums.decrescendo()
  utils.cycleSelectedTracks(DecrescendoTrackSelectedItems)
end

---@param track MediaTrack
function CrescendoTrackSelectedItems(track)
  local items = utils.getSelectedItemsInTrack(track)
  local lastItem = items[#items]
  local lastItemVol = reaper.GetMediaItemInfo_Value(lastItem, "D_VOL")
  local diminutionValue = 0.1
  -- subdivide the distance between 0 and the lastItemVol by the number of items
  local increment = (lastItemVol - diminutionValue) / #items
  local pitchTransposeAmount = -0.15 * #items

  -- loop in reverse of items
  for i = #items, 1, -1 do
    local item = items[i]
    -- local itemVol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    reaper.SetMediaItemInfo_Value(item, "D_VOL", lastItemVol - diminutionValue)
    local take = reaper.GetActiveTake(item) ---@type MediaItem_Take
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitchTransposeAmount)
    diminutionValue = diminutionValue + increment
    pitchTransposeAmount = pitchTransposeAmount - 0.15
  end
end

function DecrescendoTrackSelectedItems(track)
  local items = utils.getSelectedItemsInTrack(track)
  local firstItem = items[1]
  local firstItemVol = reaper.GetMediaItemInfo_Value(firstItem, "D_VOL")
  local diminutionValue = 0.1
  -- subdivide the distance between 0 and the lastItemVol by the number of items
  local increment = (firstItemVol - diminutionValue) / #items
  local pitchTransposeAmount = -0.01 * #items

  -- loop in reverse of items
  for i = 1, #items do
    local item = items[i]
    -- local itemVol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    reaper.SetMediaItemInfo_Value(item, "D_VOL", firstItemVol - diminutionValue)
    local take = reaper.GetActiveTake(item) ---@type MediaItem_Take
    reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitchTransposeAmount)
    diminutionValue = diminutionValue + increment
    pitchTransposeAmount = pitchTransposeAmount - 0.05
  end
end

function drums.quantizeTool()
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS61423f4f1224e18018576b5e3e1af80ebbd67f7e"), 0)
end

return drums
--[[
    crescendo: function,
    decrescendo: function,
    flam: function,
    quantizeTool: function,
    ras3: function,
    ras5: function,
]]
