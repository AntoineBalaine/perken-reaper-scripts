---HELPER - concat a variable number of tables
---@param ... table[]
local function TableConcat(...)
    local t = {}
    ---@type number, table
    for _, v in ipairs({ ... }) do
        for i = 1, #v do
            t[#t + 1] = v[i]
        end
    end
    return t
end

---HELPER - Iterates over the given table, calling `cb(value, key, t)` for each element
---and collecting the returned values into a new table with the original keys.
--
---Entries are **not** guaranteed to be called in any specific order.
---@param t table
---@param cb function    Will be called for each entry in the table and passed the arguments [value, key, t]. Should return a value.
---@return table
function Tablemap(t, cb)
    local mapped = {}

    for k, v in pairs(t) do
        mapped[k] = cb(v, k, t)
    end

    return mapped
end

---HELPER - trim whitespace from string
function string.trim(s)
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

---HELPER - Separator can be one or more chars long in a single string. e.g.
---```lua
---string.split("a\nb", "\n\r")
---```
---returns `{"a", "b"}`
---@param s string
---@param separator string
function string.split(s, separator)
    ---@type string[]
    local arr = {}
    for line in s:gmatch("[^" .. separator .. "]+") do
        table.insert(arr, line)
    end
    return arr
end

---Bank selectors refers to side buttons on the MFT
local Bank_selectors = {
    {
        id = "05qt6I1vMb2VAB_iIcA4u",
        name = "B1_Select",
        source = {
            kind = "Virtual",
            id = "bank-left",
            character = "Button",
        },
        glue = {
            target_interval = { 0, 0 },
            out_of_range_behavior = "Min",
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "FxParameterValue",
            parameter = {
                address = "ById",
                index = 0,
            },
        },
    },
    {
        id = "a2y2AMUJMsKwoxsijcLXM",
        name = "B2_Select",
        source = {
            kind = "Virtual",
            id = "bank-right",
            character = "Button",
        },
        glue = {
            source_interval = { 0.01, 0.01 },
            target_interval = { 0.01, 0.01 },
            step_size_interval = { 0.01, 0.05 },
        },
        target = {
            kind = "FxParameterValue",
            parameter = {
                address = "ById",
                index = 0,
            },
        },
    },
}

local BankId1 = "S4vSFtoLZyctXfOkWqd_7"
local BankId2 = "o4DaBaqXAgKHOezxw0fFl"
local BankId3 = "1W2CM4HFJT2vuuPXu5fn_"

--- mapping groups, named as Banks to match the MFT terminology
local Banks = {
    {
        id = BankId1,
        name = "BANK1",
        activation_condition = {
            kind = "Bank",
            parameter = 0,
            bank_index = 0,
        },
    },
    {
        id = BankId2,
        name = "BANK2",
        activation_condition = {
            kind = "Bank",
            parameter = 0,
            bank_index = 1,
        },
    },
    {
        id = BankId3,
        name = "dummies",
    },
}

---Bank 1 colors
B1_colors = [[
    B1 00 10
    B1 01 10
    B1 02 10
    B1 03 10
    B1 04 33
    B1 05 33
    B1 06 33
    B1 07 33
    B1 08 62
    B1 09 62
    B1 0A 62
    B1 0B 62
    B1 0C 45
    B1 0D 45
    B1 0E 45
    B1 0F 45 ]]

---Bank 2 colors
local B2_colors = [[
    B1 00 03
    B1 01 03
    B1 02 03
    B1 03 03
    B1 04 65
    B1 05 65
    B1 06 65
    B1 07 65
    B1 08 45
    B1 09 45
    B1 0A 45
    B1 0B 45
    B1 0C 4F
    B1 0D 4F
    B1 0E 4F
    B1 0F 4F ]]

local RED_map_colors = [[
    B1 00 4F
    B1 01 4F
    B1 02 4F
    B1 03 4F
    B1 04 4F
    B1 05 4F
    B1 06 4F
    B1 07 4F
    B1 08 4F
    B1 09 4F
    B1 0A 4F
    B1 0B 4F
    B1 0C 4F
    B1 0D 4F
    B1 0E 4F
    B1 0F 4F ]]


---@return Mapping[]
local function createMappings()
    local mappings = {}
    local banks = 2
    local encoders = 16
    for bnk_idx = 1, banks do
        local bank_name = "B" .. bnk_idx
        local group_id = bnk_idx == 1 and BankId1 or BankId2
        for map_idx = 1, encoders do
            local name = "V" .. map_idx .. "_" .. bank_name
            ---@type Mapping
            local map = {
                id = name,
                name = name,
                group = group_id,
                source = {
                    kind = "Virtual",
                    id = map_idx,
                },
                target = {
                    kind = "Dummy"
                },
                glue = {
                    step_size_interval = { 0.01, 0.05 },
                    step_factor_interval = { 1, 5 }, ---default step factor
                },
                on_activate = {
                    send_midi_feedback = {
                        {
                            kind = "Raw",
                            ---assign LED colours to buttons
                            message = string.split(string.trim(bnk_idx == 1 and B1_colors or B2_colors), "\n\r")
                                [map_idx]
                        },
                    },
                }
            }
            table.insert(mappings, map)
        end
    end
    return mappings
end



local Enable_selectTag = {
    id = "GsGIrpIfvaAGLA66FXl8E",
    name = "Enable_selectTag",
    group = BankId3,
    source = {
        kind = "Virtual",
        id = 12,
        character = "Button",
    },
    glue = {
        out_of_range_behavior = "Ignore",
        step_size_interval = { 0.01, 0.05 },
        step_factor_interval = { 1, 5 },
    },
    target = {
        kind = "EnableMappings",
        tags = {
            "select",
        },
        exclusivity = "Exclusive",
    },
}

local Map_RED_during_select_enable = {
    id = "yrG1get-yMWFTT-EYpCzt",
    name = "COLORS",
    tags = {
        "select",
    },
    control_enabled = false,
    on_activate = {
        send_midi_feedback = {
            {
                kind = "Raw",
                message = RED_map_colors,
            },
        },
    },
    glue = {
        source_interval = { 0, 0.01 },
        target_interval = { 0.01, 0.01 },
        step_size_interval = { 0.01, 0.05 },
    },
    target = {
        kind = "Dummy",
    },
}

--[[ All controller mappings here.
Bank selectors and bank mappings all go together
]]
local mappings = TableConcat(
    createMappings(),
    Bank_selectors,
    Map_RED_during_select_enable,
    Enable_selectTag
)


local main_compartment = {
    kind = "MainCompartment",
    version = "2.15.0",
    value = {
        groups = Banks,
        mappings = mappings,
    },
}
return main_compartment
