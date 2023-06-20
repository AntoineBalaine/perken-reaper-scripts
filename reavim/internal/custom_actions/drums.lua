local utils = require("custom_actions.utils")

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

return drums
