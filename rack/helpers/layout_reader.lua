local layout_reader = {}
local serpent = require("lib.serpent")
local table_helpers = require("helpers.table")

---@param parameter Parameter
---@return LayoutParameter LayoutParameter
local function LayoutParameter(parameter)
    local rv = {
        display_settings = parameter.display_settings,
        ident = parameter.ident,
        index = parameter.index,
        name = parameter.name,
    }
    rv.display_settings.component = nil -- don't store the component in the layout file
    return rv
end

---@param display_settings FxDisplaySettings
---@return LayoutFxDisplaySettings LayoutFxDisplaySettings
local function LayoutFxDisplaySettings(display_settings)
    return {
        background = display_settings.background,
        borderColor = display_settings.borderColor,
        buttons_layout = display_settings.buttons_layout,
        custom_Title = display_settings.custom_Title,
        title_display = display_settings.title_display,
        window_width = display_settings.window_width,
        decorations = table_helpers.deepCopy(display_settings.decorations, nil, { "_selected" }),
    }
end

---@param paramData ParamData
---@return LayoutParamData LayoutParamData
local function LayoutParamData(paramData)
    return {
        details = LayoutParameter(paramData.details),
        display = paramData.display,
        index = paramData.index,
        name = paramData.name,
    }
end

---@param trackFX TrackFX
---@return LayoutTrackFX LayoutTrackFX
local function LayoutTrackFX(trackFX)
    ---@type LayoutParamData[]
    local layout_display_params = {}
    for _, paramData in ipairs(trackFX.display_params) do
        layout_display_params[#layout_display_params + 1] = LayoutParamData(paramData)
    end
    return {
        display_name = trackFX.display_name,
        displaySettings = LayoutFxDisplaySettings(trackFX.displaySettings),
        display_params = layout_display_params,
        name = trackFX.name,
    }
end


local os_separator = package.config:sub(1, 1)
---@param project_directory string
---@param fx_name string
local function get_file_path(project_directory, fx_name)
    fx_name = fx_name:gsub(os_separator, "")
    return project_directory .. "layouts" .. os_separator .. fx_name .. ".lua"
end

---@param fx TrackFX
---@return boolean success
function layout_reader.save(fx)
    local layoutData = LayoutTrackFX(fx)
    local block = serpent.block(layoutData, { comment = false })
    local fmt_block = string.format("return %s", block)
    local file_path = get_file_path(fx.state.project_directory, fx.name)
    local file = io.open(file_path, "w+")
    local success = true
    if file then
        local fp, errmsg = file:write(fmt_block)
        if not fp and errmsg then
            success = false
            reaper.MB(errmsg, "Error", 0)
        else
            reaper.MB("layout saved at " .. file_path, "Success", 0)
        end
        file:close()
    else
        success = false
        reaper.MB("Error: Could not save layout", "Error", 0)
    end
    return success
end

return layout_reader
