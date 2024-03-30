local Theme = Theme
---Reproduce the style of reaper’s Actions list window
---@param ctx ImGui_Context
---@return function PopMainWindowStyle
function MainWindowStyle(ctx)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1.0)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), Theme.colors.genlist_selbg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), Theme.colors.col_main_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), Theme.colors.genlist_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), Theme.colors.genlist_fg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), Theme.colors.genlist_seliabg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), Theme.colors.col_main_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), Theme.colors.genlist_seliabg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), Theme.colors.genlist_seliabg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(), Theme.colors.genlist_selbg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), Theme.colors.col_main_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), Theme.colors.genlist_bg.color)

    reaper.ImGui_PushFont(ctx, Theme.fonts.MAIN)
    return function()
        reaper.ImGui_PopStyleColor(ctx, 11)
        reaper.ImGui_PopStyleVar(ctx, 1)
        reaper.ImGui_PopFont(ctx)
    end
end

return MainWindowStyle
