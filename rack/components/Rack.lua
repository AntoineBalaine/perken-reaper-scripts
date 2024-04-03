--[[
This is the main component:
steps are:
- initialize the component with rack:init()
- set up the state,
- read the theme,
- manage whether the component is docked
- initialize the dependent component such as:
    - the fx browser,
    - the menu bar,
    - the fx box,
    - the fx separator (space between fx for drag and drop)
- and then display the rack with rack:main()
]]
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.6') -- enable backwards compatibility
local ThemeReader            = require("themeReader.theme_read")
---@class Theme
Theme                        = ThemeReader.readTheme(ThemeReader.GetThemePath(), true) -- get and store the user's theme
Theme.FONT_SIZE              = 15
Theme.FONT_SMALL_SIZE        = 14
Theme.FONT_LARGE             = 16
Theme.ICON_FONT_SMALL_SIZE   = 13
Theme.ICON_FONT_LARGE_SIZE   = 40
Theme.ICON_FONT_CLICKED_SIZE = 32
Theme.ICON_FONT_PREVIEW_SIZE = 16

local Fx_box                 = require("components.Fx_box")
local Fx_separator           = require("components.fx_separator")
local menubar                = require("components.menubar")
local state                  = require("state.state")
local actions                = require("state.actions")
local Browser                = require("components.fx_browser")
local Settings               = require("state.settings")
local LayoutEditor           = require("components.LayoutEditor")
-- local passThrough          = require("components.passthrough")
local keyboard_passthrough   = require("components.keyboard_passthrough")
local defaults               = require("helpers.defaults")
local MainWindowStyle        = require("helpers.MainWindowStyle")
local layout_enums           = require("state.layout_enums")


---Rack module
---@class Rack
local Rack = {}

function Rack:BrowserButton()
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    local plus = Theme.letters[34]
    -- create window name button
    if reaper.ImGui_Button(self.ctx,
            plus,
            20,
            defaults.window_height) then
        self.Browser.open = true
        if not reaper.ImGui_IsPopupOpen(self.ctx, self.Browser.name) then
            reaper.ImGui_OpenPopup(self.ctx, self.Browser.name)
        end
    end
    reaper.ImGui_PopFont(self.ctx)

    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "add fx")
    end
    self.Browser:Popup(self.ctx, Theme)
end

---Global rack’s button actions (automation mode, toggle fx chain, save fx chain, close rack, etc.)
function Rack:ButtonsBar()
    reaper.ImGui_BeginGroup(self.ctx)
    -- close the rack
    local CLOSE = Theme.letters[31]
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    if reaper.ImGui_Button(self.ctx, CLOSE, defaults.button_size, defaults.button_size) then
        self.imgui_open = false
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "close rack")
    end

    -- toggle chain
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    local clicked, _ = reaper.ImGui_Checkbox(self.ctx, "##toggle_fx_chain", self.state.Track.fx_chain_enabled)
    if clicked then
        reaper.SetMediaTrackInfo_Value(self.state.Track.track, "I_FXEN", self.state.Track.fx_chain_enabled and 0 or 1) -- bypassed
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "FX enabled")
    end

    local label
    if self.state.Track.automation_mode == layout_enums.AutomationMode.trim then
        label = "Tr"
    elseif self.state.Track.automation_mode == layout_enums.AutomationMode.read then
        label = "R"
    elseif self.state.Track.automation_mode == layout_enums.AutomationMode.touch then
        label = "To"
    elseif self.state.Track.automation_mode == layout_enums.AutomationMode.write then
        label = "W"
    elseif self.state.Track.automation_mode == layout_enums.AutomationMode.latch then
        label = "L"
    else --[[ self.state.Track.automation_mode==layout_enums.AutomationMode.preview]]
        label = "P"
    end
    -- cycle automation modes
    if reaper.ImGui_Button(self.ctx, label, defaults.button_size, defaults.button_size) then
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_NF_CYCLE_TRACK_AUTOMATION_MODES"), 0) -- first SWS action in the project!
    end
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "cycle automation mode")
    end

    -- save chain
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    local saver = Theme.letters[164]
    if reaper.ImGui_Button(self.ctx, saver, defaults.button_size, defaults.button_size) then
        -- TODO implement save fx chain
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "save fx chain")
    end

    reaper.ImGui_EndGroup(self.ctx)

    reaper.ImGui_SameLine(self.ctx)
    local x = reaper.ImGui_GetCursorPosX(self.ctx)

    reaper.ImGui_SetCursorPosX(self.ctx, x - 20)
end

---draw the fx list
function Rack:drawFxList()
    for idx, fx in ipairs(self.state.Track.fx_list) do
        reaper.ImGui_PushID(self.ctx, tostring(idx))
        Fx_separator:spaceBtwFx(idx, idx == 1)
        Fx_box:main(fx)
        reaper.ImGui_PopID(self.ctx)
    end
    Fx_separator:spaceBtwFx(#self.state.Track.fx_list + 1, false)
end

--- start any styling for the rack, i.e. `ImGui_PushStyleColor`
function Rack:RackStyleStart()
    reaper.ImGui_PushStyleVar(self.ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1.0)
    reaper.ImGui_PushStyleVar(self.ctx, reaper.ImGui_StyleVar_FrameRounding(), 2) -- round up the frames
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_WindowBg(), Theme.colors.col_main_bg2.color)


    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Button(), Theme.colors.col_main_bg2.color)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBg(), Theme.colors.col_main_bg2.color)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBgHovered(), Theme.colors.col_env5.color)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBgActive(), Theme.colors.midi_endpt.color)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_CheckMark(), Theme.colors.col_seltrack.color)

    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_ButtonActive(), Theme.colors.midi_endpt.color)

    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_ButtonHovered(), Theme.colors.col_env5.color)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(), Theme.colors.col_seltrack.color)
end

--- end any styling for the rack, i.e. `ImGui_PopStyleColor`
function Rack:RackStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 9) -- Remove background color
    reaper.ImGui_PopStyleVar(self.ctx, 2)   -- remove rounding of frames
end

function Rack:main()
    -- update state and actions at every loop
    self.state:update():getTrackFx()
    self.actions:update()
    self.actions:manageDock()

    self:RackStyleStart()

    reaper.ImGui_PushFont(self.ctx, Theme.fonts.MAIN)
    local imgui_visible
    imgui_visible, self.imgui_open = reaper.ImGui_Begin(self.ctx, "rack", true, self.window_flags)

    if not self.Browser.open and reaper.ImGui_IsWindowFocused(self.ctx) then
        -- passThrough:runShortcuts() -- execute any shortcuts the user might have pressed
        self.keyboard_passthrough:run()
    end
    if imgui_visible then
        --display the rack
        -- menubar:display()

        if self.state.Track then
            self:ButtonsBar()
            self:drawFxList()
            self:BrowserButton()
        end
        reaper.ImGui_End(self.ctx)
    end
    reaper.ImGui_PopFont(self.ctx)

    self:RackStyleEnd()
    if not self.imgui_open or reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_Escape()) then
        -- Close the rack.
        self.keyboard_passthrough:onClose()
        self.LayoutEditor:close()
    else
        reaper.defer(function() self:main() end)
    end
end

---Create the ImGui context and setup the window size
---@param project_directory string
function Rack:init(project_directory)
    local os_sep                   = package.config:sub(1, 1)
    --set up the theme in init, including any custom fonts such as the icons' font
    local font_path                = project_directory .. "assets" .. os_sep .. "fontello1.ttf"
    Theme.fonts["ICON_FONT_SMALL"] = reaper.ImGui_CreateFont(font_path, Theme.ICON_FONT_SMALL_SIZE)

    local fontindex, fontface      = gfx.getfont()
    Theme.fonts["MAIN"]            = reaper.ImGui_CreateFont(fontface, Theme.FONT_SMALL_SIZE)

    Theme.letters                  = {}
    for i = 33, 254 do Theme.letters[#Theme.letters + 1] = utf8.char(i) end
    Theme.letters   = Theme.letters

    local ctx_flags = reaper.ImGui_ConfigFlags_DockingEnable()
    self.ctx        = reaper.ImGui_CreateContext("rack", ctx_flags)


    --- attach the fonts now that the context has been created
    reaper.ImGui_Attach(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    reaper.ImGui_Attach(self.ctx, Theme.fonts.MAIN)

    reaper.ImGui_SetNextWindowSize(self.ctx, 500, 440, reaper.ImGui_Cond_FirstUseEver())
    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        -- + reaper.ImGui_WindowFlags_MenuBar()
        + reaper.ImGui_WindowFlags_AlwaysAutoResize()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoTitleBar()
        + reaper.ImGui_WindowFlags_NoNav()


    self.window_flags = window_flags -- tb used in main()


    self.settings = Settings:init(project_directory)
    self.state = state:init(project_directory)              -- initialize state, query selected track and its fx
    self.actions = actions:init(self.ctx, self.state.Track) -- always init actions after state
    self.keyboard_passthrough = keyboard_passthrough:init(self.ctx)
    Browser:init(self.ctx)                                  -- initialize the fx browser
    ---@type FXBrowser
    self.Browser =
        Browser -- set the fx browser as a property of the rack, always init before the Fx_separator
    LayoutEditor:init(self.ctx)
    self.LayoutEditor = LayoutEditor


    -- initialize components by passing them the rack's state
    Fx_box:init(self)
    Fx_separator:init(self)
    -- menubar:init(self)
    return self
end

return Rack
