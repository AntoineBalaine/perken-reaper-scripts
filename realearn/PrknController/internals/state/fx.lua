local parameter = require("state.param")

---@class TrackFX
local fx = {}
fx.__index = fx

---TODO retrieve the list of params that need to be displayed for the FX and only track those. 


---query the list of params for the fx
---@return ParamData[] params_list
---@return table<string, ParamData> params_by_guid
function fx:createParams()
    local params_list = {} ---@type ParamData[]
    local params_by_guid = {} ---@type table<string, ParamData>

    local display = false
    local params_length = reaper.TrackFX_GetNumParams(self.state.Track.track, self.number)
    -- Don’t go through the entire list, so we don’t store the delta button
    for param_index = 0, params_length - 1 do
        local rv, name = reaper.TrackFX_GetParamName(self.state.Track.track, self.number, param_index)
        local guid = reaper.genGuid()
        if not rv then goto continue end
        ---@type ParamData
        local param = {
            index = param_index,
            name = name,
            guid = guid,
            display = display,
            details = nil,
            _selected = false
        }
        table.insert(params_list, param)
        params_by_guid[guid] = param

        ::continue::
    end


    return params_list, params_by_guid
end

---query whether the fx is enabled,
---query the values of the displayed params
function fx:update()
    self.enabled = reaper.TrackFX_GetEnabled(self.state.Track.track, self.number)

    for _, param in ipairs(self.display_params) do
        if param.details then
            param.details:query_value()
        end
    end
    self.DryWetParam.details:query_value()
end

---add param to list of displayed params
---query its value, create a param class for it
---@param param ParamData
function fx:createParamDetails(param)
    local new_param = parameter.new(self.state,
        param.index,
        self,
        param.guid
    )
    param.details = new_param
    return param
end

---I’m having to run a linear sweep here to find the fx by guid in the list of displayed params.
---@param param ParamData
function fx:removeParamDetails(param)
    if param.details then
        param.details = nil
    end
    for i, fx_instance in ipairs(self.display_params) do
        if fx_instance.guid == param.guid then
            table.remove(self.display_params, i)
            break
        end
    end
end

return fx

