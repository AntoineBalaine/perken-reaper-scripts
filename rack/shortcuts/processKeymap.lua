--[[
Process shortcuts: returns a table of actions, keys, and scripts.
The main function in this module is
processkeymap: a helper that reads the contents of reaper-kb.ini and parses it into a table
For this section, see https://mespotin.uber.space/Ultraschall/Reaper-Filetype-Descriptions.html#Reaper-kb.ini
The doc details how the reaper-kb.ini file is structured.
]]


--[[
parse reaper-kb.ini into a table

iterate every table to sort them out
every line in that file is prefixed with a name
ACT = action
KEY = key
SCR = script

TODO Keep only the actions and keys that correspond to the arrange view (ignore midi editor)
TODO take all each of the shortcuts, and put them into the keyboard shortcuts module.
TODO this is so the user's reaper shortcuts can be re-used in the context of the rack.

some potentially-useful functions:
---@type KbdSectionInfo
reaper.CountActionShortcuts(KbdSectionInfo section, integer cmdID)
function reaper.kbd_enumerateActions(section, idx) end
]]

---@class Error

---@class Action
---@field settings string this might have to be converted to a number
---@field section_id number
---@field command_id string
---@field action_name string
---@field composed_of string[]

---convert an action-line from the parsed keymap into a named table
--
---This function can fail - make sure to catch the error
---@param action_line string[]
---@return Action | Error
local function processAction(action_line)
    assert(#action_line >= 5, "Table length does not match the expected length, expected at least 5 elements")
    -- action.prefix = action_line[1]  -- we can rid of the prefix, since it's always "ACT"
    local settings = action_line[2] -- TODO find out what this field is
    local section_id = tonumber(action_line[3])
    local command_id = action_line[4]
    local action_name = action_line[5]
    local composed_of = select(6, action_line)
    assert(type(section_id) == "number", "section_id couldn't be converted to a number")
    ---@type Action
    return {
        settings = settings,
        section_id = section_id,
        command_id = command_id,
        action_name = action_name,
        composed_of = composed_of,
    }
end


---@class KeyMapping
---@field modifier number
---@field key_note_value number
---@field command_id string
---@field section_id number

---convert a key-line from the parsed keymap into a named table
--
---This function can fail - make sure to catch the error
---@param key_line string[]
---@return KeyMapping|Error
local function processKey(key_line)
    assert(#key_line >= 5, "key-mapping's line length does not match the expected length, expected at least 5 elements")
    -- local prefix         = key_line[1] -- we can get rid of the prefix
    local modifier       = tonumber(key_line[2])
    local key_note_value = tonumber(key_line[3])
    local command_id     = key_line[4]
    local section_id     = tonumber(key_line[5])

    assert(type(modifier) == "number", "modifier couldn't be converted to a number")
    assert(type(key_note_value) == "number", "key_note_value couldn't be converted to a number")
    assert(type(section_id) == "number", "section_id couldn't be converted to a number")
    return {
        modifier = modifier,
        key_note_value = key_note_value,
        command_id = command_id,
        section_id = section_id,
    }
end

---@class Script
---@field on_new_instance number
---@field section_id number
---@field command_id number
---@field description string
---@field script_path string

---convert a script-line from the parsed keymap into a named table
--
---This function can fail - make sure to catch the error
---@param script_line string[]
---@return Script|Error
local function processScript(script_line)
    assert(#script_line >= 6,
        "script-line's length does not match the expected length, expected at least 6 elements")
    -- local prefix = script_line[1] -- we can get rid of the prefix
    local on_new_instance = tonumber(script_line[2])
    local section_id = tonumber(script_line[3])
    local command_id = tonumber(script_line[4])
    local description = script_line[5]
    local script_path = script_line[6]

    assert(type(on_new_instance) == "number", "on_new_instance couldn't be converted to a number")
    assert(type(section_id) == "number", "section_id couldn't be converted to a number")
    assert(type(command_id) == "number", "command_id couldn't be converted to a number")

    return {
        on_new_instance = on_new_instance,
        section_id = section_id,
        command_id = command_id,
        description = description,
        script_path = script_path,
    }
end


---Takes a list of lines parsed from a reaper-kb.ini file and sorts them into actions, keys, and scripts
--
---Assuming keymap contains an array of arrays of strings, sorts each line in the keymap by finding its first element
---if first === "ACT" then add to actions
---if first === "KEY" then add to keys
---if first === "SCR" then add to scripts
---@param key_map string[][]
---@return Action[]
---@return KeyMapping[]
---@return Script[]
local function processKeymap(key_map)
    local actions = {} ---@type Action[]
    local keys = {} ---@type KeyMapping[]
    local scripts = {} ---@type Script[]
    for _, line in ipairs(key_map) do
        local first = line[1]
        if first == "ACT" then
            local rv, action = pcall(processAction, line)
            if rv then
                table.insert(actions, action)
            end
        elseif first == "KEY" then
            local rv, key_mapping = pcall(processKey, line)
            if rv then
                table.insert(keys, key_mapping)
            end
        elseif first == "SCR" then
            local rv, script = pcall(processScript, line)
            if rv then
                table.insert(scripts, script)
            end
        end
    end
    return actions, keys, scripts
end


---get the daw's section corresponding to a section_id
--
--Section IDs are found in actions, scripts, and keys from the reaper-kb.ini file
---@param section_id number
---@return "Main" | "invisible" | "Main (alt recording)" | "Midi editor" | "Midi event list editor" | "Midi inline editor" | "Media explorer" | "unknown"
local function getSection(section_id)
    if section_id == 0 then
        return "Main"
    elseif section_id == 1 then
        return "invisible"
    elseif section_id == 100 then
        return "Main (alt recording)"
    elseif section_id == 32060 then
        return "Midi editor"
    elseif section_id == 32061 then
        return "Midi event list editor"
    elseif section_id == 32062 then
        return "Midi inline editor"
    elseif section_id == 32063 then
        return "Media explorer"
    else
        return "unknown"
    end
end

return {
    processKeymap = processKeymap,
    getSection = getSection,
}
