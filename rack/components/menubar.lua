local menubar = {}
local r = reaper

---@param IgCtx ImGui_Context
---@param Ctx Rack_Context
---@return self
function menubar:init(IgCtx, Ctx)
    self.IgCtx = IgCtx
    self.Ctx = Ctx --- the rack's context
    return self
end

function menubar:display()
    r.ImGui_BeginMenuBar(self.IgCtx)
    if r.ImGui_BeginMenu(self.IgCtx, 'Settings') then
        if select(2, r.ImGui_MenuItem(self.IgCtx, 'Style Editor')) then
            r.ImGui_Text(self.IgCtx, 'Style Editor')
        end

        --     if select(2, r.ImGui_MenuItem(self.ctx, 'Keyboard Shortcut Editor')) then
        --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
        --     end

        ---FIXME: How to undock?
        if reaper.ImGui_IsWindowDocked(self.IgCtx) then -- if undocked
            if select(2, r.ImGui_MenuItem(self.IgCtx, 'undock')) then
                self.Ctx.actions.dock = false           -- user clicked «undock», rack.display() will set the dockID to 0
            end
        else
            if select(2, r.ImGui_MenuItem(self.IgCtx, 'dock')) then
                self.Ctx.actions.dock = true -- user clicked «dock», rack.display() will set the dockID to -1
            end
        end
        --     if select(2, r.ImGui_MenuItem(self.ctx, "Rescan Plugin List")) then
        --         --ScanPlugins()
        --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
        --     end


        r.ImGui_EndMenu(self.IgCtx)
    end
    r.ImGui_EndMenuBar(self.IgCtx)
end

return menubar
