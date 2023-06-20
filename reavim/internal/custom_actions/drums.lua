local utils = require("custom_actions.utils")

local drums = {}

function drums.flam()
  local tracks = utils.getSelectedTracks()
  for i = 1, #tracks do
    local track = tracks[i]

    local items = utils.getSelectedItemsInTrack(track)
    for _, item in ipairs(items) do
      local flamLength = 0.04 -- 40ms
      -- Get the item's start position and length
      local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      -- Calculate the end position for the desired portion
      local endPos = itemPos + flamLength

      -- Adjust the item's end position to the desired portion
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", endPos - itemPos)
      -- paste item at item position - flam length
      local new_item = utils.CopyMediaItemToTrack(item, track, itemPos - flamLength)
      -- nudge volume by 12db
      utils.nudgeItemVolume(new_item, -12)
      -- restore item length
      reaper.SetMediaItemInfo_Value(item, "D_LENGTH", itemLength)
      -- set fades on new item
      reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN", 0.010)
      reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", 0.001)
    end
  end
end

return drums
