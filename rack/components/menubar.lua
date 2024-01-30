local menubar     = {}
local ThemeReader = require("themeReader.theme_read")

---@param state table
---@return self
function menubar:init(state)
    self.state = state --- the rack's context
    self.ctx = state.ctx
    self.theme = state.theme
    return self
end

function menubar:display()
    ---FIXME can’t get the menu bar to change colors
    reaper.ImGui_PushStyleColor(
        self.ctx,
        reaper.ImGui_Col_MenuBarBg(),
        ThemeReader.IntToRgba(self.theme.colors.selcol_tr2_bg.color)) -- menu bar’s bg color
    reaper.ImGui_BeginMenuBar(self.ctx)

    if reaper.ImGui_BeginMenu(self.ctx, 'Settings') then
        if select(2, reaper.ImGui_MenuItem(self.ctx, 'Style Editor')) then
            reaper.ImGui_Text(self.ctx, 'Style Editor')
        end

        --     if select(2, r.ImGui_MenuItem(self.ctx, 'Keyboard Shortcut Editor')) then
        --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
        --     end

        ---FIXME: How to undock?
        if reaper.ImGui_IsWindowDocked(self.ctx) then -- if undocked
            if select(2, reaper.ImGui_MenuItem(self.ctx, 'undock')) then
                self.state.actions.dock = false       -- user clicked «undock», rack.display() will set the dockID to 0
            end
        else
            if select(2, reaper.ImGui_MenuItem(self.ctx, 'dock')) then
                self.state.actions.dock = true -- user clicked «dock», rack.display() will set the dockID to -1
            end
        end
        --     if select(2, r.ImGui_MenuItem(self.ctx, "Rescan Plugin List")) then
        --         --ScanPlugins()
        --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
        --     end


        reaper.ImGui_EndMenu(self.ctx)
    end
    reaper.ImGui_EndMenuBar(self.ctx)
    reaper.ImGui_PopStyleColor(self.ctx) -- pop the bg color
end

return menubar
