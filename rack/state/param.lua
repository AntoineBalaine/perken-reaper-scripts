---@class Parameter
local parameter = {}
parameter.__index = parameter


---@param state State
---@param param_index number
---@param parent_fx TrackFX
function parameter.new(state, param_index, parent_fx)
    ---@class Parameter
    local self = setmetatable({}, parameter)
    self.state = state
    self.index = param_index
    self.parent_fx = parent_fx
    local _, name = reaper.TrackFX_GetParamName(self.state.Track.track, self.parent_fx.index, self.index)
    local ident = reaper.TrackFX_GetParamIdent(self.state.Track.track, self.parent_fx.index, self.index)
    self.name = name
    self.ident = ident
    _, self.minval, self.maxval = reaper.TrackFX_GetParam(
        self.state.Track.track,
        self.parent_fx.index,
        self.index)
    _, self.step, self.smallstep, self.largestep, self.istoggle = reaper.TrackFX_GetParameterStepSizes(
        self.state.Track.track,
        self.parent_fx.index,
        self.index)
    return self
end

function parameter:query_value()
    --reaper.TrackFX_GetParameterStepSizes(MediaTrack track, integer fx, integer param)
    _, self.value = reaper.TrackFX_GetFormattedParamValue(self.state.Track.track,
        self.parent_fx.index,
        self.index)

    --reaper.TrackFX_GetNamedConfigParm(MediaTrack track, integer fx, string parmname)
    --  fx_type : type string
    --   fx_ident : type-specific identifier
    --   fx_name : pre-aliased name
    --   GainReduction_dB : [ReaComp + other supported compressors]
    --
    --   original_name : pre-renamed FX instance name
    --   renamed_name : renamed FX instance name (empty string = not renamed)
end

return parameter
