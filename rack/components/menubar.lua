local menubar = {}
local r = reaper

function menubar:init(ctx)
    self.ctx = ctx
    return self
end

function menubar:display()
    r.ImGui_Text(self.ctx, 'Style Editor')
    -- r.ImGui_BeginMenuBar(self.ctx)

    -- if r.ImGui_BeginMenu(self.ctx, 'Settings') then
    --     if select(2, r.ImGui_MenuItem(self.ctx, 'Style Editor')) then
    --         r.ImGui_Text(self.ctx, 'Style Editor')
    --     end

    --     if select(2, r.ImGui_MenuItem(self.ctx, 'Keyboard Shortcut Editor')) then
    --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
    --     end
    --     if r.ImGui_GetWindowDockID(self.ctx) ~= -1 then
    --         if select(2, r.ImGui_MenuItem(self.ctx, 'Dock script')) then
    --             Dock_Now = true
    --         end
    --     end
    --     if select(2, r.ImGui_MenuItem(self.ctx, "Rescan Plugin List")) then
    --         --ScanPlugins()
    --         r.ImGui_Text(self.ctx, 'Keyboard Shortcut Editor')
    --     end


    --     r.ImGui_EndMenu(self.ctx)
    -- end
    -- r.ImGui_EndMenuBar(self.ctx)
end

return menubar
