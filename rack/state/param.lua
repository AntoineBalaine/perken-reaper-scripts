local layoutEnums = require("state.fx_layout_types")
local Knob = require("components.knobs.Knobs")
local Slider = require("components.Slider")

---@class ParamDisplaySettings
---@field type Param_Display_Type
---@field component Knob|CycleButton|Slider|nil
---@field Pos_X integer|nil
---@field Pos_Y integer|nil
---@field wiper_start KnobTrackStart
---@field variant KnobVariant|SliderVariant

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
---@field step number normalized step
---@field value number
---@field steps_count? number Used for params that have a limited number of steps (like a dropdown)


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
    local _,
    name = reaper.TrackFX_GetParamName(new_param.state.Track.track,
        new_param.parent_fx.index - 1,
        new_param.index)
    local _,
    ident = reaper.TrackFX_GetParamIdent(new_param.state.Track.track,
        new_param.parent_fx.index - 1,
        new_param.index)
    new_param.name = name
    new_param.ident = ident

    --- set the min/max range of the parameter as normalized values
    new_param.minval = 0.0

    --- set the min/max range of the parameter as normalized values
    new_param.maxval = 1.0
    local min, max
    _, min, max,

    ---NOT a normalized value (NOT between 0 and 1)
    new_param.midval = reaper.TrackFX_GetParamEx(
        new_param.state.Track.track,
        new_param.parent_fx.index - 1,
        new_param.index)

    local steps_rv, step
    steps_rv, step, new_param.smallstep, new_param.largestep, new_param.istoggle = reaper
        .TrackFX_GetParameterStepSizes(
            new_param.state.Track.track,
            new_param.parent_fx.index - 1,
            new_param.index)

    if steps_rv then
        ---Calculate the amount of steps between the min and max values.
        ---If the amount of steps is less than 16, store it in the class.
        ---For now, I'm choosing 16 as the maximum amount of steps to display
        local steps_count = (max - min) / step
        --if the steps_count is a whole number and less than 10, store it in the class
        if steps_count // 1 | 0 == steps_count and steps_count <= 10 then
            new_param.steps_count = 1 + (steps_count // 1 | 0) -- store as integer
        end
        new_param.step = 1 / steps_count                       -- calculate the normalized value of a step
    end

    new_param.value = reaper.TrackFX_GetParamNormalized(new_param.state.Track.track,
        new_param.parent_fx.index - 1,
        new_param.index)
    ---for default value, I'm having to use the midval's normalized value.
    --That's because reaper doesn't have an API to query the default value of a parameter.
    --not sure that’s right, but that’s my best bet.
    new_param.defaultval = 0.5

    local control_type
    local variant
    if new_param.steps_count and new_param.steps_count <= 7 then
        control_type = layoutEnums.Param_Display_Type.CycleButton
        variant = Slider.Variant.horizontal
        -- elseif new_param.istoggle then
        --     control_type = layoutEnums.Param_Display_Type.ToggleButton -- don't have a toggle button yet.
    else
        control_type = layoutEnums.Param_Display_Type.Knob
        variant = Knob.KnobVariant.ableton
    end
    new_param.display_settings = {
        type = control_type,
        component = nil, ---the component that will be drawn, to be instantiated in the fx_box:main()
        wiper_start = layoutEnums.KnobWiperStart.left,
        variant = variant,
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
