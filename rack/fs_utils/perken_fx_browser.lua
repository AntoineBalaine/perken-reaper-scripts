local os           = reaper.GetOS()
local os_separator = package.config:sub(1, 1)
local info         = debug.getinfo(1, "S")
local source       = info.source:match(".*rack" .. os_separator):sub(2)
package.path       = package.path .. ";" .. source .. "?.lua"                  ---FIXME remove this one integrated
---@type string
CurrentDirectory   = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
local IniParse     = require("parsers.IniParse.IniParse")
local fx_browser   = {}


---parse the reaper-fxtags.ini file and return its contents:
--A list of categories and a list of developers,
--each containing their respective plugins
local function parseFXTags()
    ---@type table
    local parse = IniParse:parseFile(reaper.GetResourcePath() .. os_separator .. "reaper-fxtags.ini")
    ---expect `parse` to have two methods: category and developer
    assert(parse.category and parse.developer, "reaper-fxtags.ini is missing category or developer section")

    ---@type table<string, string[]>
    local categories = {}
    --each key in parse.category is the name of a plugin
    --so we're having to iterate all the plugins to find the list of categories
    for plugin, category in pairs(parse.category) do
        table.insert(categories, category)
        local current_cat = categories[category]
        if current_cat then
            table.insert(current_cat, plugin)
        else
            categories[category] = { plugin }
        end
    end

    --same for developers: each key is a plugin and the value is the developer
    --so we're having to iterate all the plugins to find the list of developers
    ---@type table<string, string[]>
    local developers = {}
    for plugin, developer in pairs(parse.developer) do
        table.insert(developers, developer)
        local current_cat = developers[developer]
        if current_cat then
            table.insert(current_cat, plugin)
        else
            developers[developer] = { plugin }
        end
    end
    return categories, developers
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

---@return FX[] plugins list
---@return table<string, string[]> categories
---@return table<string, string[]> developers
function fx_browser.GenerateFxList()
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
            goto continue
        end
        local fx = parseFX(name, ident)
        if fx then
            table.insert(fx)
        end
        ::continue::
    end

    local rv, categories, developers = pcall(parseFXTags)
    if not rv then
        categories = {} ---@type table<string, string[]>
        developers = {} ---@type table<string, string[]>
    end
    -- ParseCustomCategories()
    -- ParseFavorites()
    -- local FX_CHAINS = ParseFXChains()
    -- if #FX_CHAINS ~= 0 then
    --     fx_browser.CAT[#fx_browser.CAT + 1] = { name = "FX CHAINS", list = FX_CHAINS }
    -- end
    -- local TRACK_TEMPLATES = ParseTrackTemplates()
    -- if #TRACK_TEMPLATES ~= 0 then
    --     fx_browser.CAT[#fx_browser.CAT + 1] = { name = "TRACK TEMPLATES", list = TRACK_TEMPLATES }
    -- end
    -- AllPluginsCategory()

    return plugin_list, categories, developers
end

return fx_browser
