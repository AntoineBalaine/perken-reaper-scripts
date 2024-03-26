local layoutEnums = require("state.fx_layout_types")
local Knob = require("components.knobs.Knobs")

---@class ParamDisplaySettings
---@field type Param_Display_Type
---@field component Knob|nil
---@field Pos_X integer|nil
---@field Pos_Y integer|nil
---@field wiper_start KnobTrackStart
---@field knob_variant KnobVariant

---@class Parameter
---@field defaultval number
---@field display_settings ParamDisplaySettings
---@field editSelected boolean = false
---@field fmt_val string|nil
---@field guid string
---@field ident string
---@field index number
---@field istoggle boolean
---@field largestep number
---@field maxval number
---@field midval number
---@field minval number
---@field name string
---@field new fun( state: State, param_index: number, parent_fx: TrackFX, guid: string): self
---@field parent_fx TrackFX
---@field query_value fun(self):self
---@field setValue fun(self, value :number)
---@field smallstep number
---@field state State
---@field step number
---@field value number



---@class Parameter
local parameter = {}
parameter.__index = parameter


---query info about the current param (min/max value, name, identifier, etc.)
---and store it in the class
---@param state State
---@param param_index number
---@param parent_fx TrackFX
---@param guid string
function parameter.new(state, param_index, parent_fx, guid)
    ---@type Parameter
    local new_param = setmetatable({}, parameter)
    new_param.state = state
    new_param.guid = guid
    new_param.index = param_index
    new_param.parent_fx = parent_fx
    local _, name = reaper.TrackFX_GetParamName(new_param.state.Track.track, new_param.parent_fx.index - 1,
        new_param.index)
    local _, ident = reaper.TrackFX_GetParamIdent(new_param.state.Track.track, new_param.parent_fx.index - 1,
        new_param.index)
    new_param.name = name
    new_param.ident = ident
    _, new_param.minval, new_param.maxval, new_param.midval = reaper.TrackFX_GetParamEx(
        new_param.state.Track.track,
        new_param.parent_fx.index,
        new_param.index)
    _, new_param.step, new_param.smallstep, new_param.largestep, new_param.istoggle = reaper
        .TrackFX_GetParameterStepSizes(
            new_param.state.Track.track,
            new_param.parent_fx.index,
            new_param.index)

    new_param.value = reaper.TrackFX_GetParamNormalized(new_param.state.Track.track,
        new_param.parent_fx.index - 1,
        new_param.index)
    ---for default value, I'm having to use 0.5 as a placeholder
    --That's because reaper doesn't have an API to query the default value of a parameter.
    --not sure that’s right, but that’s my best bet.
    new_param.defaultval = 0.5 or new_param.value
    new_param.display_settings = {
        type = layoutEnums.Param_Display_Type.Knob,
        component = nil, ---the component that will be drawn, to be instantiated in the fx_box:main()
        wiper_start = layoutEnums.KnobWiperStart.left,
        knob_variant = Knob.KnobVariant.ableton,
        -- Pos_X = 0,
        -- Pos_Y = 0,
    }


    return new_param
end

function parameter:query_value()
    self.value = reaper.TrackFX_GetParamNormalized(self.state.Track.track,
        self.parent_fx.index - 1,
        self.index)
    local rv_fmt, formatted = reaper.TrackFX_GetFormattedParamValue(
        self.state.Track.track,
        self.parent_fx.index - 1,
        self.index)
    ---formatted value, as string
    if rv_fmt then
        self.fmt_val = formatted ---@type string|nil
    end
    --reaper.TrackFX_GetNamedConfigParm(MediaTrack track, integer fx, string parmname)
    --  fx_type : type string
    --   fx_ident : type-specific identifier
    --   fx_name : pre-aliased name
    --   GainReduction_dB : [ReaComp + other supported compressors]
    --
    --   original_name : pre-renamed FX instance name
    --   renamed_name : renamed FX instance name (empty string = not renamed)
    return self
end

---@param value number
function parameter:setValue(value)
    reaper.TrackFX_SetParamNormalized(self.state.Track.track, self.parent_fx.index - 1, self.index, value)
end

return parameter
