local layoutEnums = require("state.fx_layout_types")
---@class Parameter
local parameter = {}
parameter.__index = parameter


---query info about the current param (min/max value, name, identifier, etc.)
---and store it in the class
---@param state State
---@param param_index number
---@param parent_fx TrackFX
function parameter.new(state, param_index, parent_fx, guid)
    ---@class Parameter
    local new_param = setmetatable({}, parameter)
    new_param.state = state
    new_param.guid = guid
    new_param.index = param_index
    new_param.parent_fx = parent_fx
    new_param.display = true
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
    ---for default value, I'm having to use the on-first-load value.
    --That's because reaper doesn't have an API to query the default value of a parameter.
    new_param.defaultval = new_param.value -- assume scalar values are copied upon assignment. I think that's right?
    new_param.display_settings = {
        ---@type Param_Display_Type
        type = layoutEnums.Param_Display_Type.Knob
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
    if rv_fmt then
        ---formatted value, as string
        self.fmt_val = formatted
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
