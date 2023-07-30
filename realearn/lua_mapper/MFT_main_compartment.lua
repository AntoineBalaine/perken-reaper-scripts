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

local bank_ids = { "S4vSFtoLZyctXfOkWqd_7", "o4DaBaqXAgKHOezxw0fFl" --[[ , "1W2CM4HFJT2vuuPXu5fn_"  ]] }
local side_buttons = { "bank-left", "bank-right", "ch-left", "ch-right" }
local Colour = {
    { "10", "33", "62", "45", }, ---cyan, green, purple, yellow
    { "03", "65", "45", "4F", }  ---navy, purple, yellow, red
}

---Bank selectors are to be switched with side buttons of MFT
local function createBankSelectors()
    local selectors = {}
    for i = 1, #bank_ids do
        local selector = {
            -- id = Bank_selectors[i].id,
            name = "Bank_selector" .. i,
            source = {
                kind = "Virtual",
                id = side_buttons[i],
                character = "Button",
            },
            glue = {
                target_interval = { (i - 1) / 100, (i - 1) / 100 },
                step_size_interval = { 0.01, 0.05 },
            },
            target = {
                kind = "FxParameterValue",
                parameter = {
                    address = "ById",
                    index = 0,
                },
            },
        }
        table.insert(selectors, selector)
    end
    return selectors
end

local function createBanks()
    local banks = {}
    for i = 1, #bank_ids do
        local bank = {
            id = bank_ids[i],
            name = "BANK" .. i,
            activation_condition = {
                kind = "Bank",
                parameter = 0,
                bank_index = i - 1,
            },
        }
        table.insert(banks, bank)
    end
    return banks
end

---@param input number
local function toHex(input)
    return string.format("%x", input)
end

---For each of the banks listed in `banks`, create a mapping for each of the `encoders`.
---
---Assign a mapping name following the pattern `V{encoder}_B{bank}` eg `V1_B1` for the first encoder in bank 1.
---Assign one colour per bank per row, pull the colours from the `Colour` table.
---
---All targets are `Dummy` targets, so they don't do anything.
---@return Mapping[]
local function createMappings()
    local mappings = {}
    local banks = 2
    local encoders = 16
    for bnk_idx = 1, banks do
        for map_idx = 1, encoders do
            local name = "V" .. map_idx .. "_" .. "B" .. bnk_idx
            ---Model the LED feedback
            ---using `B1 00 4F` as an example.
            ---
            ---B1 refers to Bank 1, which is the only bank we'll use internally from the MFT (the bank logic is re-implemented at relearn's level)
            ---
            ---00 is the encoder/knob number,
            ---
            ---4F is the colour
            local color = "B1 " .. "0" .. toHex(map_idx - 1) .. " " .. Colour[bnk_idx]
                [math.floor((map_idx - 1) / 4) + 1]

            ---@type Mapping
            local map = {
                id = name,
                name = name,
                group = bank_ids[bnk_idx],
                ---In order to use `EnableMappings` to switch between banks and conditionnally activate/deactivate mappings,
                ---**EVERY MAPPING MUST BE TAGGED**
                tags = {
                    "B" .. bnk_idx,
                },
                source = {
                    kind = "Virtual",
                    id = map_idx - 1,
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
                            message = color
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
    id = "Enable_selectTag",
    name = "Enable_selectTag",
    source = {
        kind = "Virtual",
        id = side_buttons[4],
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

---create the `raw` MIDI feedback for the MFT
---containing all the colours for all the encoders
---on a single line
---@param colour string
local function single_colour_all_encoders(colour)
    local rv = ""
    for map_idx = 1, 16 do
        local c = "B1 " .. "0" .. toHex(map_idx - 1) .. " " .. colour
        rv      = rv .. " " .. c
    end
    return rv
end

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
                message = single_colour_all_encoders("4F"),
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

---All controller mappings here.
---Bank selectors and bank mappings all go together.
local mappings = TableConcat(
    createBankSelectors(),
    { Map_RED_during_select_enable,
        Enable_selectTag },
    createMappings()
)


local main_compartment = {
    kind = "MainCompartment",
    version = "2.15.0",
    value = {
        groups = createBanks(),
        mappings = mappings,
    },
}
return main_compartment
