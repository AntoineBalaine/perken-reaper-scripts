--[[
- When an FX wants to edit layout, it calls the LayoutEditor's `editLayout()` and passes it its state (`displaySettings_copy`, track ID, `onClose` callbacks, etc.)
- The LayoutEditor adds the data to its state, and displays the edit window.
- The rack keeps on displaying the edited FX, but uses the `displaySettings_copy` instead of the `displaySettings`

For now, keep a single instance for the whole app.
- run it on its own defer cycle, instead of continuously calling from the app.

TBD
- Singleton or one instance per fx?
Singleton assumes that changing without saving is going to affect all instances of the same plug-in. That doesn't have to be true.
Let's go with one instance per fx:
- allow one un-saved layout per FX. Eeach fx can have its own look.
- If we want to persist unsaved layouts between re-starts, we'll have to either store this in external state or in the track.

]]
local LayoutEditor = {}

---@param ctx ImGui_Context
function LayoutEditor:init(ctx)
    self.open = false
    self.ctx = ctx
    return self
end

function LayoutEditor:main()
    if not self.open then
        return
    end
    local center = { reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(self.ctx)) } ---window styling
    reaper.ImGui_SetNextWindowPos(self.ctx, center[1], center[2], reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
    reaper.ImGui_SetNextWindowSize(self.ctx, 400, 300)
    ---TODO replace the popup modal with something morne appropriate
    local visible, open = reaper.ImGui_Begin(self.ctx, "Shortcut List", true, reaper.ImGui_WindowFlags_TopMost()) ---begin popup
    self.open = open
    if visible then
        -- iterate display settings
        reaper.ImGui_Text(self.ctx, "Editing the layout!")
        reaper.ImGui_End(self.ctx)
    end
    if open then
        reaper.defer(function() self:main() end)
    end
end

---@param action EditLayoutCloseAction
function LayoutEditor:close(action)
    -- perform clean up: call the FX's `onClose()` and clean-up the state
    self.fx:onEditLayoutClose(action)
    self.open = false
    self.fx = nil
    self.displaySettings = nil
end

---@param fx FxInstance
function LayoutEditor:edit(fx)
    --[[
   display a pop-up window with a widget for each of the settings.
    --]]
    self.fx = fx
    self.displaySettings = fx.displaySettings_copy
    self.open = true
    self:main()
end

return LayoutEditor
