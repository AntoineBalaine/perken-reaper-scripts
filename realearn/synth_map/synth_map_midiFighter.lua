-- @description Midi-fighter-twister: Synth map
-- @version 0.0.1
-- @author Perken
-- @provides
--  utils/serpent.lua
--  utils/utils.lua
--  synth_map_midiFighter.lua
-- @about
--   # synth_map_midiFighter.lua
--   HOW TO USE:
--   - have a realearn instance with the Midi fighter's preset loaded in the controller compartment.
--   - call the script
--   - focus the realearn window,
--   - click «import from clipboard»
--   - NB LINUX USERS: realearn struggles to read from clipboard directly, you might have to paste into a text editor first, and then copy from there.
--
--    Here's how it's designed:
--    2 pages of mappings:
--      Synth page:
--        One row for oscillators
--        One row for Filters
--        One row for Envelopes
--        One row for LFOs
--      FX page:
--        One row for Distortion
--        One row for Chorus
--        One row for Delay
--        One row for Reverb
--
--    Each row contains 4 encoders, and 1 param is assigned per encoder. Let's take the Oscillators row for example:
--    If the midi-fighter's row has only 4 encoders, how can I control 3 oscillators X4 params with it? The solution is to use layers. So, pressing the first button of the row will switch between the controls of each of the oscillators of the Synth:
--    Row1:
--      Layer 1: Osc1 (navy LED)
--      Layer 2: Osc2 (yellow LED)
--      Layer 3: Sub (green LED)
--      Layer 4: Noise Osc (cyan LED)
--    Row2:
--      Layer 1: FilterA (red LED)
--      Layer 2: FilterB (purple LED)
--    Row3:
--      Layer 1: Filter Envelope (red LED)
--      Layer 2: Amp Envelope (yellow LED)
--      Layer 2: Pitch Envelope (purple LED)
--    Row4:
--      Layer 1: LFO1 (light blue LED)
--      Layer 2: LFO2 (navy LED)
--
--    for each row, the controls of each layer are the same:
--    Encoders:
--    Row1 (Osc): Octave | Coarse | wave shape | level/volume
--    Row2 (Flt): cutoff | res.   | ???        | drive/mix
--    Row3 (Env): attack | decay  | sustain    | release / amount(press and turn)
--    Row4 (LFO): shape  | rate   | ???        | amount / destination(on click)
--
--    Now that you get the gist of how I've imagined the layers, here's the layout of the synth page as structured text:
--      Synth page:
--        OSC 4layers(#1,  #2,  sub, noise) Encoders(Oct,    Coarse, WaveShape, Volume)
--        FLT 2layers(#A,  #B,  /,   /    ) Encoders(Cutoff, Res.,   Drive,     Mix)
--        ENV 3layers(Flt, Amp, ptch, /   ) Encoders(Atk,    Decay,  Sstn,      Release)
--                                          BtnPress(/,      /,      /,         Amount)
--        LFO 2layers(lf1, lf2, /,   /    ) Encoders(Shape,  Rate,   ???,       Amount)
--                                          BtnPress(/,      /,      /,         Destination)
--
--    The mapping has a second page, dedicated to FX, with the classics: distortion, chorus, delay and reverb.
--      FX page:
--        row1 (Distortion) Drive | ???    |  ???  | ??? /Mix(press and turn)
--        row2 (Chorus)     Rate  | Dly1   | Dly2  | Fdbk/Mix(press and turn)
--        row3 (Delay)      Speed | ???    |  ???  | Fdbk/Mix(press and turn)
--        row4 (Reverb)     Size  | Densty | HiCut | LoCut/Mix(press and turn)
--
--    The mapping provides some visual feedback by showing the LEDs of the layer that are active at the moment:
--    Layer1 will activate the first LED of the row. When it's active, all the other LEDs are turned off in the row
--    Layer2 will activate the second LED of the row.
--    etc.
--    Also, since the Envelopes and LFOs have an amount button, the color of that button matches the destination: Red is for Filter A, Yellow is for Amp, Cyan is for Pitch, Purple is for Filter B.
--
--    Please let me know if this explanation was clear enough, and if you'd like to make a donation, please send it to Helgoboss ;
--    You'll find the lua script for this mapping in my reapack handle.
--
--    Usage:
--    - run the script (it will copy the mapping to your clipboard),
--    - add Realearn to your track,
--    - in realearn's window, click the «Import from Clipboard» button.
--    - You'll have to work the assignments from there.
-- @links
--  Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
-- @changelog
--   0.0.1 Setup the script

local info = debug.getinfo(1, "S")
local internal_root_path = info.source:match(".*perken.realearn.synth_map."):sub(2)
local windows_files = internal_root_path:match("\\$")
if windows_files then
  package.path = package.path .. ";" .. internal_root_path .. "utils\\?.lua"
else
  package.path = package.path .. ";" .. internal_root_path .. "utils/?.lua"
end

local utils = require("utils")
local serpent = require("serpent")
local REALERN_PARAMS = 100
ENCODERS_PER_ROW = 4
local Color_list = {
  "02", --navy
  "0F", --skyBlue
  "19", --turquoise
  "2E", --oliveGreen
  "3C", --appleGreen
  "40", --yellow
  "49", --orange
  "56", --red
  "5A", --pink
  "6B", --purple
  "71", --violet
}
---@enum ColorEnum
local Color_enum = {
  blk = "00",
  navy = "02",
  skyBlue = "0F",
  turquoise = "19",
  oliveGreen = "2E",
  appleGreen = "3C",
  yellow = "40",
  orange = "49",
  red = "56",
  pink = "5A",
  purple = "6B",
  violet = "71",
}

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
---@param ENCODERS_COUNT integer
local function LOC(ENCODERS_COUNT)
  local L = {
    data = {}
  }
  L.pageIdx = -1
  ---@type integer[]
  L.availableParams = (function()
    local avail = {}
    for i = 1, REALERN_PARAMS - 1 do ---starts at one since 0 is the bank param
      table.insert(avail, i)
    end
    return avail
  end)()
  L.colorIdx = 0

  ---@return integer|nil
  function L:new_param()
    local param_idx = table.remove(self.availableParams, 1)
    return param_idx
  end

  function L:increment_color()
    self.colorIdx = (self.colorIdx + 1) % #Color_list
    if self.colorIdx == 0 then self.colorIdx = 1 end
    return Color_list[self.colorIdx]
  end

  function L:init()
    self:new_page()
    return self
  end

  function L:cur_maps_in_page()
    local count = 0
    for i, map in pairs(self.data[self.pageIdx].maps) do
      if map.target.kind ~= "Dummy" then
        count = count + 1
      end
    end
    return count
  end

  function L:fill_left_over_space_in_last_bank_with_dummies()
    local last_bank = self.data[self.pageIdx].bnk
    local last_bank_idx = #self.data[self.pageIdx].maps
    local dummies_start_idx = last_bank_idx + 1
    local dummies = create_dummies(last_bank.id, self.pageIdx, dummies_start_idx, ENCODERS_COUNT)
    for _, dummy in ipairs(dummies) do
      table.insert(self.data[self.pageIdx].maps, dummy)
    end
  end

  function L:add_dummies_page()
    self:new_page()
    local dummies = create_dummies(self.data[self.pageIdx].bnk.id, self.pageIdx, 1, ENCODERS_COUNT)
    for _, dummy in ipairs(dummies) do
      table.insert(self.data[self.pageIdx].maps, dummy)
    end
  end

  ---@param fx FxDescr
  function L:insert_fx(fx)
    local fx_colour = self:increment_color()
    for i, param in pairs(fx.params) do
      if param.mapping == nil then goto continue end ---if fx has no mapping, continue
      -- REPLACE THE DUMMIES, DON'T JUST ADD TO THEM
      self:insert(param.mapping, fx_colour)
      ::continue::
    end
  end

  ---@param mod_name string
  ---@param encoder_idx integer -- 0-indexed
  ---@param cond_list Param_n_modifier[]
  function L:create_hold_Btn(mod_name, encoder_idx, cond_list)
    local hold_btn = createIdleMapping()
    hold_btn.feedback_enabled = false
    hold_btn.name = mod_name .. "_hld"
    local page_idx = ((self.pageIdx / 100) - 0.001)
    if page_idx < 0 then page_idx = 0 end
    hold_btn.source = {
      kind = "Virtual",
      id = encoder_idx,
      character = "Button",
    }
    local conditions_list = { { bnk = 0, modifier = self.pageIdx } }
    for i, condition in ipairs(cond_list) do
      table.insert(conditions_list, { bnk = condition.bnk, modifier = condition.modifier - 1 })
    end
    hold_btn.activation_condition = {
      kind = "Expression",
      condition = L:format_condition(conditions_list)
    }
    local hold_param = L:new_param() or -1
    hold_btn.target = {
      kind = "FxParameterValue",
      parameter = {
        address = "ById",
        index = hold_param,
      },
      poll_for_feedback = false,
    }

    table.insert(self.data[self.pageIdx].maps, hold_btn)
    return hold_param
  end

  ---@param mod_name string
  ---@param encoder_idx integer -- 0-indexed
  ---@param cond_list Param_n_modifier[]
  ---@param dbl_clk? boolean
  function L:create_toggle_Btn(mod_name, encoder_idx, cond_list, dbl_clk)
    local toggle_btn = createIdleMapping()
    toggle_btn.feedback_enabled = false
    toggle_btn.name = mod_name .. "_tgl"
    local page_idx = ((self.pageIdx / 100) - 0.001)
    if page_idx < 0 then page_idx = 0 end
    toggle_btn.source = {
      kind = "Virtual",
      id = encoder_idx,
      character = "Button",
    }
    toggle_btn.glue = {
      absolute_mode = "ToggleButton",
      -- wrap = true,
      step_size_interval = { 0.01, 0.05 },
    }

    local conditions_list = { { bnk = 0, modifier = self.pageIdx } }
    for i, condition in ipairs(cond_list) do
      table.insert(conditions_list, { bnk = condition.bnk, modifier = condition.modifier - 1 })
    end
    toggle_btn.activation_condition = {
      kind = "Expression",
      condition = L:format_condition(conditions_list)
    }
    if dbl_clk then
      toggle_btn.glue.fire_mode = {
        kind = "OnDoublePress",
      }
    end
    table.insert(self.data[self.pageIdx].maps, toggle_btn)
    --[[
deux boutons: un qui controle l'effet et un qui controle le param qui déclenche le fdb de l'encodeur.
est-ce possible d'en avoir un seul pour les deux?
    ]]
    local toggle_param = L:new_param()
    local btn2 = utils.deepcopy(toggle_btn)
    btn2.id = utils.uuid()
    btn2.target = {
      kind = "FxParameterValue",
      parameter = {
        address = "ById",
        index = toggle_param,
      },
      poll_for_feedback = false,
    }

    table.insert(self.data[self.pageIdx].maps, btn2)
    return toggle_param or -1
  end

  ---@param mod_name string
  ---@param encoder_idx integer -- 0-indexed
  ---@param target_interval number[]
  ---@param realearn_param_idx number
  function L:create_cycleBtn(mod_name, encoder_idx, target_interval, realearn_param_idx)
    local cycle_btn = createIdleMapping()
    cycle_btn.feedback_enabled = false
    cycle_btn.name = mod_name .. "_cycl"
    local page_idx = ((self.pageIdx / 100) - 0.001)
    if page_idx < 0 then page_idx = 0 end
    cycle_btn.activation_condition = {
      kind = "Bank",
      parameter = 0, -- paging is all on param 0
      bank_index = self.pageIdx,
    }
    cycle_btn.source = {
      kind = "Virtual",
      id = encoder_idx,
      character = "Button",
    }
    cycle_btn.glue = {
      absolute_mode = "IncrementalButton",
      target_interval = target_interval,
      wrap = true,
      step_size_interval = { 0.01, 0.05 },
      -- source_interval = { 0, 0 },
    }
    cycle_btn.target = {
      kind = "FxParameterValue",
      parameter = {
        address = "ById",
        index = realearn_param_idx,
      },
      poll_for_feedback = false,
    }
    return cycle_btn
  end

  function L:format_low_hi(val)
    local low = (val / 100) - 0.001
    if low < 0 then low = 0 end
    local hi = (val / 100) + 0.009
    return low, hi
  end

  function L:format_modifier_idx(val)
    return "p[" .. val .. "]" -- modifier index
  end

  function L:format_expression_condition(bnk, modifier)
    local mod_low, mod_hi = L:format_low_hi(modifier)
    local b_idx = L:format_modifier_idx(bnk) -- which bank/page we're in, synth page is 0
    return b_idx .. " >= " .. mod_low .. " && " .. b_idx .. " < " .. mod_hi
  end

  ---@class Param_n_modifier
  ---@field bnk integer
  ---@field modifier integer

  --- `p[0] > 0.009 && p[0] < 0.019 && p[1] > 0.009 && p[1] < 0.019`
  ---
  --- The way that's written looks awkward,
  --- but realearn can't read `p[0]==0.001` as `true`: floating point numbers are inaccurate…
  ---@param prm_n_modifier Param_n_modifier[]
  function L:format_condition(prm_n_modifier)
    local expressions = {}
    for i, v in ipairs(prm_n_modifier) do
      table.insert(expressions, L:format_expression_condition(v.bnk, v.modifier))
    end
    return table.concat(expressions, " && ")
  end

  ---@param encoder_idx integer
  ---@param color string
  function L:format_color(encoder_idx, color)
    return "B1 " .. utils.toHex(encoder_idx) .. " " .. color
  end

  ---@param title string
  ---@param opt string
  ---@param encoder_idx integer
  ---@param alt_color string
  ---@param prm_n_modifier Param_n_modifier[]
  ---@param use_color? boolean
  function L:create_encoder(title, opt, encoder_idx, alt_color, prm_n_modifier, use_color)
    local param = createIdleMapping()
    param.name = title .. "_" .. opt
    param.source = {
      kind = "Virtual",
      id = encoder_idx,
    }
    if use_color == nil or (use_color ~= nil and use_color) then
      param.on_activate = {
        send_midi_feedback = {
          {
            kind = "Raw",
            message = L:format_color(encoder_idx, alt_color)
          },
        },
      }
    end
    -- THIS WILL BREAK WHEN BUILD FX MAPS?
    local conditions_list = { { bnk = 0, modifier = self.pageIdx } }
    for i, condition in ipairs(prm_n_modifier) do
      table.insert(conditions_list, { bnk = condition.bnk, modifier = condition.modifier - 1 })
    end
    param.activation_condition = {
      kind = "Expression",
      condition = L:format_condition(conditions_list)
    }
    table.insert(self.data[self.pageIdx].maps, param)
  end

  ---@param dest "filt1_cut" | "amp" | "pitch" | "filt2_cut"
  function L:lfo_dest_color(dest)
    local opts = {
      filt1_cut = Color_enum.red,
      amp = Color_enum.yellow,
      pitch = Color_enum.turquoise,
      filt2_cut = Color_enum.purple,
    }
    return opts[dest]
  end

  ---@class MapLayout
  ---@field title string
  ---@field alts string[]
  ---@field Options? Option[]
  ---@field colors string[]

  ---@enum Types
  local types = {
    clk = "clk",
    dbl_clk = "dbl_clk",
    hold = "hold",
  }

  ---@class MapButtons
  ---@field type Types
  ---@field colors? ColorEnum[]
  ---@field title? string
  ---@field opts? string[]


  ---@type MapLayout[]
  L.fx_layout = {
    {
      title = "FX1",
      alts = { "dist" },
      Options = {
        { name = "drive" },
        { name = "-" },
        { name = "-" },
        {
          name = "-",
          dbl_clk = { name = "Bypass", type = "toggle" },
          hold = { name = "dry/wet", colors = Color_enum.blk }
        },
      },
      colors = {
        Color_enum.orange },
      encoder4 = L.FX_encoder4,
    },
    {
      title = "FX2",
      alts = { "chorus" },
      Options = {
        { name = "rate" },
        { name = "Dly1" },
        { name = "Dly2" },
        {
          name = "Depth",
          dbl_clk = { name = "Bypass", type = "toggle" },
          hold = {
            name = "dry/wet",
            colors = Color_enum.blk
          }
        }, },
      colors = {
        Color_enum.skyBlue },
      encoder4 = L.FX_encoder4,
    },
    {
      title = "FX3",
      alts = { "Delay" },
      Options = {
        { name = "Fdbk" },
        { name = "Time" },
        { name = "-" },
        {
          name = "-",
          dbl_clk = { name = "Bypass", type = "toggle" },
          hold = { name = "dry/wet", colors = Color_enum.blk }
        }, },
      colors = {
        Color_enum.purple },
      encoder4 = L.FX_encoder4,
    },
    {
      title = "FX4",
      alts = { "Rvb" },
      Options = {
        { name = "Size" },
        { name = "Decay" },
        { name = "LoCut" },
        {
          name = "HiCut",
          dbl_clk = { name = "Bypass", type = "toggle" },
          hold = { name = "dry/wet", colors = Color_enum.blk }
        }, },
      colors = {
        Color_enum.oliveGreen },
      encoder4 = L.FX_encoder4,
    }
  }

  ---@class ClkAlt
  ---@field name string
  ---@field color string

  ---@class Option
  ---@field name string
  ---@field dbl_clk? {name: string, type: "alt" | "toggle" | "hold", alts?: ClkAlt[]}
  ---@field clk?  {name: string, type: "alt" | "toggle" | "hold", alts?: ClkAlt[]}
  ---@field hold? {name : string}

  ---@type MapLayout[]
  L.synth_layout = {
    {
      title = "OSC",
      alts = { "oscA", "oscB", "sub", "noise" },
      colors = {
        Color_enum.navy, Color_enum.yellow, Color_enum.oliveGreen, Color_enum.turquoise },
      volume = {
        send_to_filter = false
      },
      Options = {
        { name = "oct", },
        { name = "coarse", },
        { name = "wave", },
        { name = "volume", },
      },
    },
    {
      title = "FILT",
      alts = { "filt1", "filt2_hp" },
      Options = {
        { name = "cut", },
        { name = "res", },
        { name = "type", },
        { name = "drive", },
      },
      colors = {
        Color_enum.red, Color_enum.purple },
      drive = {
        keytrack = false
      }
    },
    {
      title = "ENV",
      alts = { "FILT_ENV", "AMP_ENV", "PITCH_ENV" },
      Options = {
        { name = "A", },
        { name = "D", },
        { name = "S", },
        {
          name = "R",
          clk = {
            name = "polarity",
            type = "toggle",
          },
          hold = { name = "env_amt" }
        },
      },
      colors = { Color_enum.red, Color_enum.yellow, Color_enum.turquoise },
    },
    {
      title = "LFO",
      alts = { "lfo1", "lfo2" },
      Options = {
        { name = "wave" },
        { name = "rate", dbl_clk = { name = "bpm_sync", type = "toggle" } },
        { name = "-",    dbl_clk = { name = "polarity", type = "toggle" } },
        {
          name = "amt",
          clk = {
            name = "dest",
            type = "alt",
            alts = {
              { name = "filt1_cut", color = Color_enum.red, },
              { name = "amp",       color = Color_enum.yellow, },
              { name = "pitch",     color = Color_enum.turquoise, },
              { name = "filt2_cut", color = Color_enum.purple, },
            }
          }
        },
      },
      colors = { Color_enum.skyBlue, Color_enum.navy },
    }
  }

  ---comment
  ---@param encoder_idx integer
  ---@param clk_alts ClkAlt[]
  ---@param alt_idx integer
  ---@param row_param integer
  ---@param ALT string
  function L:create_encoder_cycler(encoder_idx, clk_alts, alt_idx, row_param, ALT, opt_name)
    local destination_param = L:new_param() or -1
    local destination_cycle_btn = L:create_cycleBtn(opt_name, encoder_idx, { 0, (#clk_alts - 1) / 100 },
      destination_param)
    table.insert(self.data[self.pageIdx].maps, destination_cycle_btn)

    -- create alts for each destination tb cycled
    for opt_idx, clk_alt in ipairs(clk_alts) do
      local conditions_list = {
        { bnk = row_param,         modifier = alt_idx },
        { bnk = destination_param, modifier = opt_idx }
      }
      L:create_encoder(ALT, clk_alt.name, encoder_idx, clk_alt.color,
        conditions_list)
    end
  end

  ---@param encoder_idx integer
  ---@param alt_idx integer
  ---@param col_idx integer
  ---@param alt_color string
  ---@param cond_lst Param_n_modifier[]
  function L:create_idl_button(encoder_idx, alt_idx, col_idx, alt_color, cond_lst)
    --create 4 idle buttons
    local idle_btn = createIdleMapping()
    idle_btn.source = {
      kind = "Virtual",
      id = encoder_idx,
      -- character = "Button",
    }
    idle_btn.on_activate = {
      send_midi_feedback = {
        {
          kind = "Raw",
          message = L:format_color(encoder_idx, alt_idx == col_idx and alt_color or Color_enum.blk)
        },
      },
    }
    local conditions_list = { { bnk = 0, modifier = self.pageIdx } }
    for i, condition in ipairs(cond_lst) do
      table.insert(conditions_list, { bnk = condition.bnk, modifier = condition.modifier - 1 })
    end
    idle_btn.activation_condition = {
      kind = "Expression",
      condition = L:format_condition(conditions_list)
    }

    table.insert(self.data[self.pageIdx].maps, idle_btn)
  end

  ---@param layout MapLayout[]
  ---@param type "fx" | "synth"
  function L:create_map(layout, type)
    for row_idx, row in ipairs(layout) do
      ---Create a bank that matches the current alt. This is done by assigning one of realearn's params
      local row_param = L:new_param() or -1
      local cycle_btn = L:create_cycleBtn(row.title, (row_idx - 1) * ENCODERS_PER_ROW, { 0, (#row.alts - 1) / 100 },
        row_param)

      table.insert(self.data[self.pageIdx].maps, cycle_btn)
      for alt_idx, ALT in ipairs(row.alts) do
        local alt_color = row.colors[alt_idx]
        for col_idx, OPT in ipairs(row.Options) do
          local encoder_idx = (row_idx - 1) * ENCODERS_PER_ROW + (col_idx - 1)
          -- if you want to light up only color of encoder corresponding to alt index, then
          -- create a seriesof 4 btns for each alt in each row (if alt is not a toggle)
          -- if col_idx == alt_idx then btn gets to turn on its color
          -- other btns are in black
          if OPT.hold then
            local toggle_param = L:create_hold_Btn(ALT, encoder_idx, { { bnk = row_param, modifier = alt_idx } })
            L:create_encoder(ALT, OPT.hold.name, encoder_idx, alt_color,
              { { bnk = row_param, modifier = alt_idx }, { bnk = toggle_param, modifier = 101 }, }
            )
          end
          if OPT.clk then
            if OPT.clk.type == "alt" then
              L:create_encoder_cycler(encoder_idx, OPT.clk.alts, alt_idx, row_param, ALT, OPT.name)
            elseif OPT.clk.type == "toggle" then
              ---TODO also create the toggle button
              local toggle_param = L:create_toggle_Btn(ALT, encoder_idx, { { bnk = row_param, modifier = alt_idx } })
              L:create_encoder(ALT, OPT.name, encoder_idx, alt_color,
                { { bnk = row_param, modifier = alt_idx }, { bnk = toggle_param, modifier = 1 }, }
              )
            end
          elseif OPT.dbl_clk then
            if OPT.dbl_clk.type == "toggle" then
              ---TODO also create the toggle button
              local toggle_param = L:create_toggle_Btn(ALT, encoder_idx, { { bnk = row_param, modifier = alt_idx } },
                true
              )
              L:create_encoder(ALT, OPT.name, encoder_idx, alt_color,
                { { bnk = row_param, modifier = alt_idx }, { bnk = toggle_param, modifier = 1 }, }
              )
            end
          else
            L:create_encoder(ALT, OPT.name, encoder_idx, alt_color, { { bnk = row_param, modifier = alt_idx } },
              type ~= "synth")

            if type == "synth" then
              L:create_idl_button(encoder_idx, alt_idx, col_idx, alt_color, { { bnk = row_param, modifier = alt_idx } })
            end
          end
        end
      end
    end
  end

  function L:find_available_idx()
    return #self.data[self.pageIdx].maps + 1
  end

  ---@param map Mapping
  ---@param fx_colour string | nil
  function L:insert(map, fx_colour)
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

  function L:new_page()
    self.pageIdx = self.pageIdx + 1
    local bnk = createBank(self.pageIdx)
    bnk.activation_condition.bank_index = self.pageIdx
    self.data[self.pageIdx] = {
      maps = {},
      bnk = bnk,
    }
  end

  function L:get_maps()
    -- reduce to get all banks
    local maps = {}
    for _, datum in pairs(self.data) do
      for _, map in pairs(datum.maps) do
        table.insert(maps, map)
      end
    end
    return maps
  end

  function L:get_bnks()
    -- reduce to get all banks
    local bnks = {}
    for _, bnk in pairs(self.data) do
      table.insert(bnks, bnk.bnk)
    end
    return bnks
  end

  return L:init()
end

local Main_compartment_mapper = {}
---@param ENCODERS_COUNT integer number of encoders on the current controller
function Main_compartment_mapper.build_synth_map_pages(ENCODERS_COUNT)
  ---@return Bank[] bnks
  ---@return Mapping[] fx
  local function build()
    local bnks = LOC(ENCODERS_COUNT)
    bnks:create_map(bnks.synth_layout, "synth")
    bnks:new_page()
    bnks:create_map(bnks.fx_layout, "fx")
    bnks:fill_left_over_space_in_last_bank_with_dummies()
    bnks:add_dummies_page()
    return bnks:get_bnks(), bnks:get_maps()
  end

  local bnks, maps = build()
  local pagers = createLeftRightBankPagers()

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

local Synth_Map = {}

function Synth_Map.create_fx_map()
  local ENCODERS_COUNT = 16
  local main_compartment = Main_compartment_mapper.build_synth_map_pages(ENCODERS_COUNT)

  -- local MFT_MAPPING = { MFT_controller_compartment, main_compartment }

  local lua_table_string = serpent.serialize(main_compartment, { comment = false }) -- stringify the modulator
  reaper.CF_SetClipboard(lua_table_string)
end

Synth_Map.create_fx_map()
