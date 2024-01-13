dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local ThemeReader = {}

---@class Theme
---@field colors ColorTable colors
---@field fonts table<string, string> fonts

---@alias ColorTable table<string, {description: string, color: integer}>

local info = debug.getinfo(1, "S")

local Os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. Os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
local theme_variable_descriptions = require("theme_variable_descriptions")

local theme_var_descriptions = theme_variable_descriptions.theme_var_descriptions
local theme_var_descriptions_sorted = theme_variable_descriptions.theme_var_descriptions_sorted

local theme_vars = {} ---@type string[] List of all theme variables
for _, entry in ipairs(theme_var_descriptions_sorted) do
    table.insert(theme_vars, entry.k)
end

---@param str string
---@param words string[]
---@param or_mode boolean
---@return boolean
local function FindByWordsInSTR(str, words, or_mode)
    local out = true
    str = str:lower()
    for _, word in ipairs(words) do
        if or_mode then
            if str:find(word) then
                out = true
                break
            else
                out = false
            end
        else
            if not str:find(word) then
                out = false
                break
            end
        end
    end
    return out
end

---@param str string
---@param char string
---@return string[]
local function SplitSTR(str, char)
    local t = {}
    local i = 0
    for line in str:gmatch("[^" .. char .. "]*") do
        i = i + 1
        t[i] = line:lower()
    end
    return t
end

---@param t string[]
---@param str string
---@param or_mode boolean
---@return string[] out
---@return string[] filtered_out
local function FilterTab(t, str, or_mode)
    if str == "" then return t, {} end
    local words = SplitSTR(str, " ")
    local out, filtered_out = {}, {}
    for _, v in ipairs(t) do
        if (theme_var_descriptions and theme_var_descriptions[v] and FindByWordsInSTR(theme_var_descriptions[v], words, or_mode)) or FindByWordsInSTR(v, words, or_mode) then
            table.insert(out, v)
        else
            table.insert(filtered_out, v)
        end
    end
    return out, filtered_out
end

--- Split file name
-- Returns the Path, Filename, and Extension as 3 values
---@param strfilename string
---@return string path
---@return string file_name
---@return string extension
local function splitFileName(strfilename)
    local path, file_name, extension = string.match(strfilename, "(.-)([^\\|/]-([^\\|/%.]+))$")
    file_name = string.match(file_name, ('(.+)%.(.+)'))
    return path, file_name, extension
end

---Read the theme from the provided file,
---and return a table containing its colors and fonts
---@param theme_path string
---@return Theme theme
function ThemeReader.readTheme(theme_path)
    -- local theme_is_zip = not reaper.file_exists(theme_path)
    local _, theme_name, _ = splitFileName(theme_path)
    local theme_prefix, theme_version_str = theme_name:match("(.+) %- Mod (%d+)")
    theme_prefix = theme_prefix or theme_name
    local theme_version_num = theme_version_str and tonumber(theme_version_str) or 0
    theme_version_num = theme_version_num + 1

    local modes_tab, items = FilterTab(theme_vars, "mode dm", true)
    -- K: theme variable name -> V: description
    ---@type ColorTable
    local colors = {}
    for var_name, description in ipairs(items) do
        local col = reaper.GetThemeColor(description, 0) -- NOTE: Flag doesn't seem to work (v6.78). Channel are swapped on MacOS and Linux.
        -- if os_sep == "/" then col = SwapINTrgba( col ) end -- in fact, better staus with channel swap cause at least it works
        colors[var_name] = { description = description, color = col }
    end

    --[[leaving this section for now]]
    -- local modes = {} ---@type table<string, string>
    -- for _, v in ipairs(modes_tab) do
    --     -- modes[v] = reaper.GetThemeColor(v,0) -- BUG: https://forum.cockos.com/showthread.php?t=251007
    --     local retval, val = reaper.BR_Win32_GetPrivateProfileString("color theme", v, -1, theme_path)
    --     modes[v] = val
    -- end

    --- TODO convert to enum
    local fonts_tab = { "lb_font", "lb_font2", "user_font0", "user_font1", "user_font2", "user_font3", "user_font4",
        "user_font5", "user_font6", "user_font7", "tl_font", "trans_font", "mi_font", "ui_img", "ui_img_path" }

    local fonts = {} ---@type table<string, string>
    for _, v in ipairs(fonts_tab) do
        local _, val = reaper.BR_Win32_GetPrivateProfileString("REAPER", v, -1, theme_path)
        fonts[v] = val
    end

    return { colors = colors, fonts = fonts }
end

---Get path of the current theme
---@return string
function ThemeReader.GetThemePath()
    local theme_path = reaper.GetLastColorThemeFile()
    if not theme_path or theme_path == "" then
        reaper.MB(
            "REAPER Bug (known issue): GetLastColorThemeFile returns invalid value.\nTry to change theme and switch back before running the script",
            "Error", 0)
    end
    return theme_path
end

---Create the ImGui context and setup the window size
---@return ImGui_Context
function ThemeReader.SetupImGui()
    local ctx = reaper.ImGui_CreateContext("Theme Viewer", reaper.ImGui_ConfigFlags_DockingEnable())
    reaper.ImGui_SetNextWindowSize(ctx, 710, 400, reaper.ImGui_Cond_FirstUseEver())
    return ctx
end

---A component that displays the theme variables
---It iterates through the list of colors in the theme and displays them
---@param ctx ImGui_Context
---@param theme Theme
function ThemeReader.Comp_ShowVars(ctx, theme)
    local colors = theme.colors
    for var_name, element in ipairs(colors) do
        local description, color = element.description, element.color
        reaper.ImGui_PushItemWidth(ctx, 92) -- Set max width of inputs
        if type(color) ~= "number" then
            reaper.ImGui_Text(ctx, "ounfound")
        else
            retval, edit = reaper.ImGui_ColorEdit3(ctx,
                description,
                reaper.ImGui_ColorConvertNative(color), reaper.ImGui_ColorEditFlags_DisplayHex())
        end

        reaper.ImGui_PopItemWidth(ctx) -- Restore max with of input
    end
end

---@param ctx ImGui_Context
---@param theme Theme
function ThemeReader.display(ctx, theme)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x0F0F0FFF) -- Black opaque background

    local imgui_visible, imgui_open = reaper.ImGui_Begin(ctx, "Theme Display", true,
        reaper.ImGui_WindowFlags_AlwaysVerticalScrollbar())
    if imgui_visible then
        ThemeReader.Comp_ShowVars(ctx, theme)
    end
    reaper.ImGui_PopStyleColor(ctx) -- Remove black opack background

    reaper.ImGui_End(ctx)
    if not imgui_open or reaper.ImGui_IsKeyPressed(ctx, 27) then
        reaper.ImGui_DestroyContext(ctx)
    else
        reaper.defer(function() ThemeReader.display(ctx, theme) end)
    end
end

local theme_path = ThemeReader.GetThemePath()
local theme = ThemeReader.readTheme(theme_path)
local ctx = ThemeReader.SetupImGui()
ThemeReader.display(ctx, theme)
