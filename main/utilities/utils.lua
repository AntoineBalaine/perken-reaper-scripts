  -- @noindex
  
-- local log = require("utils.log")

local utils = {}
---@alias ItemPosition {left: number, right: number}

---@param item_positions_list table<number, table<number, ItemPosition>>
---@return table<number, ItemPosition>
function mergeItemPositionsLists(item_positions_list)
	local merged_list = {}

	function areRemainingItems()
		for i, item_positions in ipairs(item_positions_list) do
			if #item_positions_list[i] ~= 0 then
				return true
			end
		end
		return false
	end

	while areRemainingItems() do
		local next_item = nil
		for i, item_positions in ipairs(item_positions_list) do
			local next_item_for_this_list = item_positions[1]
			if next_item_for_this_list then
				if not next_item or next_item_for_this_list.left < next_item.left then
					next_item = next_item_for_this_list
					selected_list_i = i
				end
			end
		end

		table.insert(merged_list, next_item)
		table.remove(item_positions_list[selected_list_i], 1)
	end

	return merged_list
end

---@param tracks table<number, MediaTrack>
---@return table<number, ItemPosition>
function getItemPositionsOnTracks(tracks)
	---@type table<number, table<number, ItemPosition>>
	local item_positions_lists = {}
	for i = 1, #tracks do
		local current_track = tracks[i]
		---@type table<number, ItemPosition>
		local item_positions = {}
		---@type number
		local num_items_on_track = reaper.GetTrackNumMediaItems(current_track)

		for j = 1, num_items_on_track do
			local item = reaper.GetTrackMediaItem(current_track, j - 1)
			local start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
			local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
			item_positions[j] = { left = start, right = start + length }
		end

		item_positions_lists[i] = item_positions
	end

	local merged_list = mergeItemPositionsLists(item_positions_lists)
	return merged_list
end

---@return table<number, ItemPosition>
function utils.getItemPositionsOnSelectedTracks()
	---@type table<number, MediaTrack>
	local selected_tracks = {}
	for i = 0, reaper.CountSelectedTracks() do
		selected_tracks[i] = reaper.GetSelectedTrack(0, i - 1)
	end

	return getItemPositionsOnTracks(selected_tracks)
end

---@return table<number, ItemPosition>
function utils.getBigItemPositionsOnSelectedTracks()
	local item_positions = utils.getItemPositionsOnSelectedTracks()
	local big_item_positions = {}

	if #item_positions == 0 then
		return big_item_positions
	end

	local j = 1
	big_item_positions[j] = item_positions[1]
	for i = 1, #item_positions do
		local next_item = item_positions[i]
		local current_big_item = big_item_positions[j]
		if next_item.left <= current_big_item.right and next_item.right > current_big_item.right then
			current_big_item.right = next_item.right
			big_item_positions[j] = current_big_item
		end

		if next_item.left > current_big_item.right then
			j = j + 1
			big_item_positions[j] = next_item
		end
	end

	return big_item_positions
end

---@param id number
---@return boolean
function utils.selectRegion(id)
	local ok, is_region, start_pos, end_pos, _, got_id = reaper.EnumProjectMarkers(id)
	if ok and is_region then
		reaper.GetSet_LoopTimeRange(true, false, start_pos, end_pos, false)
		return true
	end
	return false
end

---@param search_name string
---@param forward boolean
---@return MediaTrack | nil
function utils.getMatchedTrack(search_name, forward)
	if not search_name then
		return nil
	end

	local current_track = reaper.GetSelectedTrack(0, 0)
	local start_i = 0
	if current_track then
		start_i = reaper.GetMediaTrackInfo_Value(current_track, "IP_TRACKNUMBER") - 1
	end

	local num_tracks = reaper.GetNumTracks()
	local tracks_searched = 1
	local next_track_i = start_i
	while tracks_searched < num_tracks do
		if forward == true then
			next_track_i = next_track_i + 1
		else
			next_track_i = next_track_i - 1
		end

		local track = reaper.GetTrack(0, next_track_i)
		if not track then
			if forward == true then
				next_track_i = -1
			else
				next_track_i = num_tracks
			end
		else
			local _, current_name = reaper.GetTrackName(track, "")
			local has_no_name = current_name:match("Track ([0-9]+)", 1)
			current_name = current_name:lower()
			tracks_searched = tracks_searched + 1
			if not has_no_name and current_name:match(search_name:lower()) then
				return track
			end
		end
	end

	return nil
end

function utils.getTrackPosition()
	local last_touched_track = reaper.GetLastTouchedTrack()
	if last_touched_track then
		local index = reaper.GetMediaTrackInfo_Value(last_touched_track, "IP_TRACKNUMBER") - 1
		return index
	end
	return 0
end

---@return table<number, MediaTrack>
function utils.getSelectedTracks()
	local selected_tracks = {}
	local n_tracks = reaper.CountSelectedTracks()
	for i = 0, reaper.CountSelectedTracks() - 1 do
		local track = reaper.GetSelectedTrack(0, i)
		selected_tracks[i + 1] = track
	end
	return selected_tracks
end

---@param indices table<number, number>
function utils.setTrackSelection(indices)
	local ScrollToSelectedTracks = 40913
	utils.unselectTracks()
	if indices then
		for _, track_index in ipairs(indices) do
			local track = reaper.GetTrack(0, track_index)
			if track then
				reaper.SetTrackSelected(track, true)
			end
		end
		reaper.Main_OnCommand(ScrollToSelectedTracks, 0)
	end
end

---@param pos number
function utils.scrollToPosition(pos)
	local current_position = reaper.GetCursorPosition()
	reaper.SetEditCurPos(pos, true, false)
	reaper.SetEditCurPos(current_position, false, false)
end

---@param index number
function utils.setCurrentTrack(index)
	local previously_selected = utils.getSelectedTrackIndices()
	local previous_position = utils.getTrackPosition()

	local track = reaper.GetTrack(0, index)
	if track then
		reaper.SetOnlyTrackSelected(track)
		local SetFirstSelectedAsLastTouched = 40914
		reaper.Main_OnCommand(SetFirstSelectedAsLastTouched, 0)

		local new_selection = previously_selected
		if previous_position and new_selection then
			for i, selected_track_i in ipairs(new_selection) do
				if selected_track_i == previous_position then
					table.remove(new_selection, i)
				end
			end
		end
		table.insert(new_selection, index)
		utils.setTrackSelection(new_selection)
	end
end

function utils.unselectAllButLastTouchedTrack()
	local last_touched_i = utils.getTrackPosition()
	if last_touched_i then
		local track = reaper.GetTrack(0, last_touched_i)
		if track then
			reaper.SetOnlyTrackSelected(track)
		end
	end
end

---@return table<number, number>
function utils.getSelectedTrackIndices()
	local selected_tracks = utils.getSelectedTracks()
	local selected_track_indices = {}
	for i, track in ipairs(selected_tracks) do
		selected_track_indices[i] = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
	end
	return selected_track_indices
end

function utils.unselectTracks()
	for i, track in ipairs(utils.getSelectedTracks()) do
		reaper.SetTrackSelected(track, false)
	end
end

---comment
---@param track MediaTrack
---@return table<number, MediaItem>
function utils.getSelectedItemsInTrack(track)
	---@type MediaItem
	local items = {}
	-- Get the number of selected items in the track
	local numItems = reaper.CountTrackMediaItems(track)

	-- Iterate over the items in the track
	for i = 0, numItems - 1 do
		-- Get the item at index i
		local item = reaper.GetTrackMediaItem(track, i)

		-- Check if the item is selected
		if reaper.IsMediaItemSelected(item) then
			table.insert(items, item)
		end
	end
	return items
end

---@param item MediaItem
---@param db number
function utils.nudgeItemVolume(item, db)
	local it_vol = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
	reaper.SetMediaItemInfo_Value(item, 'D_VOL', it_vol * 10 ^ (0.05 * db))
	reaper.UpdateItemInProject(item)
end

---@param item MediaItem
---@param track MediaTrack
---@param position number
---@return MediaItem
function utils.CopyMediaItemToTrack(item, track, position)
	local _, chunk = reaper.GetItemStateChunk(item, "", false)
	chunk = chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
	local new_item = reaper.AddMediaItemToTrack(track)
	reaper.PreventUIRefresh(1)
	reaper.SetItemStateChunk(new_item, chunk, false)
	reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", position)
	reaper.PreventUIRefresh(-1)
	return new_item
end

---@param cb fun(item: MediaItem, track: MediaTrack) nil
function utils.cycleSelectedItemsInSelectedTracks(cb)
	local tracks = utils.getSelectedTracks()
	for i = 1, #tracks do
		local track = tracks[i]

		local items = utils.getSelectedItemsInTrack(track)
		for _, item in ipairs(items) do
			cb(item, track)
		end
	end
end

---@param cb fun(item: MediaItem) nil
function utils.cycleSelectedItems(cb)
	local items = reaper.CountSelectedMediaItems(0)
	for i = 0, items - 1 do
		local item = reaper.GetSelectedMediaItem(0, i)
		cb(item)
	end
end

---@param cb fun(track: MediaTrack) nil
function utils.cycleSelectedTracks(cb)
	local tracks = utils.getSelectedTracks()
	for i = 1, #tracks do
		local track = tracks[i]
		cb(track)
	end
end

---@param tracknumber number
function utils.getTrackIndex(tracknumber)
	local trackCount = reaper.CountTracks(0) -- Get the total number of tracks in the project

	for i = 0, trackCount - 1 do
		local t = reaper.GetTrack(0, i)
		if t then
			local cur_tr_num = reaper.GetMediaTrackInfo_Value(t, "IP_TRACKNUMBER")
			if cur_tr_num == tracknumber then
				return i
			end
		end
	end
	return nil
end

return utils
