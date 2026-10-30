-- @noindex
-- A mock keyboard for the lab: the plugin's parameters with values, a connection state, a patch,
-- and the Registrations library read from REAPER's resource folder. Nothing here talks to MIDI.
local M = {}

-- Used when there is no registrations folder (another computer, before `build-install.sh vr09` has
-- copied the dumps): an organ patch, with the values of registration 1-1, and the neutral value of
-- each controller.
local DEMO = {
  ["organ-upper-d16"] = 8,
  ["organ-upper-d5f"] = 8,
  ["organ-upper-d8"] = 8,
  ["organ-upper-d4"] = 7,
  ["organ-upper-d2f"] = 4,
  ["organ-upper-d2"] = 4,
  ["organ-upper-d1f"] = 4,
  ["organ-upper-d1ff"] = 4,
  ["organ-upper-d1"] = 4,
  ["organ-lower-d16"] = 0,
  ["organ-lower-d5f"] = 0,
  ["organ-lower-d8"] = 8,
  ["organ-lower-d4"] = 6,
  ["organ-lower-d2f"] = 0,
  ["organ-lower-d2"] = 0,
  ["organ-lower-d1f"] = 0,
  ["organ-lower-d1ff"] = 0,
  ["organ-lower-d1"] = 0,
  ["organ-level"] = 127,
  ["overdrive"] = 12,
  ["leakage"] = 53,
  ["click-on"] = 16,
  ["click-off"] = 16,
  ["rotary-fast"] = 0,
  ["woofer-slow"] = 8,
  ["woofer-fast"] = 80,
  ["woofer-accel"] = 1,
  ["tweeter-slow"] = 5,
  ["tweeter-fast"] = 83,
  ["tweeter-accel"] = 4,
  ["rhythm-level"] = 90,
  ["song-level"] = 90,
  ["upper-synth-resonance"] = 64,
  ["upper-synth-attack"] = 64,
  ["upper-synth-decay"] = 64,
  ["upper-synth-release"] = 64,
  ["lower-synth-resonance"] = 64,
  ["lower-synth-attack"] = 64,
  ["lower-synth-decay"] = 64,
  ["lower-synth-release"] = 64,
  ["upper-piano-volume"] = 100,
  ["upper-synth-volume"] = 100,
  ["upper-synth2-volume"] = 100,
  ["lower-piano-volume"] = 100,
  ["lower-synth-volume"] = 100,
  ["cc-upper-vibrato-depth"] = 64,
  ["cc-upper-vibrato-rate"] = 64,
  ["cc-upper-reverb"] = 0,
  ["cc-upper-chorus"] = 0,
  ["cc-upper-expression"] = 127,
  ["cc-upper-pan"] = 64,
  ["cc-upper-cutoff"] = 64,
  ["cc-lower-cutoff"] = 64,
  ["cc-upper-resonance"] = 64,
  ["cc-upper-release"] = 64,
  ["cc-upper-attack"] = 64,
  ["cc-upper-decay"] = 64,
  ["cc-upper-modulation"] = 0,
  ["cc-lower-reverb"] = 0,
  ["cc-lower-chorus"] = 0,
  ["cc-lower-expression"] = 127,
  ["cc-piano-reverb"] = 0,
  ["cc-piano-chorus"] = 0,
  ["cc-piano-expression"] = 127,
  ["cc-master-expression"] = 127,
  ["reverb-type"] = 2,
  ["reverb-level"] = 16,
  ["reverb-variation"] = 0,
  ["vibrato-chorus-type"] = 3,
  ["mfx-type"] = 0,
  ["mfx-level"] = 0,
  ["delay-type"] = 1,
  ["delay-level"] = 0,
  ["compressor-level"] = 0
}

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

-- The registrations in `<resource>/Data/Perken/vr09/registrations`, sorted by bank and slot.
local function scan_registrations(folder)
  local list = {}
  local i = 0
  while true do
    local file = reaper.EnumerateFiles(folder, i)
    if not file then break end
    i = i + 1
    local bank, slot, name = file:match("^(%d+)%-(%d)_(.+)%.json$")
    if bank then
      list[#list + 1] = { bank = tonumber(bank), slot = tonumber(slot), name = name, file = file }
    end
  end
  table.sort(list, function(a, b)
    if a.bank ~= b.bank then return a.bank < b.bank end
    return a.slot < b.slot
  end)
  return list
end

function M.new(catalog, resource_path)
  local data = resource_path .. "/Data/Perken/vr09"
  local m = {
    data = data,
    catalog = catalog,
    by_address = {},
    values = {},
    connected = true,
    mode = "mode2",
    job = nil, -- { label = "Reading", done = 0, total = 22 } while the mock reads or writes
    patch = "(none)",
    split = false,
    follow_panel = true,
    recall_on_load = false,
    registrations = scan_registrations(data .. "/registrations"),
  }
  for _, p in ipairs(catalog) do
    m.values[p.id] = p.low
    if p.kind == "dt1" then m.by_address[p.address] = p end
  end
  if #m.registrations == 0 then
    for id, v in pairs(DEMO) do
      if m.values[id] then m.values[id] = v end
    end
    m.patch = "Demo organ (no registrations folder)"
  end
  return m
end

local function splits(m)
  local set = {}
  local text = read(m.data .. "/splits.txt")
  if text then
    for line in text:gmatch("[^\r\n]+") do set[line] = true end
  end
  return set
end

function M.patch_name(entry)
  return string.format("%d-%d %s", entry.bank, entry.slot, entry.name)
end

-- Sets the parameters from a registration's dump (JSON of "block:packed address": value).
function M.load_registration(m, entry)
  local text = read(m.data .. "/registrations/" .. entry.file)
  if not text then return false end
  for _, param in pairs(m.by_address) do m.values[param.id] = param.low end
  -- Only the keyboard's own blocks are in the catalog; the key's block name is not needed, since
  -- the packed address says where the byte is.
  for _, hex, value in text:gmatch('"([%w_]+):(%x+)"%s*:%s*(%d+)') do
    local param = m.by_address[tonumber(hex, 16)]
    if param then m.values[param.id] = tonumber(value) end
  end
  m.patch = M.patch_name(entry)
  m.split = splits(m)[m.patch] or false
  return true
end

return M
