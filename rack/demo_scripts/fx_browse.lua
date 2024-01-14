---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-- EXAMPLE FOR IMPLEMENTING IN YOUR SCRIPTS
-- COPY PASTE CODE BELLOW INTO NEW SCRIPT
-- MAKE SURE THIS SCRIPT "Sexan_FX_Browser" IS IN SAME FOLDER AS YOUR MAIN SCRIPT
-- DO NOT UNCOMMENT CODE BELLOW (ONLY FOR STANDALONE TESTING PURPOSES)
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------


local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
require("Sexan_FX_Browser")

local r = reaper
local ctx = r.ImGui_CreateContext('FX INI PARSER')

-- USE ONLY NON CHACHING OR CACHING! NOT BOTH AT THE SAME TIME

--NON CACHING -- USE IF YOU WANT RESCAN ON EVERY SCRIPT STARTUP
--local FX_LIST_TEST, CAT_TEST = GetFXTbl()

--CACHIN TO FILE - USE IF YOU WANT TO SCAN ONLY ONCE THEN USE THAT TXT FILE FOR FASTER LOADS
local FX_LIST_TEST, CAT_TEST = ReadFXFile()
if not FX_LIST_TEST or not CAT_TEST then
    FX_LIST_TEST, CAT_TEST = MakeFXFiles()
end
--CACHIN TO FILE

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local tsort = table.sort
function SortTable(tab, val1, val2)
    tsort(tab, function(a, b)
        if (a[val1] < b[val1]) then
            -- primary sort on position -> a before b
            return true
        elseif (a[val1] > b[val1]) then
            -- primary sort on position -> b before a
            return false
        else
            -- primary sort tied, resolve w secondary sort on rank
            return a[val2] < b[val2]
        end
    end)
end

local old_t = {}
local old_filter = ""
local function Filter_actions(filter_text)
    if old_filter == filter_text then return old_t end
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    if filter_text == "" or not filter_text then return t end
    for i = 1, #FX_LIST_TEST do
        local name = FX_LIST_TEST[i]:lower() --:gsub("(%S+:)", "")
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then t[#t + 1] = { score = FX_LIST_TEST[i]:len() - filter_text:len(), name = FX_LIST_TEST[i] } end
    end
    if #t >= 2 then
        SortTable(t, "score", "name") -- Sort by key priority
    end
    old_t = t
    old_filter = filter_text
    return t
end

local function SetMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

local FILTER = ''
local function FilterBox()
    local MAX_FX_SIZE = 300
    r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
    _, FILTER = r.ImGui_InputTextWithHint(ctx, '##input', "SEARCH FX", FILTER)
    local filtered_fx = Filter_actions(FILTER)
    local filter_h = #filtered_fx == 0 and 0 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
    ADDFX_Sel_Entry = SetMinMax(ADDFX_Sel_Entry or 1, 1, #filtered_fx)
    if #filtered_fx ~= 0 then
        if r.ImGui_BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
            for i = 1, #filtered_fx do
                if r.ImGui_Selectable(ctx, filtered_fx[i].name, i == ADDFX_Sel_Entry) then
                    r.TrackFX_AddByName(TRACK, filtered_fx[i].name, false, -1000 - r.TrackFX_GetCount(TRACK))
                    r.ImGui_CloseCurrentPopup(ctx)
                    LAST_USED_FX = filtered_fx[i].name
                end
            end
            r.ImGui_EndChild(ctx)
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            r.TrackFX_AddByName(TRACK, filtered_fx[ADDFX_Sel_Entry].name, false, -1000 - r.TrackFX_GetCount(TRACK))
            LAST_USED_FX = filtered_fx[filtered_fx[ADDFX_Sel_Entry].name]
            ADDFX_Sel_Entry = nil
            FILTER = ''
            r.ImGui_CloseCurrentPopup(ctx)
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
        end
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        FILTER = ''
        r.ImGui_CloseCurrentPopup(ctx)
    end
    return #filtered_fx ~= 0
end

local function DrawFxChains(tbl, path)
    local extension = ".RfxChain"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                if TRACK then
                    r.TrackFX_AddByName(TRACK, table.concat({ path, os_separator, tbl[i], extension }), false,
                        -1000 - r.TrackFX_GetCount(TRACK))
                end
            end
        end
    end
end

local function LoadTemplate(template, replace)
    local track_template_path = r.GetResourcePath() .. "/TrackTemplates" .. template
    if replace then
        local chunk = GetFileContext(track_template_path)
        r.SetTrackStateChunk(TRACK, chunk, true)
    else
        r.Main_openProject(track_template_path)
    end
end

local function DrawTrackTemplates(tbl, path)
    local extension = ".RTrackTemplate"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                local cur_path = table.concat({ path, os_separator, tbl[i].dir })
                DrawTrackTemplates(tbl[i], cur_path)
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                if TRACK then
                    local template_str = table.concat({ path, os_separator, tbl[i], extension })
                    LoadTemplate(template_str)       -- ADD NEW TRACK FROM TEMPLATE
                    LoadTemplate(template_str, true) -- REPLACE CURRENT TRACK WITH TEMPLATE
                end
            end
        end
    end
end

local function DrawItems(tbl, main_cat_name)
    for i = 1, #tbl do
        if r.ImGui_BeginMenu(ctx, tbl[i].name) then
            for j = 1, #tbl[i].fx do
                if tbl[i].fx[j] then
                    local name = tbl[i].fx[j]
                    if main_cat_name == "ALL PLUGINS" and tbl[i].name ~= "INSTRUMENTS" then
                        -- STRIP PREFIX IN "ALL PLUGINS" CATEGORIES EXCEPT INSTRUMENT WHERE THERE CAN BE MIXED ONES
                        name = name:gsub("^(%S+:)", "")
                    elseif main_cat_name == "DEVELOPER" then
                        -- STRIP SUFFIX (DEVELOPER) FROM THESE CATEGORIES
                        name = name:gsub(' %(' .. Literalize(tbl[i].name) .. '%)', "")
                    end
                    if r.ImGui_Selectable(ctx, name) then
                        if TRACK then
                            r.TrackFX_AddByName(TRACK, tbl[i].fx[j], false,
                                -1000 - r.TrackFX_GetCount(TRACK))
                            LAST_USED_FX = tbl[i].fx[j]
                        end
                    end
                end
            end
            r.ImGui_EndMenu(ctx)
        end
    end
end

function Frame()
    local search = FilterBox()
    if search then return end
    for i = 1, #CAT_TEST do
        if r.ImGui_BeginMenu(ctx, CAT_TEST[i].name) then
            if CAT_TEST[i].name == "FX CHAINS" then
                DrawFxChains(CAT_TEST[i].list)
            elseif CAT_TEST[i].name == "TRACK TEMPLATES" then
                DrawTrackTemplates(CAT_TEST[i].list)
            else
                DrawItems(CAT_TEST[i].list, CAT_TEST[i].name)
            end
            r.ImGui_EndMenu(ctx)
        end
    end
    if r.ImGui_Selectable(ctx, "CONTAINER") then
        r.TrackFX_AddByName(TRACK, "Container", false,
            -1000 - r.TrackFX_GetCount(TRACK))
        LAST_USED_FX = "Container"
    end
    if r.ImGui_Selectable(ctx, "VIDEO PROCESSOR") then
        r.TrackFX_AddByName(TRACK, "Video processor", false,
            -1000 - r.TrackFX_GetCount(TRACK))
        LAST_USED_FX = "Video processor"
    end
    if LAST_USED_FX then
        if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then
            r.TrackFX_AddByName(TRACK, LAST_USED_FX, false,
                -1000 - r.TrackFX_GetCount(TRACK))
        end
    end
end

function Main()
    TRACK = r.GetSelectedTrack(0, 0)
    local visible, open = r.ImGui_Begin(ctx, 'FX INI PARSER', true)
    if visible then
        if TRACK then
            --UPDATE FX CHAINS (WE DONT NEED TO RESCAN EVERYTHING IF NEW CHAIN WAS CREATED BY SCRIPT)
            if WANT_REFRESH then
                WANT_REFRESH = nil
                UpdateChainsTrackTemplates(CAT)
            end
            -- RESCAN FILE LIST
            if r.ImGui_Button(ctx, "RESCAN PLUGIN LIST") then
                FX_LIST_TEST, CAT_TEST = MakeFXFiles()
            end
            Frame()
        else
            reaper.ImGui_Text(ctx, "SELECT TRACK")
        end
        r.ImGui_End(ctx)
    end
    if open then
        r.defer(Main)
    end
end

r.defer(Main)
