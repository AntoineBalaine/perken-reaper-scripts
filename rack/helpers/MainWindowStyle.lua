---Reproduce the style of reaper’s Actions list window
---@param ctx ImGui_Context
---@param theme Theme
---@return integer colors
---@return integer style_vars
---@return integer fonts
function MainWindowStyle(ctx, theme)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1.0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), theme.colors.genlist_selbg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), theme.colors.col_main_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), theme.colors.genlist_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), theme.colors.genlist_fg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), theme.colors.genlist_seliabg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), theme.colors.col_main_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), theme.colors.genlist_seliabg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), theme.colors.genlist_seliabg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(), theme.colors.genlist_selbg.color)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), theme.colors.col_main_bg.color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), theme.colors.genlist_bg.color)

    reaper.ImGui_PushFont(ctx, theme.fonts.MAIN)
    return 11, 1, 1
end

return MainWindowStyle
