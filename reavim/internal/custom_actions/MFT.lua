local serpent = require("serpent")
local utils = require("custom_actions.utils")

local MFT = {}
---number of encoders on the Midi Fighter Twister
ENCODERS_COUNT = 16

---@alias FX_param {param_name: string, value: number, minval: number, maxval: number, param_idx: number, mapping: Mapping | nil}
---@alias FxDescr {name: string, params: FX_param[], idx: integer}

---convert a number to hex.
---Hex number has to be 2 characters-long, with leading 0 if necessary
---@param input integer
local function toHex(input)
    return string.format("%02x", input)
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

---Create a dummy mapping, containing a unique ID and the base glue and target sections.
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
    { "62", "33", "10", "45", }, ---cyan, green, purple, yellow
    { "65", "45", "03", "4F", }  ---navy, purple, yellow, red
}
---not sure about the color descriptions here
local Color_list = {
    "10", -- cyan
    "45", -- yellow
    "03", -- navy
    "33", -- green
    "4F", -- red
    "62", -- ??
    "65", -- ??
    "7F", -- ??

}

---generate a random colour in hex format.
---This is unused for now, I dunno why but realearn won't eat its output
local function randomColour()
    math.randomseed(os.time())
    -- Generate a random number between 1 and 127
    local randomNumber = math.random(126)

    return string.upper(string.format("%02x", randomNumber))
end


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

---create a bank for the given bnk_idx
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

---Count number of valid mappings in current fx.
---Typically, the «Delta» param is not mapped, so we don't count it
---@param fx FxDescr
---@return integer
local function countMappings(fx)
    -- iterate over fx params
    --- if param~=nil, increment count
    ---return count
    local count = 0
    for _, param in ipairs(fx.params) do
        if param ~= nil then
            count = count + 1
        end
    end
    return count
end

---create dummy mappings in current bank for all available encoder slots
---@param bnk_id string
---@param bnk_idx integer
---@param dummies_start_idx integer
local function create_dummies(bnk_id, bnk_idx, dummies_start_idx)
    local dummies = {} ---@type Mapping[]
    -- create dummy mappings for the rest of the encoders
    for i = dummies_start_idx, ENCODERS_COUNT do
        local dummy_mapping = createDummyMapping()
        dummy_mapping.name = "_"
        dummy_mapping.group = bnk_id
        dummy_mapping.activation_condition = {
            kind = "Bank",
            parameter = 0,
            bank_index = bnk_idx,
        }
        dummy_mapping.source = {
            kind = "Virtual",
            id = i - 1,
        }
        dummy_mapping.on_activate = {
            send_midi_feedback = {
                {
                    kind = "Raw",
                    ---assign black to dummy params
                    message = "B1 " ..
                        toHex(i - 1) .. " " .. "00"
                },
            },
        }
        table.insert(dummies, dummy_mapping)
    end
    return dummies
end

---Create banks for the FX, and update mappings to assign pages to the FX's params
---
---Each page contains one or multiple FX, and the breakout of the pages
---tries to avoid having to break an FX across multiple pages.
---
---Each FX is assigned its own colour.
---
---Add an empty page at the end, to signal the last page
---@param fx FxDescr[]
---@return Bank[] bnks
---@return Mapping[] fx
local function build_banks(fx)
    local bnk_idx = -1
    local bnks = {} ---@type Bank[]
    local mappings_in_current_bank = 0
    local maps = {} ---@type Mapping[]
    local paramidx_in_bnk = -1
    local colorIdx = 0
    --[[
        for each fx, check whether the next fx and the current one can fit in the current bank.
        if so, include them
        if not, only include the current fx in the current bank
            increment bank
    ]]
    for fxIdx = 1, #fx do
        colorIdx = colorIdx + 1
        ---pick a random index from C
        local fx_colour = Color_list[colorIdx % #Color_list]
        --[[ if remaining slots in bank >= #fx[fxIdx].params
            include fx[fxIdx] in current bank
        else
            increment bank
            update each param to be assigned to current bank
            include fx[fxIdx] in current bank
      ]]
        local map_count = countMappings(fx[fxIdx])
        ---TODO: check if there are enough slots in the current bank
        --- what happens if bank is empty but it doesn't have enough slots for current FXparams?
        if mappings_in_current_bank + map_count <= ENCODERS_COUNT and bnk_idx ~= -1 then
            -- include fx[fxIdx] in current bank
            mappings_in_current_bank = mappings_in_current_bank + map_count
        else
            -- increment bank
            bnk_idx = bnk_idx + 1
            mappings_in_current_bank = 0
            paramidx_in_bnk = -1
            local bnk = createBank(bnk_idx)
            bnk.activation_condition.bank_index = bnk_idx
            table.insert(bnks, bnk)
        end
        -- create bank for each fx
        -- for each fx, iterate params
        for paramIdx = 1, #fx[fxIdx].params do
            local param = fx[fxIdx].params[paramIdx]
            if param.mapping == nil then goto continue end ---if fx has no mapping, continue
            param.mapping.activation_condition.bank_index = bnk_idx
            paramidx_in_bnk = paramidx_in_bnk + 1
            param.mapping.source.id = paramidx_in_bnk
            param.mapping.on_activate.send_midi_feedback[1].message = "B1 " ..
                toHex(paramidx_in_bnk) .. " " .. fx_colour ---assign LED colours to buttons here
            table.insert(maps, param.mapping)
            ::continue::
        end
        -- if next page is goingq to go to a new bank, fill left over slots in current bank with dummies
        if fx[fxIdx + 1] == nil or mappings_in_current_bank + countMappings(fx[fxIdx + 1]) > ENCODERS_COUNT then
            local loopIdx = paramidx_in_bnk + 1
            local dummies = create_dummies(bnks[#bnks].id, bnk_idx, loopIdx)
            --- insert each dummy into the current bank
            mappings_in_current_bank = mappings_in_current_bank + #dummies
            for _, dummy in ipairs(dummies) do
                paramidx_in_bnk = paramidx_in_bnk + 1
                table.insert(maps, dummy)
            end
        end
    end
    -- add a page of empty mappings
    local empty_bnk = createBank(bnk_idx + 1)
    empty_bnk.activation_condition.bank_index = bnk_idx + 1
    table.insert(bnks, empty_bnk)
    -- add a page of empty mappings
    local dummies = create_dummies(bnks[#bnks].id, bnk_idx + 1, 1)
    for _, dummy in ipairs(dummies) do
        paramidx_in_bnk = paramidx_in_bnk + 1
        table.insert(maps, dummy)
    end

    return bnks, maps
end

---Create main compartment mapping for the selected FX in the visible FX chain.
---Add a mapping for each parameter of the selected FX, assign bank pages to them,
---assign colours to the encoders LEDs, and copy the resulting main compartment mapping
---into the system clipboard.
---
---The resulting clipboard is meant to be pasted into the main compartment mapping,
---the «Import from clipboard» button in Realearn.
---
---**Linux users**: don't try to paste directly into realern, it will crash.
---Try to paste into a text editor first, and then copy from there into realern.
function MFT.create_fx_map()
    local fx = getFx2()
    local pagers = createLeftRightBankPagers()
    -- iterate fx
    for fxIdx = 1, #fx do
        -- create bank for each fx
        -- table.insert(bnks, createBank(fxIdx))
        -- for each fx, iterate params
        for paramIdx = 1, #fx[fxIdx].params do
            -- create a mapping for each param
            local map = createDummyMapping()
            map.name = --[[ fx[fxIdx].name .. " " ..  ]] fx[fxIdx].params[paramIdx].param_name
            -- add mapping to bank
            map.activation_condition = {
                kind = "Bank",
                parameter = 0,
                bank_index = -1,
            }
            map.source = {
                kind = "Virtual",
                id = paramIdx % ENCODERS_COUNT - 1, --- only 16 encoders on MFT, this will be modifed in `build_banks`
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
            map.on_activate = {
                send_midi_feedback = {
                    {
                        kind = "Raw",
                        ---don't assign LED colours to buttons here, but in `build_banks`
                    },
                },
            }
            --[[removing the «deactivate» feedback for now,
            as it it suffers from a bug I've reported here: https://github.com/helgoboss/realearn/issues/879
            ]]
            --[[             map.on_deactivate = {
                send_midi_feedback = {
                    {
                        kind = "Raw",
                        ---assign LED colours to buttons
                        message = "B1 " ..
                            "0" .. toHex(paramIdx - 1) .. " 00"
                    },
                },
            } ]]
            if string.match(fx[fxIdx].params[paramIdx].param_name, "Bypass") then
                map.source["character"] = "Button"
                map.glue = {
                    absolute_mode = "ToggleButton",
                    step_size_interval = { 0.01, 0.05 },
                }
                ---would be nice to be able to set the knob color to red when bypassed
                map.on_activate.send_midi_feedback.message = "B1 " ..
                    toHex(paramIdx - 1) .. " 4F"
            end
            local isDeltaParam = fx[fxIdx].params[paramIdx].param_name == "Delta"
            if not isDeltaParam then
                fx[fxIdx].params[paramIdx].mapping = map
            end
        end
    end
    local bnks, maps = build_banks(fx)
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
    for bnk_idx = 1, banks do
        for map_idx = 1, ENCODERS_COUNT do
            local name = "V" .. map_idx .. "_" .. "B" .. bnk_idx
            ---Model the LED feedback
            ---using `B1 00 4F` as an example.
            ---
            ---B1 refers to Bank 1, which is the only bank we'll use internally from the MFT (the bank logic is re-implemented at relearn's level)
            ---
            ---00 is the encoder/knob number,
            ---
            ---4F is the colour
            local color_deactivate = "B1 " .. toHex(map_idx - 1) .. " " .. "00"
            local color = "B1 " .. toHex(map_idx - 1) .. " " .. Colour[bnk_idx]
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
    for map_idx = 1, ENCODERS_COUNT do
        local c = "B1 " .. toHex(map_idx - 1) .. " " .. colour
        rv      = rv .. " " .. c
    end
    return rv
end

---@param colour1 string
---@param colour2 string
---@return string
local function color_half_encoders(colour1, colour2)
    local rv = ""
    for map_idx = 1, ENCODERS_COUNT do
        local colour = math.floor((map_idx - 1) / 8) == 0 and colour1 or colour2
        local c      = "B1 " .. toHex(map_idx - 1) .. " " .. colour
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
