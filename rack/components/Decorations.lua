local layout_enums = require("state.layout_enums")
local table_helpers = require("helpers.table")

local Decorations = {}

---@type deco_text
local default_deco_text = {
    type = layout_enums.DecorationType.text,
    Pos_X = 0,
    Pos_Y = 0,
    color = Theme.colors.col_env1.color,
    font_size = 12,
    _selected = false,
    guid = "",
    text = ""
}

---@type deco_line
local default_deco_line = {
    type      = layout_enums.DecorationType.line,
    _selected = false,
    Pos_X     = 0,
    Pos_Y     = 0,
    Pos_X_end = 0,
    Pos_Y_end = 20,
    guid      = "",
    color     = Theme.colors.col_env1.color,
    thickness = 2
}


---@type deco_rectangle
local default_deco_rectangle = {
    type = layout_enums.DecorationType.rectangle,
    Pos_X = 0,
    Pos_Y = 0,
    width = 20,
    height = 20,
    color = Theme.colors.col_env1.color,
    _selected = false,
    guid = "",
    rounding = 0.0
}

---@type deco_image
local default_deco_image = {
    type = layout_enums.DecorationType.rectangle,
    Pos_X = 0,
    Pos_Y = 0,
    width = 20,
    height = 20,
    keep_ratio = false,
    path = "",
    _selected = false,
    guid = "",
    image = nil
}

---@param fx TrackFX
function Decorations.createDecoration(fx)
    -- default decoration is a rectangle
    ---@type deco_rectangle
    local new_decoration = {
        type = layout_enums.DecorationType.rectangle,
        Pos_X = 0,
        Pos_Y = 0,
        color = Theme.colors.col_env1.color,
        width = 20,
        height = 20,
        _selected = false,
        rounding = 0.0,
        guid = "",
    }
    table.insert(fx.displaySettings.decorations, new_decoration)
    return new_decoration
end

---@param decoration Decoration
---@param new_type DecorationType
---@return Decoration
function Decorations.updateType(decoration, new_type)
    decoration.type = new_type
    local copy
    if new_type == layout_enums.DecorationType.rectangle then
        copy = table_helpers.deepCopy(default_deco_rectangle)
    elseif new_type == layout_enums.DecorationType.text then
        copy = table_helpers.deepCopy(default_deco_text)
    elseif new_type == layout_enums.DecorationType.line then
        copy = table_helpers.deepCopy(default_deco_line)
    elseif new_type == layout_enums.DecorationType.background_image then
        copy = table_helpers.deepCopy(default_deco_image)
    end

    -- remove extraneous keys from decoration
    for k, _ in pairs(decoration) do
        if copy[k] == nil then
            decoration[k] = nil
        end
    end

    -- add missing keys in decoration
    for k, v in pairs(copy) do
        if decoration[k] == nil then
            decoration[k] = v
        end
    end


    return decoration
end

---@param decoration Decoration
---@param ctx ImGui_Context
function Decorations.drawDecoration(ctx, decoration)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)

    -- text
    if decoration.type == layout_enums.DecorationType.text then
        reaper.ImGui_DrawList_AddTextEx(draw_list,
            nil,
            decoration.font_size,
            win_x + decoration.Pos_X,
            win_y + decoration.Pos_Y,
            decoration.color,
            decoration.text)

        -- line
    elseif decoration.type == layout_enums.DecorationType.line then
        -- assume vertical line for now
        reaper.ImGui_DrawList_AddLine(draw_list,
            win_x + decoration.Pos_X,
            win_y + decoration.Pos_Y,
            win_x + decoration.Pos_X_end,
            win_y + decoration.Pos_Y_end,
            decoration.color,
            decoration.thickness)

        -- rectangle
    elseif decoration.type == layout_enums.DecorationType.rectangle then
        reaper.ImGui_DrawList_AddRectFilled(draw_list,
            win_x + decoration.Pos_X,
            win_y + decoration.Pos_Y,
            win_x + decoration.Pos_X + decoration.width,
            win_y + decoration.Pos_Y + decoration.height,
            decoration.color,
            decoration.rounding,
            reaper.ImGui_DrawFlags_RoundCornersAll()
        )

        -- image
        -- FIXME image doesn't persist when layoutEditor closes
    elseif decoration.type == layout_enums.DecorationType.background_image and decoration.path ~= "" then
        if decoration.image == nil then
            local Image = reaper.ImGui_CreateImage(decoration.path)
            if Image then
                decoration.image = Image
            end
        end
        reaper.ImGui_DrawList_AddImage(draw_list,
            decoration.image,
            win_x + decoration.Pos_X,
            win_y + decoration.Pos_Y,
            win_x + decoration.Pos_X + decoration.width,
            win_y + decoration.Pos_Y + decoration.height
        )
    end
end

return Decorations
