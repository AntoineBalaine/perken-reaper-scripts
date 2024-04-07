local layout_reader = {}
local IniParse = require("lib.Iniparse.IniParse")


---@param fx TrackFX
function layout_reader.save(fx)
    local mapped = {
        name = fx.name,
        display_params = fx.display_params,
        display_settings = fx.displaySettings

    }


    local P = {
        displaySettings = {
            background = fx.displaySettings.background,
            -- background_disabled = fx.displaySettings.background_disabled, -- unused
            -- background_offline = fx.displaySettings.background_offline, -- unused
            -- borderColor = fx.displaySettings.borderColor, -- don't store this
            buttons_layout = fx.displaySettings.buttons_layout,
            -- title_Clr = fx.displaySettings.title_Clr,
            -- title_Width = fx.displaySettings.title_Width,
            title_display = fx.displaySettings.title_display,
            -- window_height = fx.displaySettings.window_height,
            window_width = fx.displaySettings.window_width,
            -- labelButtonStyle = fx.displaySettings.labelButtonStyle, -- don't allow storing this
        }
    }

    if fx.displaySettings.custom_Title and fx.displaySettings.custom_Title ~= "" then
        P.displaySettings.custom_Title = fx.displaySettings.custom_Title
    end
    if fx.displaySettings.decorations then
        P.decorations = {}
        for idx, decoration in ipairs(fx.displaySettings.decorations) do
            local curidx = {
                [idx .. "x"] = decoration.x,
                [idx .. "y"] = decoration.y,
                [idx .. "color"] = decoration.color,
                [idx .. "height"] = decoration.height,
                [idx .. "type"] = decoration.type,
                [idx .. "width"] = decoration.width,
            }
            for k, v in pairs(curidx) do
                P.decorations[k] = v
            end
        end
    end

    local stringified = IniParse.stringify(P)
    reaper.ShowConsoleMsg(stringified .. "\n")
    -- for idx, param in ipairs(fx.display_params) do
    --     local st = param.details.display_settings
    --     local St = {
    --         x = st.x,
    --         y = st.y,
    --         color = st.color,
    --         colors = st.color,
    --         flags = st.flags,
    --         height = st.height,
    --         radius = st.radius,
    --         type = st.type,
    --         variant = st.variant,
    --         width = st.width,
    --         wiper_start = st.wiper_start
    --     }
    -- end
end

return layout_reader
