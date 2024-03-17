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
local ThemeReader  = require("themeReader.theme_read")
local Fx_box       = require("components.Fx_box")
local Fx_separator = require("components.fx_separator")
local menubar      = require("components.menubar")
local state        = require("state.state")
local actions      = require("state.actions")
local Browser      = require("components.fx_browser")
local Settings     = require("state.settings")
local LayoutEditor = require("components.LayoutEditor")
local passThrough  = require("components.passthrough")
local constants    = require("helpers.constants")

---Rack module
---@class Rack
local Rack         = {}

function Rack:BrowserButton()
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    local plus = self.theme.letters[34]
    -- create window name button
    if reaper.ImGui_Button(self.ctx,
            plus,
            20,
            constants.WINDOW_HEIGHT) then
        self.Browser.open = true
        if not reaper.ImGui_IsPopupOpen(self.ctx, self.Browser.name) then
            reaper.ImGui_OpenPopup(self.ctx, self.Browser.name)
        end
    end
    reaper.ImGui_PopFont(self.ctx)

    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "add fx")
    end
    self.Browser:Popup()
end

---draw the fx list
function Rack:drawFxList()
    for idx, fx in ipairs(self.state.Track.fx_list) do
        reaper.ImGui_PushID(self.ctx, tostring(idx))
        Fx_separator:spaceBtwFx(idx)
        Fx_box:main(fx)
        reaper.ImGui_PopID(self.ctx)
    end
    Fx_separator:spaceBtwFx(#self.state.Track.fx_list + 1, true)
end

--- start any styling for the rack, i.e. `ImGui_PushStyleColor`
function Rack:RackStyleStart()
    reaper.ImGui_PushStyleVar(self.ctx, reaper.ImGui_StyleVar_FrameRounding(), 2) -- round up the frames
    reaper.ImGui_PushStyleColor(
        self.ctx,
        reaper.ImGui_Col_WindowBg(), --background color
        self.theme.colors.col_main_bg2.color)
end

--- end any styling for the rack, i.e. `ImGui_PopStyleColor`
function Rack:RackStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx)  -- Remove background color
    reaper.ImGui_PopStyleVar(self.ctx, 1) -- remove rounding of frames
end

function Rack:main()
    -- update state and actions at every loop
    self.state:update():getTrackFx()
    self.actions:update()
    self.actions:manageDock()

    self:RackStyleStart()

    local imgui_visible, imgui_open = reaper.ImGui_Begin(self.ctx, "rack", true, self.window_flags)

    if not self.Browser.open then
        passThrough:runShortcuts() -- execute any shortcuts the user might have pressed
    end
    if imgui_visible then
        --display the rack
        -- menubar:display()

        if self.state.Track then
            self:drawFxList()
            self:BrowserButton()
        end
        reaper.ImGui_End(self.ctx)
    end

    self:RackStyleEnd()
    if not imgui_open or reaper.ImGui_IsKeyPressed(self.ctx, 27) then
        -- Close the rack.
        self.LayoutEditor:close()
    else
        reaper.defer(function() self:main() end)
    end
end

---Create the ImGui context and setup the window size
---@param project_directory string
function Rack:init(project_directory)
    local os_sep                        = package.config:sub(1, 1)
    --set up the theme in init, including any custom fonts such as the icons' font
    ---@class Theme
    self.theme                          = ThemeReader.readTheme(ThemeReader.GetThemePath(), true) -- get and store the user's theme
    self.theme.FONT_SIZE                = 15
    self.theme.FONT_LARGE               = 16
    self.theme.ICON_FONT_SMALL_SIZE     = 13
    self.theme.ICON_FONT_LARGE_SIZE     = 40
    self.theme.ICON_FONT_CLICKED_SIZE   = 32
    self.theme.ICON_FONT_PREVIEW_SIZE   = 16
    local font_path                     = project_directory .. "assets" .. os_sep .. "fontello1.ttf"
    self.theme.fonts["ICON_FONT_SMALL"] = reaper.ImGui_CreateFont(font_path, self.theme.ICON_FONT_SMALL_SIZE)

    self.theme.letters                  = {}
    for i = 33, 254 do self.theme.letters[#self.theme.letters + 1] = utf8.char(i) end
    self.theme.letters = self.theme.letters

    local ctx_flags    = reaper.ImGui_ConfigFlags_DockingEnable()
    self.ctx           = reaper.ImGui_CreateContext("rack", ctx_flags)

    --- attach the fonts now that the context has been created
    reaper.ImGui_Attach(self.ctx, self.theme.fonts.ICON_FONT_SMALL)

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

    passThrough:init(self.ctx)
    self.settings = Settings:init(project_directory)
    self.state = state:init(project_directory, self.theme)  -- initialize state, query selected track and its fx
    self.actions = actions:init(self.ctx, self.state.Track) -- always init actions after state
    Browser:init(self.ctx)                                  -- initialize the fx browser
    ---@type FXBrowser
    self.Browser =
        Browser -- set the fx browser as a property of the rack, always init before the Fx_separator
    LayoutEditor:init(self.ctx, self.theme)
    self.LayoutEditor = LayoutEditor


    -- initialize components by passing them the rack's state
    Fx_box:init(self)
    Fx_separator:init(self)
    -- menubar:init(self)
    return self
end

return Rack
