local layout_reader = {}
local serpent = require("lib.serpent")
local table_helpers = require("helpers.table")

---@param fx TrackFX
function layout_reader.stringify(fx)
    local displaySettings_clone = table_helpers.deepCopy(
        fx.displaySettings,
        nil,
        { "background_disabled", -- don't store these properties
            "background_offline",
            "borderColor",
            "title_Clr",
            "title_Width",
            "window_height",
            "labelButtonStyle",
            "_grid_color",
            "_grid_size",
            "_is_collapsed",
            "custom_Title",
            "_selected"

        })
    if fx.displaySettings.custom_Title and fx.displaySettings.custom_Title ~= "" then
        displaySettings_clone.custom_Title = fx.displaySettings.custom_Title
    end

    local params_clone = {}
    for _, param in ipairs(fx.display_params) do
        -- in the params,
        -- only store the details and display settings and the header info.
        -- Don't store the details.

        local param_clone = table_helpers.deepCopy(
            param,
            nil,
            { "display", "details", "_selected", "guid" })

        local display_settings_clone = table_helpers.deepCopy(
            param.details.display_settings,
            nil,
            { "component" })
        param_clone.display_settings = display_settings_clone
        table.insert(params_clone, param_clone)
    end


    local fx_mapped = {
        displaySettings = displaySettings_clone,
        display_params = params_clone
    }

    local block = serpent.block(fx_mapped, { comment = false })
    return block
end

local os_separator = package.config:sub(1, 1)
---@param project_directory string
---@param fx_name string
local function get_file_path(project_directory, fx_name)
    return project_directory .. os_separator .. "layouts" .. os_separator .. fx_name .. ".lua"
end

function layout_reader.save(fx)
    local block = layout_reader.stringify(fx)
    reaper.ShowConsoleMsg(block .. "\n")
    -- local file_path = get_file_path(fx.state.project_directory, fx.name)
    -- file = io.open(file_path, "w")
    -- file:write(block)
    -- file:close()
end

---@param file_path string
---@return boolean, table|nil
function layout_reader.read_layout(file_path)
    local file = io.open(file_path, "r")
    local read_table
    local success = false
    if file then
        local content = file:read("*a")
        success,
        ---@type table
        read_table = serpent.load(content)
        file:close()
    end
    return success, read_table
end

---pulled from serpent.lua,
---modded to set properties recursively,
---so we don't overwrite entire objects, only the properties that we've stored.
---@param a table
---@param b table
---@return table
local function merge(a, b)
    for k, v in pairs(b) do
        if a[k] and type(a[k]) == "table" and type(v) == "table" then
            merge(a[k], v)
        else
            a[k] = v
        end
    end
    return a
end

---@param fx TrackFX
---@return boolean success
---@return TrackFX|nil fx
function layout_reader.read_and_merge(fx)
    -- find the file path for the current fx name
    --[[
    if there is a layouts file,
    create the list of params,
    iterate the display settings and the fx params,
    perform validation on the layout's params
    and merge them
    --]]
    local file_path = get_file_path(fx.state.project_directory, fx.name)
    local success, read_table = layout_reader.read_layout(file_path)
    if not success or not read_table then
        return false, fx
    else
        local merged = merge(fx, read_table)
        return true, merged
    end
end

return layout_reader
