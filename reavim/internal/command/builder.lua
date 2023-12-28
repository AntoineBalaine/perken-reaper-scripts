--@noindex
local utils = require("command.utils")
local action_sequences = require("command.action_sequences")
local definitions = require("utils.definitions")
local getAction = require("utils.get_action")
local format = require("utils.format")
local log = require("utils.log")

local function getActionKey(key_sequence, entries)
	local action_name = utils.getEntryForKeySequence(key_sequence, entries)
	if
			action_name
			and not utils.isFolder(action_name)
			and (
				not utils.checkIfActionHasOptionSet(action_name, "registerAction")
				or utils.checkIfActionHasOptionSet(action_name, "registerOptional")
			)
	then
		return action_name
	end

	local number_match, rest_of_key_sequence = utils.splitFirstMatch(key_sequence, "[1-9][0-9]*")
	if number_match then
		local num_prefix_entries = utils.filterEntries({ "prefixRepetitionCount" }, entries)
		local action_key = getActionKey(rest_of_key_sequence, num_prefix_entries)
		if action_key then
			if type(action_key) ~= "table" then
				action_key = { action_key }
			end
			action_key["prefixedRepetitions"] = tonumber(number_match)
			return action_key
		end
	end

	local start_of_key_sequence, possible_register = utils.splitLastKey(key_sequence)
	local reg_postfix_entries = utils.filterEntries({ "registerAction" }, entries)
	local register_action_name = utils.getEntryForKeySequence(start_of_key_sequence, reg_postfix_entries)
	if register_action_name and not utils.isFolder(register_action_name) then
		local action_key = { register_action_name }
		action_key["register"] = possible_register
		return action_key
	end

	return nil
end

---@param key_sequence string|nil
---@param action_type_entries Definition
local function stripNextActionKeyInKeySequence(key_sequence, action_type_entries)
	if not action_type_entries then
		return nil, nil, false
	end

	local rest_of_key_sequence = ""
	local key_sequence_for_action_type = key_sequence
	while #key_sequence_for_action_type ~= 0 do
		local action_key = getActionKey(key_sequence_for_action_type, action_type_entries)
		if action_key then
			return rest_of_key_sequence, action_key, true
		end

		key_sequence_for_action_type, Last_key = utils.splitLastKey(key_sequence_for_action_type)
		rest_of_key_sequence = Last_key .. rest_of_key_sequence
	end

	return nil, nil, false
end

---@param key_sequence string
---@param action_sequence string[][]
---@param entries Definition[]
---@return {action_sequence: string[], action_keys: string[]} | nil
local function buildCommandWithSequence(key_sequence, action_sequence, entries)
	local command = {
		action_sequence = {},
		action_keys = {},
	}

	---@type string|nil
	local rest_of_key_sequence = key_sequence
	for _, action_type in pairs(action_sequence) do
		rest_of_key_sequence, Action_key, Found =
				stripNextActionKeyInKeySequence(rest_of_key_sequence, entries[action_type])
		if not Found then
			return nil
		else
			table.insert(command.action_sequence, action_type)
			table.insert(command.action_keys, Action_key)
		end
	end

	if #rest_of_key_sequence > 0 then
		return nil
	end

	return command
end

---@param state State
---@return Command | nil
local function buildCommand(state)
	local action_sequences = action_sequences.getPossibleActionSequences(state["context"], state["mode"])
	local entries = definitions.getPossibleEntries(state["context"])

	for _, action_sequence in pairs(action_sequences) do
		local command = buildCommandWithSequence(state["key_sequence"], action_sequence, entries) ---@as Command
		if command then
			command["mode"] = state["mode"]
			command["context"] = state["context"]
			return command
		end
	end

	return nil
end

return buildCommand
