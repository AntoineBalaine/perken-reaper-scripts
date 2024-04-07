--[[
Defaults for FX sizes and for the fx separator's height.
]]

local layout_enums        = require("state.layout_enums")
local color_helpers       = require("helpers.color_helpers")
local Knob                = require("components.knobs.Knobs")
local Slider              = require("components.Slider")
local ColorSet            = require("helpers.ColorSet")
local Theme               = Theme
local defaults            = {}
defaults.window_height    = 240
defaults.window_width     = 280
defaults.custom_Title     = nil
defaults.title_Clr        = 0x000000FF
defaults.title_Width      = 220 - 80
defaults.button_size      = 20

defaults.param_text_color = 0xFFFFFFFF

---@return integer dot_color, integer track_color, integer wiper_color
function defaults.getDefaultKnobColors()
    local dot_col = Theme.colors.areasel_fill
    local track_col = Theme.colors.col_buttonbg
    local wiper_col = Theme.colors.areasel_outline
    return dot_col.color, track_col.color, wiper_col.color
end

---Create default Fx display settings,
---such as default colors for the fx box, label button styles, etc.
---@return FxDisplaySettings
function defaults.getDefaultFxDisplaySettings()
    ---@type FxDisplaySettings
    local displaySettings = {
        _is_collapsed       = false,
        background          = Theme.colors.selcol_tr2_bg.color,
        background_disabled = Theme.colors.group_15.color,
        background_offline  = Theme.colors.col_mi_fades.color,
        borderColor         = Theme.colors.col_gridlines2.color,
        buttons_layout      = layout_enums.buttons_layout.horizontal, -- TODO set as «vertical» by default
        labelButtonStyle    = {
            -- background = Theme.colors.col_fadearm2.color,
            background = Theme.colors.col_main_bg.color,
            background_disabled = Theme.colors.group_15.color,
            background_offline = color_helpers.desaturate(Theme.colors.col_mi_fades.color),
            -- text_enabled = Theme.colors.col_toolbar_text_on.color,
            text_enabled = Theme.colors.mcp_fx_normal.color,
            text_disabled = Theme.colors.mcp_fx_bypassed.color,
            text_offline = Theme.colors.mcp_fx_offlined.color,
        },
        custom_Title        = nil,
        title_Clr           = 0x000000FF,
        title_Width         = 220 - 80,
        window_width        = defaults.window_width,
        window_height       = defaults.window_height, -- TODO make this into a constant, accessible everywhere
        _grid_size          = 10,
        _grid_color         = 0x444444AA,
        title_display       = layout_enums.Title_Display_Style.fx_name,
    }
    return displaySettings
end

--- create a knob by default,
--- unless the values are stepped and there's less than 7 of them:
--- in that case, create a stepped knob.
---@param steps_count integer
---@param type? Param_Display_Type
---@return KnobDisplaySettings|HorizontalSliderDisplaySettings|VerticalSliderDisplaySettings|CycleButtonDisplaySettings
function defaults.getDefaultParamDisplaySettings(steps_count, type)
    if type then
        if type == layout_enums.Param_Display_Type.Slider then
            return defaults.getDefaultHorizontalSliderDisplaySettings()
        elseif type == layout_enums.Param_Display_Type.CycleButton then
            return defaults.getDefaultCycleButtonDisplaySettings()
        elseif type == layout_enums.Param_Display_Type.vSlider then
            return defaults.getDefaultVerticalSliderDisplaySettings()
        elseif type == layout_enums.Param_Display_Type.Knob then
            return defaults.getDefaultKnobDisplaySettings()
        end
    end
    if steps_count and steps_count <= 7 then
        return defaults.getDefaultCycleButtonDisplaySettings()
    else
        return defaults.getDefaultKnobDisplaySettings()
    end
end

---create a parameter's default display settings,
---such as basic colors for knobs and other controls.
---@return KnobDisplaySettings
function defaults.getDefaultKnobDisplaySettings()
    local variant = Knob.KnobVariant.ableton
    local flags = layout_enums.KnobFlags.None
    local dot_col, track_col, wiper_col = defaults.getDefaultKnobColors()
    ---@type KnobDisplaySettings
    local display_settings = {
        type = layout_enums.Param_Display_Type.Knob,
        ---the component that will be drawn, to be instantiated in the fx_box:main()
        ---remains to be seen if it might be better to instantiate it here…
        component = nil,
        wiper_start = layout_enums.KnobWiperStart.left,
        variant = variant,
        flags = flags,
        color = {
            text_color = 0xFFFFFFFF,
            wiper_color = ColorSet.new(wiper_col),
            dot_color = ColorSet.new(dot_col),
            circle_color = ColorSet.new(track_col),
        },
        radius = 21
    }
    return display_settings
end

---create a horizontal sliders's default display settings,
---@return HorizontalSliderDisplaySettings
function defaults.getDefaultHorizontalSliderDisplaySettings()
    local flags = layout_enums.KnobFlags.None
    ---@type HorizontalSliderDisplaySettings
    local display_settings = {
        type = layout_enums.Param_Display_Type.Slider,
        component = nil, ---the component that will be drawn, to be instantiated in the fx_box:main()
        variant = Slider.Variant.horizontal,
        flags = flags,
        width = 100,
        height = 60,
        color = {
            text_color = 0xFFFFFFFF
        }

    }
    return display_settings
end

---create a vertical sliders's default display settings,
function defaults.getDefaultVerticalSliderDisplaySettings()
    local flags = layout_enums.KnobFlags.None
    ---@type VerticalSliderDisplaySettings
    local display_settings = {
        type = layout_enums.Param_Display_Type.vSlider,
        component = nil, ---the component that will be drawn, to be instantiated in the fx_box:main()
        variant = Slider.Variant.vertical,
        flags = flags,
        width = 40,
        height = 100,
        color = {
            text_color = 0xFFFFFFFF
        }
    }
    return display_settings
end

---create a cycle button's default display settings,
function defaults.getDefaultCycleButtonDisplaySettings()
    local flags = layout_enums.KnobFlags.None
    ---@type CycleButtonDisplaySettings
    local display_settings = {
        type = layout_enums.Param_Display_Type.CycleButton,
        component = nil, ---the component that will be drawn, to be instantiated in the fx_box:main()
        flags = flags,
        width = 50,
        height = 20,
        color = {
            text_color = 0xFFFFFFFF
        }
    }
    return display_settings
end

return defaults
