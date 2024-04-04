local layout_enums = require("state.layout_enums")
local table_helpers = require("helpers.table")

local deco_helpers = {}

---@type deco_text
local default_deco_text = {
    type = layout_enums.DecorationType.text,
    Pos_X = 0,
    Pos_Y = 0,
    color = Theme.colors.col_env1.color,
    font_size = 12,
    weight = 400,
    _selected = false,
    guid = "",
}

---@type deco_line
local default_deco_line = {
    type      = layout_enums.DecorationType.line,
    _selected = false,
    Pos_X     = 0,
    Pos_Y     = 0,
    guid      = "",
    color     = Theme.colors.col_env1.color,
    thickness = 2,
    length    = 20,
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
    guid = ""
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
    guid = ""
}

---@param fx TrackFX
function deco_helpers.createDecoration(fx)
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
        guid = "",
    }
    table.insert(fx.displaySettings.decorations, new_decoration)
    return new_decoration
end

---@param decoration Decoration
---@param new_type DecorationType
---@return Decoration
function deco_helpers.updateType(decoration, new_type)
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

return deco_helpers
