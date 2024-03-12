--[[
parse the list of fx in reaper-fxtags.ini for use in the fx_browser
]]
local os           = reaper.GetOS()
local os_separator = package.config:sub(1, 1)
-- local info         = debug.getinfo(1, "S")
-- local source       = info.source:match(".*rack" .. os_separator):sub(2)
-- package.path       = package.path .. ";" .. source .. "?.lua"                  ---FIXME remove this once integrated
-- ---@type string
-- CurrentDirectory   = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
local fx_browser   = {}
local IniParse     = require("parsers.Iniparse.IniParse")
local Table        = require("helpers.table")

---parse the reaper-fxtags.ini file and return its contents:
--A list of categories and a list of developers,
--each containing their respective plugins
--
--This function can fail, so make sure to call with `pcall(parseFXTags)`
local function parseFXTags()
    ---@type table|nil
    local parse = IniParse:parse_file(reaper.GetResourcePath() .. os_separator .. "reaper-fxtags.ini")
    ---expect `parse` to have two methods: category and developer
    assert(parse and parse.category and parse.developer, "reaper-fxtags.ini is missing category or developer section")

    ---@type table<string, string[]>
    local categories = {}
    --each key in parse.category is the name of a plugin
    --so we're having to iterate all the plugins to find the list of categories
    for plugin, category_string in pairs(parse.category) do
        --if the category contains a pipe, this plugin belongs to multiple categories
        local multiple_categories = string.find(category_string, "|")
        local category_table = {} ---@type string[]
        -- put the list of categories contained in category_string into category_table
        if multiple_categories then
            for category_type in category_string:gmatch('[^%|]+') do
                table.insert(category_table, category_type)
            end
        else
            category_table = { category_string }
        end
        -- iterate category_table and add the plugin to each category
        for _, category in ipairs(category_table) do
            if categories[category] then
                table.insert(categories[category], plugin)
            else
                categories[category] = { plugin }
            end
        end
    end
    ---@type {[1]: string, [2]: string[]}[]
    local categories_sorted = {}
    for dev, plugins in pairs(categories) do
        table.insert(categories_sorted, { dev, plugins })
    end
    --same for developers: each key is a plugin and the value is the developer
    --so we're having to iterate all the plugins to find the list of developers
    ---@type table<string, string[]>
    local developers = {}
    for plugin, developer in pairs(parse.developer) do
        local cur_dev = developers[developer]
        if cur_dev then
            table.insert(developers[developer], plugin)
        else
            developers[developer] = { plugin }
        end
    end
    ---@type {[1]: string, [2]: string[]}[]
    local developers_sorted = {}
    for dev, plugins in pairs(developers) do
        table.insert(developers_sorted, { developer = dev, plugins = plugins })
    end
    return {
        categories = categories,
        developers = developers,
        categories_sorted = categories_sorted,
        developers_sorted = developers_sorted
    }
end


---@enum FxFolderEntryType
local FxFolderEntryType = {
    lv2 = "lv2",
    jsfx = "jsfx",
    vst = "vst",
    external_editor = "external_editor",
    video_processor = "video_processor",
    au = "au",
    clap = "clap",
    fx_chain = "fx_chain",
    smartfolder = "smartfolder",
}

---@class FxFolderEntry
---@field type FxFolderEntryType
---@field path string

---Each folder section in reaper-fxfolders.ini follows the format:
---```ini
---Nb=1300 #the number of entries in the current folder
---Item0=VST:ReaComp (Cockos)
---Type0=1000 # the type for the first entry
---```
---This function reads the folder section and returns a list of entries
---each containing its type and path.
---
---For types enum, see `FxFolderEntryType`
---@see FxFolderEntryType
---@param folder table<string, string>|nil
---@return FxFolderEntry[]|nil
local function parseFolder(folder)
    if not folder then
        return
    end

    ---@type FxFolderEntry[]
    local fx_in_folder = {}
    -- property "Nb" exists in the folder section of reaper-fxfolders.ini
    local length = tonumber(folder.Nb) or 0
    for i = 0, length - 1 do
        local cur_item = {}
        local itemPrefix = "Item" .. i
        local typePrefix = "Type" .. i
        local plugin_type = folder[typePrefix]
        local itemPath = folder[itemPrefix]

        if plugin_type == "1" then           -- lv2
            cur_item.type = FxFolderEntryType.lv2
        elseif plugin_type == "2" then       -- jsfx
            cur_item.type = FxFolderEntryType.jsfx
        elseif plugin_type == "3" then       -- vst
            cur_item.type = FxFolderEntryType.vst
        elseif plugin_type == "4" then       -- external_editor
            cur_item.type = FxFolderEntryType.external_editor
        elseif plugin_type == "6" then       -- video_processor
            cur_item.type = FxFolderEntryType.video_processor
        elseif plugin_type == "5" then       -- au
            cur_item.type = FxFolderEntryType.au
        elseif plugin_type == "7" then       -- clap
            cur_item.type = FxFolderEntryType.clap
        elseif plugin_type == "1000" then    --rfx_chain
            cur_item.type = FxFolderEntryType.rfx_chain
        elseif plugin_type == "1048576" then -- smartfolder
            cur_item.type = FxFolderEntryType.smartfolder
        end
        cur_item.path = itemPath
        table.insert(fx_in_folder, cur_item)
    end
end

---@class FxFolder
---@field name string
---@field id string
---@field fx FxFolderEntry[]

---Parse custom categories found in reaper-fxfolders.ini
--
---This includes the list of user-defined fx-categories
---and the list of user-defined folders
---@return {categories: table<string, string[]>, folders: FxFolder[]}
local function parseCustomCategories()
    local fxfolders_path = reaper.GetResourcePath() .. os_separator .. "reaper-fxfolders.ini"
    ---@type table|nil
    local parse = IniParse:parse_file(fxfolders_path)

    assert(parse and parse.categories and parse.category and parse.Folders,
        "reaper-fxfolders.ini is missing some sections")

    local categories = {} ---@type table<string, string[]>
    for plugin, category in pairs(parse.category) do
        if categories[category] then
            table.insert(categories[category], plugin)
        else
            categories[category] = { plugin }
        end
    end
    -- remove parse.categories and parse.category
    parse.categories = nil
    parse.category = nil
    --[[
the Folders section indicates the setup of folders:
[Folders]
Id0=0
Name0=Favorites
NbFolders=1
    ]]
    ---@type FxFolder[]
    local folders = {}
    for i = 0, parse.Folders.NbFolders - 1 do
        local folder = parse.Folders["Folder" .. i]
        local name = parse.Folders["Name" .. i]
        local id = parse.Folders["Id" .. i]
        local fx = parseFolder(folder)
        if fx then
            ---@type FxFolder
            local mapped_folder = { name = name, id = id, fx = fx }
            table.insert(folders, mapped_folder)
        end
    end

    ---@type {[1]: string, [2]: string[]}[]
    local categories_sorted = {}
    for category, plugins in Table.sortNamedTable(categories) do
        table.insert(categories_sorted, { category, plugins })
    end

    table.sort(folders, function(a, b) return a.name:lower() < b.name:lower() end)
    return {
        categories,
        folders,
        categories_sorted,
    }
end

---@class FX
---@field name string
---@field id string
---@field type FxType

---@enum FxType
local FxType = {
    VST = "VST",
    VSTi = "VSTi:",
    VST3 = "VST3:",
    VST3i = "VST3i:",
    JS = "JS:",
    AU = "AU:",
    AUi = "AUi:",
    CLAP = "CLAP:",
    CLAPi = "CLAPi:",
    LV2 = "LV2:",
    LV2i = "LV2i:",
    Container = "Container",
    VideoProcessor = "Video processor",
}

---@param name string
---@param ident string
---@return FX|nil
local function parseFX(name, ident)
    local fx = {}
    fx.name = name
    fx.id = ident
    if string.find(name, "^VST:") then
        fx.type = FxType.VST
    elseif string.find(name, "^VSTi:") then
        fx.type = FxType.VSTi
    elseif string.find(name, "^VST3:") then
        fx.type = FxType.VST3
    elseif string.find(name, "^VST3i:") then
        fx.type = FxType.VST3i
    elseif string.find(name, "^JS:") then
        fx.type = FxType.JS
    elseif string.find(name, "^AU:") then
        fx.type = FxType.AU
    elseif string.find(name, "^AUi:") then
        fx.type = FxType.AUi
    elseif string.find(name, "^CLAP:") then
        fx.type = FxType.CLAP
    elseif string.find(name, "^CLAPi:") then
        fx.type = FxType.CLAPi
    elseif string.find(name, "^LV2:") then
        fx.type = FxType.LV2
    elseif string.find(name, "^LV2i:") then
        fx.type = FxType.LV2i
    else
        return nil
    end
    return fx
end

local function parsePluginList()
    local plugin_list = {} ---@type FX[]
    table.insert(plugin_list, { name = "Container", id = "Container", type = FxType.Container })
    table.insert(plugin_list, { name = "Video processor", id = "Video processor", type = FxType.VideoProcessor })

    for i = 0, math.huge do
        ---@type boolean
        local retval,
        ---@type string
        name,
        ---@type string
        ident = reaper.EnumInstalledFX(i)
        if not retval then
            break -- If no more plugins are found, exit the loop
        end
        local fx = parseFX(name, ident)
        if fx then
            table.insert(plugin_list, fx)
        end
    end

    table.sort(plugin_list, function(a, b) return a.name:lower() < b.name:lower() end)
    return plugin_list
end

---@class Directory
---@field path string
---@field subdirs? Directory[]
---@field files? string[]

---@param path string
---@param file_extension string
---@return Directory
local function directoryRead(path, file_extension)
    ---@type Directory
    local directory = { path = path }
    for index = 0, math.huge do
        local subdir = reaper.EnumerateSubdirectories(path, index)
        if not subdir then break end -- break if no more sub-directories are found
        local subdir_path = path .. os_separator .. subdir
        if directory.subdirs then
            table.insert(directory.subdirs, directoryRead(subdir_path, file_extension))
        else
            directory.subdirs = { directoryRead(subdir_path, file_extension) }
        end
    end

    local files = {}
    for index = 0, math.huge do
        local file = reaper.EnumerateFiles(path, index)
        if not file then break end -- break if no more files are found
        if file:find(file_extension, nil, true) then
            local file_name = file:gsub(file_extension, "")
            if files then
                table.insert(files, file_name)
            else
                files = { file_name }
            end
        end
    end
    table.sort(files, function(a, b) return a:lower() < b:lower() end)
    directory.files = files
    return directory
end

local function parseFxChains()
    local fxChainsPath = reaper.GetResourcePath() .. os_separator .. "FXChains"
    return directoryRead(fxChainsPath, ".RfxChain")
end

local function parseTrackTemplates()
    local trackTemplatesPath = reaper.GetResourcePath() .. os_separator .. "TrackTemplates"
    return directoryRead(trackTemplatesPath, ".RTrackTemplate")
end

---sort plugins by type, such as {VST = {plugin1, plugin2}, JS = {plugin3}}
---@param plugin_list FX[]
local function to_plugins_by_type(plugin_list)
    ---@class PluginsByType
    ---@field VST? FX[]
    ---@field VSTi? FX[]
    ---@field VST3? FX[]
    ---@field VST3i? FX[]
    ---@field JS? FX[]
    ---@field AU? FX[]
    ---@field AUi? FX[]
    ---@field CLAP? FX[]
    ---@field CLAPi? FX[]
    ---@field LV2? FX[]
    ---@field LV2i? FX[]
    ---@field Container? FX[]
    ---@field VideoProcessor? FX[]
    local plugins_by_type = {}

    for _, plugin in ipairs(plugin_list) do
        if plugins_by_type[plugin.type] then
            table.insert(plugins_by_type[plugin.type], plugin)
        else
            plugins_by_type[plugin.type] = { plugin }
        end
    end
    return plugins_by_type
end


---@return FX[] plugin_list
---@return { categories: table<string, string[]>, developers: table<string, string[]> } fx_tags
---@return { categories: table<string, string[]>, folders: FxFolder[] } custom_categories
---@return Directory fx_chains
---@return Directory track_templates
---@return PluginsByType plugin_by_type
function fx_browser.GenerateFxList()
    local plugin_list = parsePluginList()
    local rv, fx_tags = pcall(parseFXTags)
    if not rv then
        fx_tags = {
            categories = {}, ---@type table<string, string[]>
            developers = {}, ---@type table<string, string[]>
            categories_sorted = {}, ---@type {[1]: string, [2]: string[]}[]
            developers_sorted = {} ---@type {[1]: string, [2]: string[]}[]
        }
    end
    local retval, custom_categories = pcall(parseCustomCategories)
    if not retval then
        custom_categories = {
            categories = {}, ---@type table<string, string[]>
            folders = {}, ---@type FxFolder[]
            categories_sorted = {} ---@type {[1]: string, [2]: string[]}[]
        }
    end
    local fx_chains = parseFxChains()
    local track_templates = parseTrackTemplates()
    local plugin_by_type = to_plugins_by_type(plugin_list)
    return plugin_list, fx_tags, custom_categories, fx_chains, track_templates, plugin_by_type
end

return fx_browser
