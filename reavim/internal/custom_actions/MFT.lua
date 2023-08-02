local serpent = require("serpent")
local utils = require("custom_actions.utils")

local MFT = {}

---@alias FxDescr {name: string, params: FX_param[], idx: integer}

---@param input number
local function toHex(input)
    return string.format("%x", input)
end

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

---@return Mapping
local function createDummyMapping()
    local id = utils.uuid()
    return {
        id = id,
        name = id,
        glue = {
            step_size_interval = { 0.01, 0.05 },
            step_factor_interval = { 1, 5 },
        },
        target = {
            kind = "Dummy",
        }
    }
end


local function createLeftRightBankPagers() ---@return Mapping[]
    return {
        {
            name = "PAGE_LEFT",
            source = {
                kind = "Virtual",
                id = "bank-left",
                character = "Button",
            },
            glue = {
                absolute_mode = "IncrementalButton",
                reverse = true,
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
        {
            name = "PAGE_RIGHT",
            source = {
                kind = "Virtual",
                id = "bank-right",
                character = "Button",
            },
            glue = {
                absolute_mode = "IncrementalButton",
                step_size_interval = { 0.01, 0.05 },
            },
            target = {
                kind = "FxParameterValue",
                parameter = {
                    address = "ById",
                    index = 0,
                },
            }
        }
    }
end

local bank_ids = { "S4vSFtoLZyctXfOkWqd_7", "o4DaBaqXAgKHOezxw0fFl" --[[ , "1W2CM4HFJT2vuuPXu5fn_"  ]] }
local side_buttons = { "bank-left", "bank-right", "ch-left", "ch-right" }
local Colour = {
    { "10", "33", "62", "45", }, ---cyan, green, purple, yellow
    { "03", "65", "45", "4F", }  ---navy, purple, yellow, red
}

local function enumSelectedTrackFX(track) ---@param track MediaTrack
    local fxChain = reaper.CF_GetTrackFXChain(track)
    ---@type integer | nil
    local i = -1

    return function()
        i = reaper.CF_EnumSelectedFX(fxChain, i)
        if i < 0 then i = nil end
        return i
    end
end


---get fx and their params for the currently selected track
---@return FxDescr[]
local function getFx2()
    --- get selected track
    --- if fxchain windon for selected track is open
    --- get selected fx in fx chain
    local tr = reaper.GetSelectedTrack(0, 0)
    --- get open fx chain
    if reaper.TrackFX_GetChainVisible(tr) == -1 then return {} end
    local fx = {}
    for i in enumSelectedTrackFX(tr) do
        -- get fx name
        local rv, fx_name = reaper.TrackFX_GetFXName(tr, i)
        if not rv then return {} end
        -- get fx params
        local fx_params = {}
        for param_idx = 0, reaper.TrackFX_GetNumParams(tr, i) - 1 do
            local rv, param_name = reaper.TrackFX_GetParamName(tr, i, param_idx)
            local param_value, minval, maxval = reaper.TrackFX_GetParam(tr, i, param_idx)
            fx_params[#fx_params + 1] = {
                param_name = param_name,
                value = param_value,
                minval = minval,
                maxval = maxval,
                param_idx = param_idx,
            }
        end
        table.insert(fx, {
            idx = i,
            name = fx_name,
            params = fx_params,
        })
    end
    -- create a mapping with each of the fx params
    return fx
end

---@param bnk_idx number
local function createBank(bnk_idx)
    ---@type Bank
    local bank = {
        id = utils.uuid(),
        name = "BANK" .. bnk_idx,
        activation_condition = {
            kind = "Bank",
            parameter = 0,
            bank_index = bnk_idx - 1,
        },
    }
    return bank
end


function MFT.create_fx_map()
    local fx = getFx2()
    local pagers = createLeftRightBankPagers()
    local bnk_idx = 0
    local bnks = {} ---@type Bank[]
    local maps = {}
    -- iterate fx
    for fxIdx = 1, #fx do
        -- create bank for each fx
        table.insert(bnks, createBank(fxIdx))
        -- for each fx, iterate params
        for paramIdx = 1, #fx[fxIdx].params do
            if fx[fxIdx].params[paramIdx].param_name == "Delta" then goto continue end
            -- create a mapping for each param
            local map = createDummyMapping()
            map.name = --[[ fx[fxIdx].name .. " " ..  ]] fx[fxIdx].params[paramIdx].param_name
            -- add mapping to bank
            map.group = bnks[fxIdx].id
            map.source = {
                kind = "Virtual",
                id = paramIdx % 16 - 1, --- only 16 encoders on MFT
            }
            map.target = {
                kind = "FxParameterValue",
                parameter = {
                    address = "ByIndex",
                    fx = {
                        address = "ByIndex",
                        chain = {
                            address = "Track",
                        },
                        index = fx[fxIdx].idx,
                    },
                    index = paramIdx - 1,
                },
            }
            local colournum = Colour[bnk_idx % 2 > 0 and bnk_idx % 2 or 1]
                [paramIdx % 4 + 1]
            map.on_activate = {
                send_midi_feedback = {
                    {
                        kind = "Raw",
                        ---assign LED colours to buttons
                        message = "B1 " ..
                            "0" .. toHex(paramIdx - 1) .. " " .. colournum
                    },
                },
            }
            if string.match(fx[fxIdx].params[paramIdx].param_name, "Bypass") then
                map.source["character"] = "Button"
                map.glue = {
                    absolute_mode = "ToggleButton",
                    step_size_interval = { 0.01, 0.05 },
                }
                ---would be nice to be able to set the knob color to red when bypassed
                map.on_activate.send_midi_feedback.message = "B1 " ..
                    "0" .. toHex(paramIdx - 1) .. " 4F"
            end
            table.insert(maps, map)
            -- if there are more than 16 params, create a new bank
            if paramIdx % 16 == 0 then
                bnk_idx = bnk_idx + 1
            end
            ::continue::
        end
    end
    ---All controller mappings here.
    ---Bank selectors and bank mappings all go together.
    local main_compartment = {
        kind = "MainCompartment",
        version = "2.15.0",
        value = {
            groups = bnks,
            mappings = TableConcat(
                pagers,
                maps
            ),
        },
    }


    local lua_table_string = serpent.serialize(main_compartment, { comment = false }) -- stringify the modulator
    reaper.CF_SetClipboard(lua_table_string)
    return main_compartment
end

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

---@return Bank[]
local function createBanks()
    local banks = {}
    for i = 1, #bank_ids do
        ---@type Bank
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
            local color_deactivate = "B1 " .. "0" .. toHex(map_idx - 1) .. " " .. "00"
            local color = "B1 " .. "0" .. toHex(map_idx - 1) .. " " .. Colour[bnk_idx]
                [math.floor((map_idx - 1) / 4) + 1]

            local tags = {}
            table.insert(tags, "B" .. bnk_idx)
            local source_or_dest = (math.floor(map_idx / 9) == 0 and "dest" or "source")
            table.insert(tags, source_or_dest)
            ---@type Mapping
            local map = {
                id = name,
                name = name,
                group = bank_ids[bnk_idx],
                ---In order to use `EnableMappings` to switch between banks and conditionnally activate/deactivate mappings,
                ---**EVERY MAPPING MUST BE TAGGED**
                tags = tags,
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
                },
                on_deactivate = {
                    send_midi_feedback = {
                        {
                            kind = "Raw",
                            ---assign LED colours to buttons
                            message = color_deactivate
                        },
                    },
                }
            }
            table.insert(mappings, map)
        end
    end
    return mappings
end

---@type Mapping
local Enable_selectTag = {
    id = "Enable_selectTag",
    name = "Enable_selectTag",
    source = {
        kind = "Virtual",
        id = 12,
        character = "Button",
    },
    glue = {
        absolute_mode = "ToggleButton",
        out_of_range_behavior = "Ignore",
        step_size_interval = { 0.01, 0.05 },
    },
    target = {
        kind = "EnableMappings",
        tags = {
            -- "select",
            "source",
        },
    },
}
---@type Mapping
local Disable_selectTag = {
    id = "Disable_selectTag",
    name = "Disable_selectTag",
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
    }
}

---create the `raw` MIDI feedback for the MFT
---containing all the colours for all the encoders
---on a single line
---@param colour string
---@return string
local function color_all_encoders(colour)
    local rv = ""
    for map_idx = 1, 16 do
        local c = "B1 " .. "0" .. toHex(map_idx - 1) .. " " .. colour
        rv      = rv .. " " .. c
    end
    return rv
end

---@param colour1 string
---@param colour2 string
---@return string
local function color_half_encoders(colour1, colour2)
    local rv = ""
    for map_idx = 1, 16 do
        local colour = math.floor((map_idx - 1) / 8) == 0 and colour1 or colour2
        local c      = "B1 " .. "0" .. toHex(map_idx - 1) .. " " .. colour
        rv           = rv .. " " .. c
    end
    return rv
end


---@type Mapping
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
                message = color_half_encoders("4F", "00"),
                -- message = single_colour_all_encoders("4F"),
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

local Virtual_Btn_Actions = {
    VrtlBtn1 = "_RS86a658f69fadfd0c116968a473ed6b519f4c58cd",
    VrtlBtn2 = "_RS830a2f5bc01f783a8420b014d40d85ce347e6f9b",
    VrtlBtn3 = "_RS7ad216177f674727876f6db23cd4ec198c041924",
    VrtlBtn4 = "_RScad496a247fdbb534da3a99df0b31f12c6195699",
    VrtlBtn5 = "_RS32313842f86d8a75dd381cd4a388d9c9101142d9",
    VrtlBtn6 = "_RS616a6d79328be95d99b095362456360bce9573dc",
    VrtlBtn7 = "_RSb9c4a112e8da743767779d4ef215fda6e77f7944",
    VrtlBtn8 = "_RS5e00b697a621faca3c972d40b8490d284d28eba2",
    VrtlBtn9 = "_RSdc0e41cf2f89ed30e2937a6966919cd3b39c5525",
    VrtlBtn10 = "_RS3588e08b70e293b90143c06f4c7b8f1b5afe950c",
    VrtlBtn11 = "_RS1eac7a16f7d2356133a11c30ed1cfc25a5f71229",
    VrtlBtn12 = "_RS4c645ceca8f3d4ee8ead639378be705c07b7692f",
    VrtlBtn13 = "_RSf0e6daa0f6f654158be9723ed1c862cedb3cb074",
    VrtlBtn14 = "_RSacc0bd3a37bd607e5cc3267d2f73c2bb53e2ba1e",
    VrtlBtn15 = "_RSdb7cd88f6a4eeb04bdf368ea9d020504dc42f86f",
    VrtlBtn16 = "_RSf6dd39666432405992d1b844b90fd19ea3fb27b1",
}
local function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

---@return Mapping[]
local function create_virtual_btns()
    local rv = {} ---@type Mapping[]
    for i = 1, tablelength(Virtual_Btn_Actions) do
        local v = Virtual_Btn_Actions[i]
        local m = { ---@type Mapping
            id = "Btn" .. i,
            name = "Btn" .. i,
            source = {
                kind = "Virtual",
                id = i - 1,
                character = "Button",
            },
            glue = {
                out_of_range_behavior = "Ignore",
                step_size_interval = { 0.01, 0.05 },
            },
            target = {
                kind = "ReaperAction",
                command = v
            },
        }
        table.insert(rv, m)
    end
    return rv
end
---All controller mappings here.
---Bank selectors and bank mappings all go together.
local mappings = TableConcat(
    createBankSelectors(),
    { Map_RED_during_select_enable,
        Enable_selectTag, Disable_selectTag },
    createMappings(),
    create_virtual_btns()
)

function MFT.createMainCompartment()
    local main_compartment = {
        kind = "MainCompartment",
        version = "2.15.0",
        value = {
            groups = createBanks(),
            mappings = mappings,
        },
    }
    return main_compartment
end

return MFT
