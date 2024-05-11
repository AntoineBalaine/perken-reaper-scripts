--[[
read input from ext states and load mappings according to the current state.
--]]
local types = require("types")
local config = require("config.settings")

local state_machine = {}

local function read_ext_state()
    local ext = reaper.GetExtState(types.namespace, "action_stack")
end


local format = require("utils.format")

---@param state State
---@param key_press ActionId
---@return State|nil new_state, string|nil err
local function updateWithButtonPress(state, key_press)
    local new_state = state

    ---@type string
    local new_key_sequence = state.btn_sequence .. key_press
    new_state.key_sequence = new_key_sequence

    return new_state, nil
end

---@param state State
---@param button_press ActionId
local function step(state, button_press)
    local message = ""
    local new_state, err = updateWithButtonPress(state, button_press)
    if err ~= nil then
        new_state = state
        new_state.btn_sequence = ""
        reaper.MB(err, "error", 0)
        return new_state
    end

    local command = buildCommand(new_state)
    if command then
        new_state, message = handleCommand(new_state, command)
        return new_state
    end

    local future_entries = getPossibleFutureEntries(new_state)
    if not future_entries then
        new_state.btn_sequence = ""
        feedback.displayMessage("Undefined key sequence")
        return new_state
    end

    local message = format.keySequence(state.key_sequence, true)
    message = message .. "-"
    feedback.displayMessage(message)
    feedback.displayCompletions(future_entries)

    return new_state
end

---@param controller ControllerId
---@param button_press ActionId
local function input(controller, button_press)
    if config.show_feedback_window then
        -- check whether the ui is open
    end

    local state = state_interface.get(controller)
    local new_state = step(state, button_press)
    state_interface.set(new_state)

    if config.show_feedback_window then
        -- save info to ext states for ui to read
    end
end

return input
