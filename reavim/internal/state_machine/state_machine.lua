local state_machine = {}

local state_interface = require('state_machine.state_interface')
local state_machine_definitions = require("state_machine.definitions")
local definitions = require("definitions")

local command = require("command")
local log = require('utils.log')

local ser = require("serpent")

function input(key_press)
  log.info("input: " .. ser.line(key_press, {comment=false}))

  local state = state_interface.get()

  if state['key_sequence'] == "" then
    state['context'] = key_press['context']
  elseif state['context'] ~= key_press['context'] then
    log.info('Invalid key sequence. Next key is in different context.')
    return state_machine_definitions['reset_state']
  end

  local new_state = state
  new_state["key_sequence"] = state['key_sequence'] .. key_press['key']
  log.info("key sequence: " .. new_state["key_sequence"])

  local cmd = command.buildCommand(new_state)
  if cmd then
    log.info('Command triggered: ' .. ser.block(cmd, {comment=false}))
    new_state = command.executeCommand(state, cmd)
  else
    local future_entries = command.getPossibleFutureEntries(new_state)
    log.info("Future entries: " .. ser.block(future_entries, {comment=false, maxlevel=2}))
    if not future_entries then
        new_state = state_machine_definitions['reset_state']
        log.info('Undefined key sequence.')
    end
  end

  log.trace("new state: " .. ser.block(new_state, {comment=false}) .. "\n")
  state_interface.set(new_state)
end

return input
