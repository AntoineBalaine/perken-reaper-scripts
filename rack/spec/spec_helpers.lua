local spec_helpers = {}
function spec_helpers.create_fx()
    ---Setup some FX to pass into the state
    ---@type FxData[]
    local fx = {}
    for idx = 1, 3 do
        ---@type FxData
        local cur_fx = {
            number = idx - 1,
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
