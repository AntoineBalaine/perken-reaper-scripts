local spec_helpers = {}
function spec_helpers.create_fx()
    ---Setup some FX to pass into the state
    ---@type TrackFX[]
    local fx = {}
    for idx = 1, 3 do
        ---@type TrackFX
        local cur_fx = {
            number = idx,
            name = "fxname" .. idx,
            guid = "fx_guid" .. idx,
            enabled = true,
            index = idx
        }
        table.insert(fx, cur_fx)
    end
    return fx
end

return spec_helpers
