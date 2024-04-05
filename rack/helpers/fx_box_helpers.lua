local fx_box_helpers = {}

---Remove the plugin type from the plugin name
---@param name string
function fx_box_helpers.getDisplayName(name)
    return name:gsub("%w+%:%s+",
        {
            ['AU: '] = "",
            ['JS: '] = "",
            ['VST: '] = "",
            ['VSTi: '] = "",
            ['VST3: '] = '',
            ['VST3i: '] = "",
            ['CLAP: '] = "",
            ['CLAPi: '] = ""
        }):gsub('[%:%[%]%/]', "_")
end

---Coerce `Input` number to be between `Min` and `Max`
---@param Input number
---@param Min number
---@param Max number
---@return number
function fx_box_helpers.fitBetweenMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

return fx_box_helpers
