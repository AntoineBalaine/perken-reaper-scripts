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

return fx_box_helpers
