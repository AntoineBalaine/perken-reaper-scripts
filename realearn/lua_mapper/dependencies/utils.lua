-- @noindex
local utils = {}

---convert a number to hex.
---Hex number has to be 2 characters-long, with leading 0 if necessary
---@param input integer
function utils.toHex(input)
  return string.format("%02x", input)
end

---HELPER - concat a variable number of tables
---@param ... table[]
function utils.TableConcat(...)
  local t = {}
  ---@type number, table
  for _, v in ipairs({ ... }) do
    for i = 1, #v do
      t[#t + 1] = v[i]
    end
  end
  return t
end

function utils.uuid()
  local random = math.random
  local template = 'xxxxxxxxxxxxxx4xxxxyx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
    return string.format('%x', v)
  end)
end

return utils
