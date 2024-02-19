local ThemeReader  = require("themeReader.theme_read")
local Fx_box       = require("components.Fx_box")
local Fx_separator = require("components.fx_separator")
local menubar      = require("components.menubar")
local state        = require("state.state")
local actions      = require("state.actions")
local Browser      = require("components.fx_browser")

---Rack module
---@class Rack
local Rack         = {}

---draw the fx list
function Rack:drawFxList()
    if not self.state.Track then
        return
    end

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
    reaper.ImGui_PushStyleColor(
        self.ctx,
        reaper.ImGui_Col_WindowBg(), --background color
        self.theme.colors.col_main_bg2.color)
end

--- end any styling for the rack, i.e. `ImGui_PopStyleColor`
function Rack:RackStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx) -- Remove background color
end

function Rack:main()
    -- update state and actions at every loop
    self.state:update():getTrackFx()
    self.actions:update()
    self.actions:manageDock()

    self:RackStyleStart()

    local imgui_visible, imgui_open = reaper.ImGui_Begin(self.ctx, "rack", true, self.window_flags)
    if imgui_visible then
        --display the rack
        menubar:display()
        self:drawFxList()
    end

    self:RackStyleEnd()
    reaper.ImGui_End(self.ctx)
    if not imgui_open or reaper.ImGui_IsKeyPressed(self.ctx, 27) then
        -- if the fx_browser is open,
        -- set it to be closed
        -- so that it doesn’t throw an error when the rack closes
        if not Browser.closed then
            Browser.closed = true
        end
        reaper.ImGui_DestroyContext(self.ctx)
    else
        reaper.defer(function() self:main() end)
    end
end

---Create the ImGui context and setup the window size
---@param project_directory string
function Rack:init(project_directory)
    local ctx_flags = reaper.ImGui_ConfigFlags_DockingEnable()
    self.ctx = reaper.ImGui_CreateContext("rack",
        ctx_flags)
    reaper.ImGui_SetNextWindowSize(self.ctx, 500, 440, reaper.ImGui_Cond_FirstUseEver())
    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        + reaper.ImGui_WindowFlags_MenuBar()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoNav()
    self.window_flags = window_flags -- tb used in main()


    self.theme = ThemeReader.readTheme(ThemeReader.GetThemePath(), true) -- get and store the user's theme
    self.state = state:init(project_directory, self.theme)               -- initialize state, query selected track and its fx
    self.actions = actions:init(self.ctx, self.state.Track)              -- always init actions after state
    Browser:init(self.ctx)                                               -- initialize the fx browser
    ---@type FXBrowser
    self.Browser =
        Browser -- set the fx browser as a property of the rack, always init before the Fx_separator

    -- initialize components by passing them the rack's state
    Fx_box:init(self)
    Fx_separator:init(self)
    menubar:init(self)
    return self
end

return Rack
