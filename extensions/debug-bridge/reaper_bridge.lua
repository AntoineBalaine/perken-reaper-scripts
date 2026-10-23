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

local PORT = tonumber(os.getenv("BRIDGE_PORT")) or 9876
local sockets = "/Scripts/Mavriq ReaScript Repository/Various/Mavriq-Lua-Sockets/"
-- A scratch REAPER (another resource folder) borrows the sockets installed in
-- the user's own folder.
for _, base in ipairs({ reaper.GetResourcePath(), os.getenv("HOME") .. "/.config/REAPER" }) do
  package.path = package.path .. ";" .. base .. sockets .. "?.lua"
  package.cpath = package.cpath .. ";" .. base .. sockets .. "?.so"
end
local socket = require("socket")

local data_dir = reaper.GetResourcePath() .. "/Data/Perken"
reaper.RecursiveCreateDirectory(data_dir, 0)
local token_path = data_dir .. "/bridge.token"

local function read_token()
  local f = io.open(token_path, "r")
  if f then
    local t = f:read("l")
    f:close()
    if t and #t >= 32 then return t end
  end
  local r = io.open("/dev/urandom", "rb")
  local bytes = r:read(24)
  r:close()
  local t = bytes:gsub(".", function(c) return string.format("%02x", c:byte()) end)
  os.execute("umask 077; : > '" .. token_path .. "'")
  f = io.open(token_path, "w")
  f:write(t, "\n")
  f:close()
  return t
end
local token = read_token()

local function serialize(v, depth, seen)
  depth = depth or 0
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t ~= "table" then return tostring(v) end
  if depth > 6 or (seen and seen[v]) then return "<...>" end
  seen = seen or {}
  seen[v] = true
  local parts = {}
  for k, x in pairs(v) do
    parts[#parts + 1] = "[" .. serialize(k, depth + 1, seen) .. "]=" .. serialize(x, depth + 1, seen)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function run(source)
  -- An expression is returned as such, like in a REPL.
  local chunk = load("return " .. source, "=bridge") or load(source, "=bridge")
  if not chunk then
    local _, err = load(source, "=bridge")
    return "error: " .. tostring(err)
  end
  local results = table.pack(xpcall(chunk, debug.traceback))
  if not results[1] then return "error: " .. tostring(results[2]) end
  local lines = {}
  for i = 2, results.n do lines[#lines + 1] = serialize(results[i]) end
  return table.concat(lines, "\n")
end

local server = assert(socket.bind("127.0.0.1", PORT))
server:settimeout(0)
local clients = {}

local function finish(c, body)
  c.sock:send(#body .. "\n" .. body)
  c.sock:close()
  c.done = true
end

local function serve(c)
  local chunk, err, partial = c.sock:receive(4096)
  local got = chunk or partial
  if got and #got > 0 then c.buf = c.buf .. got end
  if err == "closed" then c.done = true return end
  if #c.buf > 1048576 then c.sock:close() c.done = true return end
  if not c.need then
    local nl = c.buf:find("\n", 1, true)
    if not nl then return end
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
local reload_requested = false
function bridge_reload()
  reload_requested = true
  return "reloading"
end

local function reload()
  server:close()
  for _, c in ipairs(clients) do c.sock:close() end
  local path = debug.getinfo(1, "S").source:sub(2)
  local id = reaper.AddRemoveReaScript(true, 0, path, true)
  reaper.Main_OnCommand(id, 0)
end

local function poll()
  if reload_requested then return reload() end
  while true do
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

reaper.atexit(function() pcall(server.close, server) end)
poll()
