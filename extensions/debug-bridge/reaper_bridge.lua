-- Lets a terminal session run Lua inside the running REAPER, to inspect its
-- state and call its API while developing. Run it once from the Actions list
-- ("Load ReaScript"), or start it from Scripts/__startup.lua. It keeps
-- running on REAPER's defer loop.
--
-- Because the code a client sends runs with the whole ReaScript API, the
-- bridge only listens on 127.0.0.1 and only obeys a client that sends the
-- secret in Data/Perken/bridge.token (mode 600, created on the first start).
--
-- Request:  "<token> <byte count>\n" followed by that many bytes of Lua.
-- Response: "<byte count>\n" followed by the result, or the error.

---A client that is connected to the bridge, and whose request is being read.
---@class BridgeClient
---@field sock any The client's LuaSocket connection.
---@field buf string The bytes received so far.
---@field need integer? The byte count of the request's code, known once its first line is read.
---@field done boolean? True when the connection is finished and the client can be dropped.

---@type integer
local PORT = tonumber(os.getenv("BRIDGE_PORT")) or 9876
---@type string
local sockets = "/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/"
-- A scratch REAPER (another resource folder) borrows the sockets installed in
-- the user's own folder.
for _, base in ipairs({ reaper.GetResourcePath(), os.getenv("HOME") .. "/.config/REAPER" }) do
  package.path = package.path .. ";" .. base .. sockets .. "?.lua"
  package.cpath = package.cpath .. ";" .. base .. sockets .. "?.so"
end
---@type any
local socket = require("socket")

---@type string
local data_dir = reaper.GetResourcePath() .. "/Data/Perken"
reaper.RecursiveCreateDirectory(data_dir, 0)
---@type string
local token_path = data_dir .. "/bridge.token"

---Because `gsub` calls this function once for each byte, it writes one byte as two hexadecimal digits.
---@param c string One byte.
---@return string hex The two digits of the byte.
local function hex_byte(c)
  return string.format("%02x", c:byte())
end

---Reads the secret from its file, or makes a new one when the file is missing or too short.
---@return string token The secret that a client must send.
local function read_token()
  ---@type file*?
  local f = io.open(token_path, "r")
  if f then
    ---@type string?
    local t = f:read("l")
    f:close()
    if t and #t >= 32 then return t end
  end
  ---@type file*
  local r = io.open("/dev/urandom", "rb")
  ---@type string
  local bytes = r:read(24)
  r:close()
  ---@type string
  local t = bytes:gsub(".", hex_byte)
  os.execute("umask 077; : > '" .. token_path .. "'")
  f = io.open(token_path, "w")
  f:write(t, "\n")
  f:close()
  return t
end
---@type string
local token = read_token()

---Writes a value as text, with the tables sorted by key so that the same value always gives the same text.
---@param v any The value to write.
---@param depth integer? How deep the value is inside the tables being written. It starts at 0.
---@param seen table<table, boolean>? The tables already visited, so that a cycle is cut.
---@return string text The value as text.
local function serialize(v, depth, seen)
  depth = depth or 0
  ---@type string
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t ~= "table" then return tostring(v) end
  if depth > 6 or (seen and seen[v]) then return "<...>" end
  seen = seen or {}
  seen[v] = true
  ---@type string[]
  local parts = {}
  for k, x in pairs(v) do
    parts[#parts + 1] = "[" .. serialize(k, depth + 1, seen) .. "]=" .. serialize(x, depth + 1, seen)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

---Runs the code that a client sent, and writes what it returns, or the error.
---@param source string The Lua code of the request.
---@return string result The values returned by the code, one on each line, or "error: " and the message.
local function run(source)
  -- An expression is returned as such, like in a REPL.
  ---@type function?
  local chunk = load("return " .. source, "=bridge") or load(source, "=bridge")
  if not chunk then
    ---@type function?, string?
    local _, err = load(source, "=bridge")
    return "error: " .. tostring(err)
  end
  ---@type table
  local results = table.pack(xpcall(chunk, debug.traceback))
  if not results[1] then return "error: " .. tostring(results[2]) end
  ---@type string[]
  local lines = {}
  for i = 2, results.n do lines[#lines + 1] = serialize(results[i]) end
  return table.concat(lines, "\n")
end

---@type any
local server = assert(socket.bind("127.0.0.1", PORT))
server:settimeout(0)
---@type BridgeClient[]
local clients = {}

---Sends the response to a client, and closes its connection.
---@param c BridgeClient The client to answer.
---@param body string The result of the request.
local function finish(c, body)
  c.sock:send(#body .. "\n" .. body)
  c.sock:close()
  c.done = true
end

---Reads what a client has sent so far, and answers it once its whole request has arrived.
---@param c BridgeClient The client to serve.
local function serve(c)
  ---@type string?, string?, string?
  local chunk, err, partial = c.sock:receive(4096)
  ---@type string?
  local got = chunk or partial
  if got and #got > 0 then c.buf = c.buf .. got end
  if err == "closed" then c.done = true return end
  if #c.buf > 1048576 then c.sock:close() c.done = true return end
  if not c.need then
    ---@type integer?
    local nl = c.buf:find("\n", 1, true)
    if not nl then return end
    ---@type string?, string?
    local t, n = c.buf:sub(1, nl - 1):match("^(%x+) (%d+)$")
    if t ~= token or not n then
      reaper.ShowConsoleMsg("reaper_bridge: refused a request\n")
      c.sock:close() c.done = true return
    end
    c.need = tonumber(n)
    c.buf = c.buf:sub(nl + 1)
  end
  if #c.buf >= c.need then finish(c, run(c.buf:sub(1, c.need))) end
end

-- Because REAPER builds a script's reaper table when the script starts, a
-- function registered later (by a plugin loaded with a project, for one) is
-- missing from it. bridge_reload() starts a fresh copy of this script, which
-- sees every function registered so far.
---@type boolean
local reload_requested = false

---Asks the bridge to restart itself. Because a client calls it through the bridge, no code in this file calls it.
---@return string answer The text sent back to the client, before the restart.
function bridge_reload()
  reload_requested = true
  return "reloading"
end

---Closes the connections and starts a fresh copy of this script.
local function reload()
  server:close()
  for _, c in ipairs(clients) do c.sock:close() end
  ---@type string
  local path = debug.getinfo(1, "S").source:sub(2)
  ---@type integer
  local id = reaper.AddRemoveReaScript(true, 0, path, true)
  reaper.Main_OnCommand(id, 0)
end

---Takes the new clients, serves the connected ones, and asks REAPER to call it again on its next cycle.
local function poll()
  if reload_requested then return reload() end
  while true do
    ---@type any
    local sock = server:accept()
    if not sock then break end
    sock:settimeout(0)
    clients[#clients + 1] = { sock = sock, buf = "" }
  end
  for i = #clients, 1, -1 do
    serve(clients[i])
    if clients[i].done then table.remove(clients, i) end
  end
  reaper.defer(poll)
end

---Closes the server when the script ends.
local function close_server()
  pcall(server.close, server)
end

reaper.atexit(close_server)
poll()
