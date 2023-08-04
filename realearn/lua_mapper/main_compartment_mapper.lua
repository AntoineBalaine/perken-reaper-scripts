-- @noindex
local utils = require("dependencies.utils")

local Main_compartment_mapper = {}

---@param ENCODERS_COUNT integer number of encoders on the current controller
function Main_compartment_mapper.Map_selected_fx_in_visible_chain(ENCODERS_COUNT)
  ---@alias FX_param {param_name: string, value: number, minval: number, maxval: number, param_idx: number, mapping: Mapping | nil}
  ---@alias FxDescr {name: string, params: FX_param[], idx: integer}


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
                utils.toHex(i - 1) .. " " .. "00"
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
            utils.toHex(paramidx_in_bnk) .. " " .. fx_colour ---assign LED colours to buttons here
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
  local function build_main_compartment()
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
              utils.toHex(paramIdx - 1) .. " 4F"
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
        mappings = utils.TableConcat(
          pagers,
          maps
        ),
      },
    }


    return main_compartment
  end
  return build_main_compartment()
end

return Main_compartment_mapper
