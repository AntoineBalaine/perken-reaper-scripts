local def = require("definitions")
local log = require("utils.log")
local str = require("string")
local ser = require("serpent")

local sequences = require("command.sequences")
local utils = require("command.utils")

function getPossibleFutureEntriesForKeySequence(key_sequence, entries)
  if not entries then return nil end
  if key_sequence == "" then return entries end

  local entry = entries[key_sequence]
  if entry and utils.isFolder(entry) then
      local folder_table = entry[2]
      return folder_table
  end

  local possible_future_entries = {}

  local found_sequence_completion = false
  for full_key_sequence, entry_value in pairs(entries) do
    rest_of_sequence, full_seq_starts_with_key_seq = string.gsub(full_key_sequence, "^" .. key_sequence, "")
    if full_seq_starts_with_key_seq == 1 then
      possible_future_entries[full_key_sequence] = entry_value
      found_possible_future_entry = true
    end
  end
  if found_future_entry then
    return possible_future_entries
  end

  local first_key, rest_of_key_sequence = utils.splitFirstKey(key_sequence)
  local possible_folder = entries[first_key]
  if rest_of_key_sequence and utils.isFolder(possible_folder) then
    local folder = possible_folder
    local folder_table = folder[2]
    return getPossibleFutureEntriesForKeySequence(rest_of_key_sequence, folder_table)
  end

  return nil
end


function getPossibleFutureEntriesFollowingSequence(key_sequence, entry_type_sequence, entries)
  if not entries then return nil end
  if #entry_type_sequence == 0 then return nil end
  local first_entry_type = entry_type_sequence[1]
  local entries_for_first_entry_type = entries[first_entry_type]
  if not entries_for_first_entry_type then return nil end

  if key_sequence == "" then return entries_for_first_entry_type end

  -- regex type of entry (such as number, or macro key, or macro letter)
  if type(entries_for_first_entry_type) == 'string' then
    local match, rest_of_sequence = utils.splitFirstMatch(key_sequence, entries_for_first_entry_type)
    if match then
      table.remove(entry_type_sequence, 1)
      return getPossibleFutureEntriesFollowingSequence(rest_of_sequence, entry_type_sequence, entries)
    end
    return nil
  end

  local completions = getPossibleFutureEntriesForKeySequence(key_sequence, entries_for_first_entry_type)
  if completions then
    return completions
  end

  local rest_of_sequence = key_sequence
  while #rest_of_sequence ~= 0 do
    first_key, rest_of_sequence = utils.splitFirstKey(rest_of_sequence)
    local entry = utils.getEntryForKeySequence(first_key, entries_for_first_entry_type)
    if entry then
      table.remove(entry_type_sequence, 1)
      return getPossibleFutureEntriesFollowingSequence(rest_of_sequence, entry_type_sequence, entries)
    end
  end

  return nil
end

function getPossibleFutureEntries(state)
  local context_sequences = sequences.getPossibleSequences(state['context'], state['mode'])
  local global_sequences = sequences.getPossibleSequences('global', state['mode'])

  local future_entries = {}
  local future_entry_exists = false
  for _, entries in pairs({def.read(state['context']), def.read('global')}) do
    for _, possible_entry_type_sequences in pairs({context_sequences, global_sequences}) do
      for _, possible_entry_type_sequence in pairs(possible_entry_type_sequences) do
        local future_entries_following_sequence = getPossibleFutureEntriesFollowingSequence(state['key_sequence'], possible_entry_type_sequence, entries)
        if future_entries_following_sequence then
          future_entry_exists = true
          for key, entry in pairs(future_entries_following_sequence) do
            future_entries[key] = entry
          end
        end
      end

    end
  end

  if future_entry_exists then
    return future_entries
  end

  return nil
end

return getPossibleFutureEntries
