--[[
A color palette, containing a color picker and the list of reaper’s theme colors.
]]

---store the backup color in module context
---@type integer
local backup_color

---Display a button that opens a color picker, in a popup with the list of reaper’s theme colors.
---@param ctx ImGui_Context
---@param theme Theme
---@param cur_col integer
---@param name string
function Palette(ctx, theme, cur_col, name)
    local changed = false
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), cur_col)
    local open_popup = reaper.ImGui_Button(ctx, "##Theme_palette" .. name, 20, 20)
    reaper.ImGui_PopStyleColor(ctx)
    if open_popup then
        reaper.ImGui_OpenPopup(ctx, "Theme_palette" .. name)
        backup_color = cur_col
    end
    reaper.ImGui_SetNextWindowSize(ctx, 470, 295)
    if reaper.ImGui_BeginPopup(ctx, "Theme_palette" .. name) then
        reaper.ImGui_Separator(ctx)
        changed, cur_col = reaper.ImGui_ColorPicker4(ctx, "##picker",
            cur_col,
            reaper.ImGui_ColorEditFlags_NoSidePreview() | reaper.ImGui_ColorEditFlags_NoSmallPreview())
        if changed then
            cur_col = reaper.ImGui_ColorConvertNative(cur_col)
        end
        reaper.ImGui_SameLine(ctx)

        reaper.ImGui_BeginGroup(ctx) -- Lock X position
        reaper.ImGui_BeginGroup(ctx) -- Lock next items to be on the same line
        reaper.ImGui_Text(ctx, "Current")
        reaper.ImGui_ColorButton(ctx, "##current",
            cur_col,
            reaper.ImGui_ColorEditFlags_NoPicker() |
            reaper.ImGui_ColorEditFlags_AlphaPreviewHalf(), 60, 40)
        reaper.ImGui_EndGroup(ctx)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_BeginGroup(ctx) -- Lock next items to be on the same line
        reaper.ImGui_Text(ctx, "Previous")
        if reaper.ImGui_ColorButton(ctx, "##previous", backup_color,
                reaper.ImGui_ColorEditFlags_NoPicker() |
                reaper.ImGui_ColorEditFlags_AlphaPreviewHalf(), 60, 40) then
            cur_col = backup_color
        end
        reaper.ImGui_EndGroup(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "Theme Colors")
        if reaper.ImGui_BeginChild(ctx, "##themecolorspalette", nil) then
            for count, col in ipairs(theme.colors_by_name) do
                local col_name = col[1]
                local color = col[2].color
                local description = col[2].description
                reaper.ImGui_PushID(ctx, col_name)
                if ((count - 1) % 8) ~= 0 then
                    reaper.ImGui_SameLine(ctx, 0.0,
                        select(2, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())))
                end


                if reaper.ImGui_ColorButton(ctx, description .. "##palette", color, reaper.ImGui_ColorEditFlags_NoPicker(), 20, 20) then
                    cur_col = color
                    changed = true
                end

                -- Allow user to drop colors into each palette entry. Note that ColorButton() is already a
                -- drag source by default, unless specifying the ImGuiColorEditFlags_NoDragDrop flag.
                if reaper.ImGui_BeginDragDropTarget(ctx) then
                    local drop_color
                    -- rv, drop_color = reaper.ImGui_AcceptDragDropPayloadRGB(ctx)
                    -- if rv then
                    --     theme.colors[name].color = drop_color
                    -- end
                    rv, drop_color = reaper.ImGui_AcceptDragDropPayloadRGBA(ctx)
                    if rv then
                        theme.colors[name].color = reaper.ImGui_ColorConvertNative(drop_color)
                    end
                    reaper.ImGui_EndDragDropTarget(ctx)
                end
                reaper.ImGui_PopID(ctx)
            end
            reaper.ImGui_EndChild(ctx)
        end
        reaper.ImGui_EndGroup(ctx)
        reaper.ImGui_EndPopup(ctx)
    end
    return changed, cur_col
end

return Palette
