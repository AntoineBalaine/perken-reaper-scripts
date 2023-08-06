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

local src = {}
src.name = "Insert matching track templates"
src.template_dir = reaper.GetResourcePath() .. "/" .. "TrackTemplates"
src.sample_name_pattern = "^.+[/\\](.+)%..+$"

local function getMediaBrowserSelection()
  local t = {}

  local title = reaper.JS_Localize("Media Explorer", "common")
  local hWnd = reaper.JS_Window_Find(title, true)
  if hWnd == nil then return end

  local file_ListView = reaper.JS_Window_FindChildByID(hWnd, 0x3E9)
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(file_ListView)
  if sel_count == 0 then return end

  local index = 0
  -- get selected items in 1st column of ListView.
  for ndx in string.gmatch(sel_indexes, '[^,]+') do
    local name = reaper.JS_ListView_GetItemText(file_ListView, tonumber(ndx), 0)

    index = index + 1
    t[index] = name:match("(.+)%..+$") -- remove extension from file names
  end
  if #t > 0 then                       -- files & folders
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

    if not path then return end

    return i + 1, path, start_path .. "/" .. path
  end
end

local function getFolderList(path, tbl)
  tbl = tbl or { [1] = path }

  for i, v in getPathStructure(path, 0) do
    if v:find("%.") then goto SKIP end

    local path = path .. "/" .. v
    tbl[#tbl + 1] = path

    tbl = getFolderList(path, tbl)

    ::SKIP::
  end

  return tbl
end

local function getFileList(path)
  local folders = getFolderList(path)

  local files = {}

  for f = 1, #folders do
    local path = folders[f]

    for i, v in getPathStructure(path, 1) do
      if v:find("^%.") then goto SKIP end

      local path = path .. "/" .. v

      files[#files + 1] = path

      ::SKIP::
    end
  end

  return files
end

local function getTemplateList(tbl)
  local templates = {}

  for i = 1, #tbl do
    local path = tbl[i]

    if path:lower():find("rtracktemplate$") then
      table.insert(
        templates,
        { path = path, name = path:match(src.sample_name_pattern) }
      )
    end
  end

  return templates
end

local function setLastTouchedTrack()
  if src.last_tr_set then return end

  src.last_tr_set = true

  local tr_cnt = reaper.CountTracks(0)
  local last_tr_idx = tr_cnt - 1
  local last_tr = reaper.GetTrack(0, last_tr_idx)

  reaper.SetOnlyTrackSelected(last_tr)
end

local function processTemplate(sample_name)
  for i = 1, #src.template_list do
    local template_name = src.template_list[i].name
    if sample_name == template_name then
      local path = src.template_list[i].path

      setLastTouchedTrack()

      reaper.Main_openProject(path)
    end
  end
end

local function insertTemplates()
  local insert_list = {}

  reaper.Undo_BeginBlock2(0)
  for n = 1, #src.sample_name_list do
    local sample_name = src.sample_name_list[n]

    processTemplate(sample_name)
  end
  reaper.Undo_EndBlock2(0, src.name, -1)
end

function Main()
  src.file_list = getFileList(src.template_dir)

  if not next(src.file_list) then return end

  src.template_list = getTemplateList(src.file_list)

  if not next(src.template_list) then return end
  src.sample_name_list = getMediaBrowserSelection()
  if not src.sample_name_list or not next(src.sample_name_list) then
    return
  else
    insertTemplates()
  end
end

Main()
