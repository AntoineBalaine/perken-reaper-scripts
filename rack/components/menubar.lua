local menubar = {}
local r = reaper

---@param state table
---@return self
function menubar:init(state)
    self.state = state --- the rack's context
    return self
end

function menubar:display()
    r.ImGui_BeginMenuBar(self.state.ctx)
    if r.ImGui_BeginMenu(self.state.ctx, 'Settings') then
        if select(2, r.ImGui_MenuItem(self.state.ctx, 'Style Editor')) then
            r.ImGui_Text(self.state.ctx, 'Style Editor')
        end

        --     if select(2, r.ImGui_MenuItem(self.ctx, 'Keyboard Shortcut Editor')) then
        --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
        --     end

        ---FIXME: How to undock?
        if reaper.ImGui_IsWindowDocked(self.state.ctx) then -- if undocked
            if select(2, r.ImGui_MenuItem(self.state.ctx, 'undock')) then
                self.state.actions.dock = false             -- user clicked «undock», rack.display() will set the dockID to 0
            end
        else
            if select(2, r.ImGui_MenuItem(self.state.ctx, 'dock')) then
                self.state.actions.dock = true -- user clicked «dock», rack.display() will set the dockID to -1
            end
        end
        --     if select(2, r.ImGui_MenuItem(self.ctx, "Rescan Plugin List")) then
        --         --ScanPlugins()
        --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
        --     end


        r.ImGui_EndMenu(self.state.ctx)
    end
    r.ImGui_EndMenuBar(self.state.ctx)
end

return menubar
