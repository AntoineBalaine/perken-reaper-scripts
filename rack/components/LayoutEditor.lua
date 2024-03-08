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
---@param theme Theme
function LayoutEditor:init(ctx, theme)
    self.open = false
    self.ctx = ctx
    self.theme = theme
    return self
end

function LayoutEditor:fontButton()
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)

    local wrench_icon = self.theme.letters[75]
    local arrow_right = self.theme.letters[97]
    local arrow_down = self.theme.letters[94]
    local saver = self.theme.letters[164]
    local kebab = self.theme.letters[191]
    local plus = self.theme.letters[34]
    reaper.ImGui_Button(self.ctx, wrench_icon)
    reaper.ImGui_Button(self.ctx, arrow_right)
    reaper.ImGui_Button(self.ctx, arrow_down)
    reaper.ImGui_Button(self.ctx, saver)
    reaper.ImGui_Button(self.ctx, kebab)
    reaper.ImGui_Button(self.ctx, plus)
    -- for i = 1, #self.theme.letters do
    --     reaper.ImGui_Button(self.ctx, self.theme.letters[i])
    -- end
    reaper.ImGui_PopFont(self.ctx)
    -- reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    -- reaper.ImGui_DrawList_AddTextEx(draw_list, nil, self.theme.ICON_FONT_SMALL_SIZE, i_x, i_y, font_color, icon)
    -- reaper.ImGui_PopFont(self.ctx)
end

function LayoutEditor:main()
    if not self.open then
        return
    end
    reaper.ImGui_SetNextWindowSize(self.ctx, 400, 300)
    local visible, open = reaper.ImGui_Begin(self.ctx, self.windowLabel, true, reaper.ImGui_WindowFlags_TopMost()) ---begin popup
    self.open = open
    if visible then
        -- iterate display settings
        reaper.ImGui_Text(self.ctx, "Editing the layout!")
        self:fontButton()
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

---@param fx TrackFX
function LayoutEditor:edit(fx)
    --[[
   display a pop-up window with a widget for each of the settings.
    --]]
    self.fx = fx
    self.displaySettings = fx.displaySettings_copy
    self.open = true
    self.windowLabel = self.fx.name .. self.fx.index .. " - Layout Editor"
    self:main()
end

return LayoutEditor
