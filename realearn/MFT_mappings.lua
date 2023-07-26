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

--- Iterates over the given table, calling `cb(value, key, t)` for each element
---and collecting the returned values into a new table with the original keys.
--
---Entries are **not** guaranteed to be called in any specific order.
---@param t     table       A table
---@param cb    function    Will be called for each entry in the table and passed
---the arguments [value, key, t]. Should return a value.
---@return      table
local Tablemap = function(t, cb)
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
        on_activate = {
            send_midi_feedback = {
                {
                    kind = "Raw",
                    message =
                    "B1 00 10 B1 01 10 B1 02 10 B1 03 10 B1 04 33 B1 05 33 B1 06 33 B1 07 33 B1 08 62 B1 09 62 B1 0A 62 B1 0B 62 B1 0C 2C B1 0D 2C B1 0E 2C B1 0F 2C",
                },
            },
        },
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

--- mapping groups, named as Banks to match the MFT terminology
local Banks = {
    {
        id = "S4vSFtoLZyctXfOkWqd_7",
        name = "BANK1",
        activation_condition = {
            kind = "Bank",
            parameter = 0,
            bank_index = 0,
        },
    },
    {
        id = "o4DaBaqXAgKHOezxw0fFl",
        name = "BANK2",
        activation_condition = {
            kind = "Bank",
            parameter = 0,
            bank_index = 1,
        },
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
    B1 0C 2C
    B1 0D 2C
    B1 0E 2C
    B1 0F 2C ]]

---Bank 1 mappings, all triggering the virtual button actions in Reaper
local B1_mappings = {
    {
        id = "GKr6XIMDomfdBvdUgBWq2",
        name = "V1_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        on_activate = {
            send_midi_feedback = {
                {
                    kind = "Raw",
                    message = B1_colors,
                },
            },
        },
        source = {
            kind = "Virtual",
            id = 0,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS86a658f69fadfd0c116968a473ed6b519f4c58cd",
        },
    },
    {
        id = "3tICfLtgYaMUrEtRF-j0-",
        name = "V2_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 1,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
        },
    },
    {
        id = "VEGCtvC7As8JvuwAT7MDL",
        name = "V3_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 2,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS7ad216177f674727876f6db23cd4ec198c041924",
        },
    },
    {
        id = "f6s6xksXI1P5ORtfttJUQ",
        name = "V4_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 3,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RScad496a247fdbb534da3a99df0b31f12c6195699",
        },
    },
    {
        id = "O1TA84rxsfsXcWa9mt2gZ",
        name = "V5_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 4,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS32313842f86d8a75dd381cd4a388d9c9101142d9",
        },
    },
    {
        id = "3oGY61kvfdZkxdErl6YKW",
        name = "V6_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 5,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS616a6d79328be95d99b095362456360bce9573dc",
        },
    },
    {
        id = "T3ykjm7UmcEmWYhmrjl7i",
        name = "V7_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 6,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSb9c4a112e8da743767779d4ef215fda6e77f7944",
        },
    },
    {
        id = "T0PYrvAkeHortwH7pppcf",
        name = "V8_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 7,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS5e00b697a621faca3c972d40b8490d284d28eba2",
        },
    },
    {
        id = "1NXUfzIkeBH4g6bKDwPIC",
        name = "V9_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 8,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSdc0e41cf2f89ed30e2937a6966919cd3b39c5525",
        },
    },
    {
        id = "T3FPLb9UG3VsW-8nfVbK-",
        name = "V10_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 9,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS3588e08b70e293b90143c06f4c7b8f1b5afe950c",
        },
    },
    {
        id = "haeJA4ZU5996BpNFSMu2D",
        name = "V11_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 10,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS1eac7a16f7d2356133a11c30ed1cfc25a5f71229",
        },
    },
    {
        id = "0P-Hgcp8JmmvF7o7ruBM5",
        name = "V12_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 11,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS4c645ceca8f3d4ee8ead639378be705c07b7692f",
        },
    },
    {
        id = "dgPhcTy6G2NPNco8TJjBT",
        name = "V13_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 12,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSf0e6daa0f6f654158be9723ed1c862cedb3cb074",
        },
    },
    {
        id = "glcJ-aIJw_BtgwdA1gc92",
        name = "V14_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 13,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSacc0bd3a37bd607e5cc3267d2f73c2bb53e2ba1e",
        },
    },
    {
        id = "0US_gNl6HQE_r4horXCXn",
        name = "V15_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 14,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSdb7cd88f6a4eeb04bdf368ea9d020504dc42f86f",
        },
    },
    {
        id = "D_XTLXBMT0ujklhHfmLsq",
        name = "V16_B1",
        group = "S4vSFtoLZyctXfOkWqd_7",
        source = {
            kind = "Virtual",
            id = 15,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RSf6dd39666432405992d1b844b90fd19ea3fb27b1",
        },
    },
}

--[[ ---assign LED colours to buttons
B1_mappings = Tablemap(B1_mappings, function(v, k, t)
    v.on_activate = {
        send_midi_feedback = {
            {
                kind = "Raw",
                message = B1_colors:trim():split("\n\r")[k]
            },
        },
    }
    return v
end) ]]

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
---Bank 2 mappings, all triggering the virtual button actions in Reaper
local B2_mappings = {
    {
        id = "xymAWh9XDME-gCzIVUdYq",
        name = "V1_B2",
        group = "o4DaBaqXAgKHOezxw0fFl",
        on_activate = {
            send_midi_feedback = {
                {
                    kind = "Raw",
                    message = B2_colors
                },
            },
        },
        source = {
            kind = "Virtual",
            id = 0,
        },
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "ReaperAction",
            command = "RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
        },
    },
}



--[[ All controller mappings here.
Bank selectors and bank mappings all go together
]]
local mappings = TableConcat(
    B1_mappings,
    B2_mappings,
    Bank_selectors
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
