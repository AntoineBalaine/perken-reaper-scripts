local utils = require('command.utils')

local definition_tables = {
  global = require('definitions.global'),
  midi = require('definitions.midi'),
  main = require('definitions.main'),
}

local definitions = {}

function concatEntryTables(t1,t2)
  local merged_tables = {}
  for action_type, entries in pairs(t1) do
    merged_tables[action_type] = entries

    if t2[action_type] then
      for key_sequence,action in pairs(t2[action_type]) do
        merged_tables[action_type][key_sequence] = action
      end
    end
  end

  for action_type, entries in pairs(t2) do
    if not merged_tables[action_type] then
      merged_tables[action_type] = {}
      for key_sequence,action in pairs(entries) do
        merged_tables[action_type][key_sequence] = action
      end
    end
  end

  return merged_tables
end

function definitions.getPossibleEntries(context)
  local merged_table = {}
  merged_table = concatEntryTables(merged_table, definition_tables['global'])
  merged_table = concatEntryTables(merged_table, definition_tables[context])
  return merged_table
end

-- this reverses the keys and values by 'extracting' from folders
function getBindings(entries)
  local bindings = {}
  for entry_key,entry_value in pairs(entries) do
    if utils.isFolder(entry_value) then
      local folder_table = entry_value[2]
      local folder_bindings = getBindings(folder_table)

      for action_name_from_folder,binding_from_folder in pairs(folder_bindings) do
        bindings[action_name_from_folder] = entry_key .. binding_from_folder
      end
    else
      bindings[entry_value] = entry_key
    end
  end

  return bindings
end

function definitions.getBindings()
  local bindings = {}
  for context,context_definitions in pairs(definition_tables) do
    bindings[context] = {}

    for action_type,action_type_definitions in pairs(context_definitions) do
      bindings[context][action_type] = getBindings(action_type_definitions)
    end

  end

  return bindings
end

function definitions.getAllEntries()
  return definition_tables
end

return definitions
