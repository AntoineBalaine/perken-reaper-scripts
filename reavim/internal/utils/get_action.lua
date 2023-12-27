local actions = require("definitions.defaults.actions") -- todo chck settings: extended dfaults or standard
local user_actions = require("definitions.actions")
for action_name, action_value in pairs(user_actions) do
	actions[action_name] = action_value
end

---@param action_name string
---@return Action | nil
function getAction(action_name)
	return actions[action_name]
end

return getAction
