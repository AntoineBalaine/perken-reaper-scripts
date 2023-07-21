local utils = require("custom_actions.utils")
local reaper_state = require("../utils/reaper_state")

local movement = {}

function movement.projectStart()
	reaper.SetEditCurPos(0, true, false)
end

function movement.projectEnd()
	local project_end = reaper.GetProjectLength(0)
	reaper.SetEditCurPos(project_end, true, false)
end

function movement.lastItemEnd()
	local item_positions = utils.getBigItemPositionsOnSelectedTracks()
	if #item_positions > 0 then
		local last_item = item_positions[#item_positions]
		reaper.SetEditCurPos(last_item.right, true, false)
	end
end

function movement.firstItemStart()
	local item_positions = utils.getBigItemPositionsOnSelectedTracks()
	if #item_positions > 0 then
		local first_item = item_positions[1]
		reaper.SetEditCurPos(first_item.left, true, false)
	end
end

movement.midi = {}

function movement.midi.takeStart()
	-- get start of take
	local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
	-- local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
	-- position of start of item
	local item_start = reaper.GetMediaItemInfo_Value(reaper.GetMediaItemTake_Item(take), "D_POSITION")
	reaper.SetEditCurPos(item_start, true, false)
end

function movement.midi.takeEnd()
	-- get end of take
	local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
	local itm = reaper.GetMediaItemTake_Item(take)

	local takeLength = reaper.GetMediaItemInfo_Value(itm, "D_LENGTH")       -- get current item length and position
	local takePosition = reaper.GetMediaItemInfo_Value(itm, "D_POSITION")   -- Get the position of the take in seconds
	-- position of start of item
	reaper.SetEditCurPos(takePosition + takeLength, true, false)
end

function moveToPrevItemStart(item_positions)
	local current_position = reaper.GetCursorPosition()
	local next_position = nil
	for i, item in pairs(item_positions) do
		if not next_position and item.left < current_position and item.right >= current_position then
			next_position = item.left
		end

		if next_position and item.left > next_position and item.right >= next_position then
			next_position = item.left
		end

		local next_item = item_positions[i + 1]
		if not next_item or next_item.left >= current_position then
			next_position = item.left
			break
		end
	end

	if next_position then
		reaper.SetEditCurPos(next_position, true, false)
	end
end

function movement.prevBigItemStart()
	moveToPrevItemStart(utils.getBigItemPositionsOnSelectedTracks())
end

function movement.prevItemStart()
	moveToPrevItemStart(utils.getItemPositionsOnSelectedTracks())
end

function moveToNextItemStart(item_positions)
	local current_position = reaper.GetCursorPosition()
	local next_position = nil
	for i, item_position in pairs(item_positions) do
		if not next_position and current_position < item_position.left then
			next_position = item_position.left
		end
		if next_position and item_position.left < next_position then
			next_position = item_position.left
		end
	end
	if next_position then
		reaper.SetEditCurPos(next_position, true, false)
	end
end

function movement.nextBigItemStart()
	moveToNextItemStart(utils.getBigItemPositionsOnSelectedTracks())
end

function movement.nextItemStart()
	moveToNextItemStart(utils.getItemPositionsOnSelectedTracks())
end

function moveToNextItemEnd(item_positions)
	local current_position = reaper.GetCursorPosition()
	local next_position = nil
	local tolerance = 0.002
	for _, item_position in pairs(item_positions) do
		if not next_position and item_position.right - tolerance > current_position then
			next_position = item_position.right
		elseif next_position and item_position.right < next_position and item_position.right > current_position then
			next_position = item_position.right
		end
	end
	if next_position then
		reaper.SetEditCurPos(next_position, true, false)
	end
end

function movement.nextBigItemEnd()
	moveToNextItemEnd(utils.getBigItemPositionsOnSelectedTracks())
end

function movement.nextItemEnd()
	moveToNextItemEnd(utils.getItemPositionsOnSelectedTracks())
end

function movement.firstTrack()
	local first_track = reaper.GetTrack(0, 0)
	reaper.SetOnlyTrackSelected(first_track)
end

function movement.lastTrack()
	local num_tracks = reaper.GetNumTracks()
	local last_track = reaper.GetTrack(0, num_tracks - 1)
	reaper.SetOnlyTrackSelected(last_track)
end

function movement.trackWithNumber()
	local _, number = reaper.GetUserInputs("Match Forward", 1, "Track Number", "")
	if type(tonumber(number)) ~= "number" then
		return
	end

	local track = reaper.GetTrack(0, number - 1)
	if track then
		reaper.SetOnlyTrackSelected(track)
	end
end

function movement.firstTrackWithItem()
	local num_tracks = reaper.GetNumTracks()
	for i = 0, num_tracks - 1 do
		local track = reaper.GetTrack(0, i)
		if reaper.GetTrackNumMediaItems(track) > 0 then
			reaper.SetOnlyTrackSelected(track)
			return
		end
	end
end

function movement.snap()
	local pos = reaper.GetCursorPosition()
	local snapped_pos = reaper.SnapToGrid(0, pos)
	reaper.SetEditCurPos(snapped_pos, false, false)
end

function movement.storeCursorPosition() -- add cursor position to "cursorPositionStack"
	local cursorPos = reaper.GetCursorPosition()
	local stack = reaper_state.get("cursorPositionStack")
	if stack == nil then
		stack = {}
	end
	table.insert(stack, cursorPos)
	reaper_state.set("cursorPositionStack", stack)
end

function movement.restoreCursorPosition() -- retrieve previous cursor position from "cursorPositionStack"
	local stack = reaper_state.get("cursorPositionStack")
	if stack and #stack > 0 then
		local prevPos = stack[#stack]
		if prevPos then
			table.remove(stack, #stack)
			reaper_state.set("cursorPositionStack", stack)
			reaper.SetEditCurPos(prevPos, true, false)
		end
	end
end

function movement.jumpToBarNumber()
	local retval, num_string = reaper.GetUserInputs("Jump to bar number", 1, "Bar number", "")
	if retval == false then return end
	local barNumber = tonumber(num_string)
	-- get cursor position
	local cursorPos = reaper.GetCursorPosition()
	reaper.MoveEditCursor(reaper.TimeMap2_beatsToTime(0, 0, barNumber - 1) - cursorPos, false)
end

---@param direction "up" | "down" | "left" | "right	"
local function moveItem(direction)
	--- get selected items
	---for each item
	--- if direction === up
	--- move selected items to track above their tracks
	--- else if direction === down
	--- move selected items to track below their tracks
	--- else if direction === left
	--- move selected items to previous grid line (left grid line from start of item)
	--- else if direction === right
	--- move selected items to next grid line (right line from start of item)
	local selectedItems = getSelectedItems()
end

local function getSelectedItems()
	local numSelectedItems = reaper.CountSelectedMediaItems(0)
	---@type MediaItem[]
	local selectedItems = {}
	for i = 0, numSelectedItems - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		table.insert(selectedItems, item)
	end
	return selectedItems
end


return movement
