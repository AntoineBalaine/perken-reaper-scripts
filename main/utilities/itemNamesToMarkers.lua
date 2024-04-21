--[[
create markers at every item on the selected track
and rename them to the file name of the item

Get selected track
Iterate all items.
For each item,
    retrieve the file name, and create a marker carrying the file name.
]]
local function itemNamesToMarker()
    local track = reaper.GetSelectedTrack(0, 0)
    local items = reaper.CountTrackMediaItems(track)
    reaper.Undo_BeginBlock()
    for idx = 0, items - 1 do
        local item = reaper.GetTrackMediaItem(track, idx)
        local take = reaper.GetMediaItemTake(item, 0)
        local pcmSource = reaper.GetMediaItemTake_Source(take)
        local filePath = reaper.GetMediaSourceFileName(pcmSource)
        --[[
        trim the file path to the file name
        and remove the file extension
        --]]
        local fileName = string.match(filePath, "^.+/(.+)$")
        fileName = string.match(fileName, "^(.+)%..+$")
        -- make it uppercase
        fileName = string.upper(fileName)
        --[[
        get start position of item
        if there is no marker at the start position, create a marker
        set the marker name to the file name
        ]]
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemStart + itemLength

        local markers = reaper.CountProjectMarkers(0)
        local hasMarker = false
        for markIdx = 0, markers - 1 do
            local retval, _, pos, _, _, _ = reaper.EnumProjectMarkers(markIdx)
            if retval and pos == itemStart then
                reaper.SetProjectMarker(markIdx, true, itemStart, itemEnd, fileName)
                hasMarker = true
                break
            end
        end
        if not hasMarker then
            reaper.AddProjectMarker2(0, true, itemStart, itemEnd, fileName, -1, 0)
        end
    end
    reaper.Undo_EndBlock("itemNamesToMarker", 0)
end

itemNamesToMarker()
