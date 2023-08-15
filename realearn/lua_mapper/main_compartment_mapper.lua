-- @noindex
local utils = require("dependencies.utils")

local Main_compartment_mapper = {}

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

---Create a «do nothing» mapping, containing a unique ID and the base glue and target sections.
---@return Mapping
local function createIdleMapping()
  local id = utils.uuid()
  return {
    id = id,
    name = id,
    target = {
      kind = "Track",
      track = {
        address = "This",
        track_must_be_selected = true,
      },
      action = "DoNothing",
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
        track_must_be_selected = true,
        kind = "FxParameterValue",
        parameter = {
          address = "ById",
          index = 0,
          chain = {
            address = "Track",
            track = {
              address = "This",
              track_must_be_selected = true,
            }
          },
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
          chain = {
            address = "Track",
            track = {
              address = "This",
              track_must_be_selected = true,
            }
          },
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

---create dummy mappings in current bank for all available encoder slots
---@param bnk_id string
---@param bnk_idx integer
---@param dummies_start_idx integer
---@param ENCODERS_COUNT integer
local function create_dummies(bnk_id, bnk_idx, dummies_start_idx, ENCODERS_COUNT)
  local dummies = {} ---@type Mapping[]
  -- create dummy mappings for the rest of the encoders
  for i = dummies_start_idx, ENCODERS_COUNT do
    local idle_mapping = createIdleMapping()
    idle_mapping.name = "_"
    idle_mapping.group = bnk_id
    idle_mapping.activation_condition = {
      kind = "Bank",
      parameter = 0,
      bank_index = bnk_idx,
    }
    idle_mapping.on_activate = {
      send_midi_feedback = {
        {
          kind = "Raw",
          ---assign black to dummy params
          message = "B1 " ..
              utils.toHex(i - 1) .. " " .. "00"
        },
      },
    }
    table.insert(dummies, idle_mapping)
  end
  return dummies
end

---Count number of valid mappings in current fx.
---Typically, the «Delta» param is not mapped, so we don't count it
---@param fx FxDescr
---@return integer
local function countValidMappings(fx)
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

---@param ENCODERS_COUNT integer
local function Bankk(ENCODERS_COUNT)
  ---@class BNK
  ---@field data {maps: Mapping[], bnk: Bank}[]
  local B = {}
  B.data = {}
  B.pageIdx = -1

  B.colorIdx = 0
  function B:increment_color()
    self.colorIdx = self.colorIdx + 1 % #Color_list
    return Color_list[self.colorIdx]
  end

  function B:init()
    self:new_page()
    return self
  end

  function B:cur_maps_in_page()
    local count = 0
    for i, map in pairs(self.data[self.pageIdx].maps) do
      if map.target.kind ~= "Dummy" then
        count = count + 1
      end
    end
    return count
  end

  function B:fill_left_over_space_in_last_bank_with_dummies()
    local last_bank = self.data[self.pageIdx].bnk
    local last_bank_idx = #self.data[self.pageIdx].maps
    local dummies_start_idx = last_bank_idx + 1
    local dummies = create_dummies(last_bank.id, self.pageIdx, dummies_start_idx, ENCODERS_COUNT)
    for _, dummy in ipairs(dummies) do
      table.insert(self.data[self.pageIdx].maps, dummy)
    end
  end

  function B:add_dummies_page()
    self:new_page()
    local dummies = create_dummies(self.data[self.pageIdx].bnk.id, self.pageIdx, 1, ENCODERS_COUNT)
    for _, dummy in ipairs(dummies) do
      table.insert(self.data[self.pageIdx].maps, dummy)
    end
  end

  ---@param fx FxDescr
  function B:insert_fx(fx)
    local fx_colour = self:increment_color()
    for i, param in pairs(fx.params) do
      if param.mapping == nil then goto continue end ---if fx has no mapping, continue
      -- REPLACE THE DUMMIES, DON'T JUST ADD TO THEM
      self:insert(param.mapping, fx_colour)
      ::continue::
    end
  end

  function B:find_available_idx()
    return #self.data[self.pageIdx].maps + 1
  end

  ---@param map Mapping
  ---@param fx_colour string | nil
  function B:insert(map, fx_colour)
    if fx_colour == nil then fx_colour = "00" end
    -- if current bank is full, create a new one
    -- else, add to current bank
    if self:cur_maps_in_page() >= ENCODERS_COUNT then
      self:new_page()
    end
    local encoder_id = self:find_available_idx()
    -- TODO IS THIS THE PROBLEM

    map.group = self.data[self.pageIdx].bnk.id
    map.activation_condition.bank_index = self.pageIdx
    map.source.id = encoder_id - 1 -- does this need to be zero-indexed
    -- map.source = { kind = "Virtual", id = encoder_id }
    map.on_activate = {
      send_midi_feedback = { {
        kind = "Raw",
        message = "B1 " ..
            utils.toHex((encoder_id - 1) % ENCODERS_COUNT) ..
            " " .. fx_colour ---assign LED colours to buttons here
      } }
    }
    -- insert into maps
    -- replace dummy mapping with new mapping
    table.insert(self.data[self.pageIdx].maps, map)
  end

  function B:new_page()
    self.pageIdx = self.pageIdx + 1
    local bnk = createBank(self.pageIdx)
    bnk.activation_condition.bank_index = self.pageIdx
    self.data[self.pageIdx] = {
      maps = {},
      bnk = bnk,
    }
  end

  function B:get_maps()
    -- reduce to get all banks
    local maps = {}
    for _, datum in pairs(self.data) do
      for _, map in pairs(datum.maps) do
        table.insert(maps, map)
      end
    end
    return maps
  end

  function B:get_bnks()
    -- reduce to get all banks
    local bnks = {}
    for _, bnk in pairs(self.data) do
      table.insert(bnks, bnk.bnk)
    end
    return bnks
  end

  return B:init()
end

---@param ENCODERS_COUNT integer number of encoders on the current controller
function Main_compartment_mapper.Map_selected_fx_in_visible_chain(ENCODERS_COUNT)
  ---@param fx FxDescr[]
  ---@return Bank[] bnks
  ---@return Mapping[] fx
  local function build(fx)
    local bnks = Bankk(ENCODERS_COUNT)
    for _, fx in pairs(fx) do
      bnks:insert_fx(fx)
    end
    bnks:fill_left_over_space_in_last_bank_with_dummies()
    bnks:add_dummies_page()
    return bnks:get_bnks(), bnks:get_maps()
  end

  ---@param maps Mapping[]
  local function count_maps_in_bank(maps, bnk_idx)
    local count = 0
    local cur_group = nil
    -- everytime we find a mapping with a different group, we increment the count
    for i, map in pairs(maps) do
      if map.activation_condition.bank_index == bnk_idx then
        count = count + 1
      end
    end
    return count
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
                track = {
                  address = "This",
                  track_must_be_selected = true,
                }
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
    local bnks, maps = build(fx)
    -- local bnks, maps = build_banks(fx)

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
