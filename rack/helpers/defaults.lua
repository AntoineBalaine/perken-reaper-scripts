--[[
Defaults for FX sizes and for the fx separator's height.
]]

local layout_enums        = require("state.layout_enums")
local color_helpers       = require("helpers.color_helpers")
local defaults            = {}
defaults.window_height    = 240
defaults.window_width     = 280
defaults.custom_Title     = nil
defaults.edge_Rounding    = 0
defaults.grb_Rounding     = 0
defaults.param_Instance   = nil
defaults.title_Clr        = 0x000000FF
defaults.title_Width      = 220 - 80

defaults.param_text_color = 0xFFFFFFFF

---@param theme Theme
---@return integer dot_color, integer track_color, integer wiper_color
function defaults.getDefaultKnobColors(theme)
    local dot_col = theme.colors.areasel_fill
    local track_col = theme.colors.col_buttonbg
    local wiper_col = theme.colors.areasel_outline
    return dot_col.color, track_col.color, wiper_col.color
end

---@param theme Theme
---@return FxDisplaySettings
function defaults.getDefaultFxDisplaySettings(theme)
    ---@type FxDisplaySettings
    local displaySettings = {
        _is_collapsed       = false,
        background          = theme.colors.selcol_tr2_bg.color,
        background_disabled = theme.colors.group_15.color,
        background_offline  = theme.colors.col_mi_fades.color,
        borderColor         = theme.colors.col_gridlines2.color,
        buttons_layout      = layout_enums.buttons_layout.horizontal, -- TODO set as «vertical» by default
        labelButtonStyle    = {
            -- background = theme.colors.col_fadearm2.color,
            background = theme.colors.col_main_bg.color,
            background_disabled = theme.colors.group_15.color,
            background_offline = color_helpers.desaturate(theme.colors.col_mi_fades.color),
            -- text_enabled = theme.colors.col_toolbar_text_on.color,
            text_enabled = theme.colors.mcp_fx_normal.color,
            text_disabled = theme.colors.mcp_fx_bypassed.color,
            text_offline = theme.colors.mcp_fx_offlined.color,
        },
        custom_Title        = nil,
        edge_Rounding       = 0,
        grb_Rounding        = 0,
        param_Instance      = nil,
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

return defaults
