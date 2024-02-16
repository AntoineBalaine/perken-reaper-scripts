local fx = {}
fx.__index = fx

---@param state State
---@param data TrackFX
function fx.new(state, data)
    local self = setmetatable({}, fx)
    self.state = state
    self.enabled = data.enabled
    self.guid = data.guid
    self.name = data.name
    self.number = data.number
    self.param = data.param
    self.index = data.index
    self.LTP.param.number = state.Track.last_fx.param.number
    self.LTP.param.name = state.Track.last_fx.param.name
    -- self.param_list
    -- number retval, number minval, number maxval = reaper.TrackFX_GetParam(MediaTrack track, integer fx, integer param)
    --
    -- ParamValue_At_Script_Start = r.TrackFX_GetParamNormalized(Track, FX_Idx, FxdCtx.FX[FxGUID][Fx_P].Num or 0)
    return self
end

return fx
