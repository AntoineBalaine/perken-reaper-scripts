  -- @noindex
  
--[[
Description: Insert matching track templates
About: Insert track templates that match media explorer's selected items
Version: 2.0
Author: Neutronic, mod by Perken
License: perpetual commercial
Links:
  Neutronic's REAPER forum profile https://forum.cockos.com/member.php?u=66313
Changelog:
  + pull match from media explorer selection
  + init realease
--]]
reaper = reaper
local src = {}
src.name = "Insert matching fx chains"
src.fxchains_dir = reaper.GetResourcePath() .. "/" .. "FXChains" ---@type string
src.sample_name_pattern = "^.+[/\\](.+)%..+$"

local function getMediaBrowser()
	local title = reaper.JS_Localize("Media Explorer", "common")
	return reaper.JS_Window_Find(title, true)
end

---@return {number: string} | nil
local function getMediaBrowserSelection()
	local t = {}

	local hWnd = getMediaBrowser()
	if hWnd == nil then
		return
	end

	local file_ListView = reaper.JS_Window_FindChildByID(hWnd, 0x3E9)
	local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(file_ListView)
	if sel_count == 0 then
		return
	end

	local index = 0
	-- get selected items in 1st column of ListView.
	for ndx in string.gmatch(sel_indexes, "[^,]+") do
		local name = reaper.JS_ListView_GetItemText(file_ListView, tonumber(ndx), 0)

		index = index + 1
		t[index] = name:gsub("%..+$", "") -- remove extension from file names
	end
	if #t > 0 then                    -- files & folders
		return t
	else
		return nil
	end
end

local function getPathStructure(start_path, type, init)
	return function(_, i)
		local f = type == 0 and reaper.EnumerateSubdirectories or reaper.EnumerateFiles
		local i = i or init or 0
		local path = f(start_path, i)

		if not path then
			return
		end

		return i + 1, path, start_path .. "/" .. path
	end
end

local function getFolderList(path, tbl)
	tbl = tbl or { [1] = path }

	for i, v in getPathStructure(path, 0) do
		if v:find("%.") then
			goto SKIP
		end

		local path = path .. "/" .. v
		tbl[#tbl + 1] = path

		tbl = getFolderList(path, tbl)

		::SKIP::
	end

	return tbl
end

---@param path string
---@return {number: string}
local function getFileList(path)
	local folders = getFolderList(path)

	local files = {}

	for f = 1, #folders do
		local path = folders[f]

		for i, v in getPathStructure(path, 1) do
			if v:find("^%.") then
				goto SKIP
			end

			local path = path .. "/" .. v

			files[#files + 1] = path

			::SKIP::
		end
	end

	return files
end

---@param tbl {number: string}
---@return {number: {path: string, name: string}}
local function getTemplateList(tbl)
	---@type {number:  {path: string, name: string} }
	local templates = {}

	for i = 1, #tbl do
		local path = tbl[i]

		if path:lower():find("rfxchain") then
			table.insert(templates, { path = path, name = path:match(src.sample_name_pattern) })
		end
	end

	return templates
end

---@param cb function
local function cycleSelectedTracks(cb)
	local sel_tracks = reaper.CountSelectedTracks(0)
	if sel_tracks == 0 then
		return
	end

	for i = 0, sel_tracks - 1 do
		local track = reaper.GetSelectedTrack(0, i) ---@type MediaTrack
		cb(track)
	end
end

---@param track MediaTrack
---@param chain_name string
local function setVstiOrChainToTrackName(track, chain_name)
	local vsti_id = reaper.TrackFX_GetInstrument(track)
	local retval, fx_name = reaper.TrackFX_GetFXName(track, vsti_id, "")
	local retval, presetname = reaper.TrackFX_GetPreset(track, vsti_id, "")
	if retval ~= 0 then
		local track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", presetname, true)
	else
		local track_name_retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", chain_name, true)
	end
end

---@param sample_name string
local function processTemplate(sample_name)
	local foundMatch = false
	for i = 1, #src.template_list do
		local template_name = src.template_list[i].name ---@type string
		if sample_name == template_name then
			foundMatch = true
			local path = src.template_list[i].path

			--- select the last track so that the template is inserted at the bottom
			--- insert a new track, select it, and insert the chain there
			reaper.Main_OnCommand(40297, 0)                                 -- unselect all tracks
			reaper.Main_OnCommand(40001, 0)                                 -- insert new track
			reaper.Main_openProject(path)                                   -- insert chain
			reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS4"), 0) -- close all fx chains
			reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_WNCLS5"), 0) -- close all floating fx chains
			cycleSelectedTracks(function(track)
				setVstiOrChainToTrackName(track, sample_name)
			end)
			--- get first vsti preset name, if it doesn't have it, then get the fx chain name
			--- set track name to that.
			reaper.JS_Window_SetFocus(getMediaBrowser()) -- focus back to the media browser
		end
	end
	if foundMatch == false then
		local title = "Warning"
		local message = "Chain unfound."
		local messageType = 2 -- 2 displays a warning icon

		reaper.ShowMessageBox(message, title, messageType)
	end
end

local function insertTemplates()
	reaper.Undo_BeginBlock2(0)
	for n = 1, #src.sample_name_list do
		local sample_name = src.sample_name_list[n] ---@type string

		processTemplate(sample_name)
	end
	reaper.Undo_EndBlock2(0, src.name, -1)
end

function Main()
	src.file_list = getFileList(src.fxchains_dir)

	if not next(src.file_list) then
		return
	end

	src.template_list = getTemplateList(src.file_list)

	if not next(src.template_list) then
		return
	end
	src.sample_name_list = getMediaBrowserSelection()
	if not src.sample_name_list or not next(src.sample_name_list) then
		return
	else
		insertTemplates()
	end
end

Main()
