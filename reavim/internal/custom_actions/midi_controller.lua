local serpent = require("serpent")
local namespace = "reaper_keys"
local table_name = "mod_source"
local utils = require("custom_actions.utils")
-- dofile("/home/antoine/.config/REAPER/UserPlugins/ultraschall_api.lua")

-- local ultraschall = require("ultraschall_api")
local midi_controller = {}
---@class Modulator
---@field target_name string - the name of the fx param, e.g. "LFO_INSTANCE"
---@field fxIdx integer - the index of the fx in the chain
---@field parmeterIdx integer - the index of the parameter in the fx

---credit to mpl
---thread https://forum.cockos.com/showthread.php?t=216683
---@param track MediaTrack
---@param fx_idx integer
---@param new_name string
local function setFXName(track, fx_idx, new_name)
  if not new_name then return end

  local edited_line, edited_line_id, segm ---@type string, integer, string
  -- get ref guid
  if not track or not tonumber(fx_idx) then return end
  local FX_GUID = reaper.TrackFX_GetFXGUID(track, fx_idx)
  if not FX_GUID then return else FX_GUID = FX_GUID:gsub('-', ''):sub(2, -2) end
  local plug_type = reaper.TrackFX_GetIOSize(track, fx_idx)
  -- get chunk t
  local retval, chunk = reaper.GetTrackStateChunk(track, '', false)
  local t = {}
  for line in chunk:gmatch("[^\r\n]+") do t[#t + 1] = line end
  -- find edit line
  local search
  for i = #t, 1, -1 do
    local t_check = t[i]:gsub('-', '')
    if t_check:find(FX_GUID) then search = true end
    if t[i]:find('<') and search and not t[i]:find('JS_SER') then
      edited_line = t[i]:sub(2)
      edited_line_id = i
      break
    end
  end
  -- parse line
  if not edited_line then return end
  local t1 = {}
  for word in edited_line:gmatch('[%S]+') do t1[#t1 + 1] = word end
  local t2 = {}
  for i = 1, #t1 do
    segm = t1[i]
    if not q then t2[#t2 + 1] = segm else t2[#t2] = t2[#t2] .. ' ' .. segm end
    if segm:find('"') and not segm:find('""') then if not q then q = true else q = nil end end
  end

  if plug_type == 2 then t2[3] = '"' .. new_name .. '"' end -- if JS
  if plug_type == 3 then t2[5] = '"' .. new_name .. '"' end -- if VST

  local out_line = table.concat(t2, ' ')
  t[edited_line_id] = '<' .. out_line
  local out_chunk = table.concat(t, '\n')
  --msg(out_chunk)
  reaper.SetTrackStateChunk(track, out_chunk, false)
end

-- Return -1 if no FX with the given alias is found
---@param track MediaTrack
---@param alias string
local function getTrackFxIdxByAlias(track, alias)
  local fxCount = reaper.TrackFX_GetCount(track)
  for fxIndex = 0, fxCount - 1 do
    local _, fxName = reaper.TrackFX_GetFXName(track, fxIndex)
    if fxName == alias then
      return fxIndex
    end
  end
  return -1 -- Return -1 if no FX with the given alias is found
end

---Find fx by its alias. If not found, add it
---@param orig_name string
---@param fx_alias string
---@param preset_name? string
local function getFXIdxByName(orig_name, fx_alias, preset_name)
  local track = reaper.GetSelectedTrack(0, 0)                     -- get track
  local fx_idx = getTrackFxIdxByAlias(track, fx_alias)            -- find fx index
  if fx_idx < 0 then
    fx_idx = reaper.TrackFX_AddByName(track, orig_name, false, 0) -- add track FX
    setFXName(track, fx_idx, fx_alias)                            -- rename instance
    if preset_name then
      reaper.TrackFX_SetPreset(track, fx_idx, preset_name)        -- set preset
    end
  end
  return fx_idx
end

--[[
  will have to setup mechanism to get Origin.

  Maybe something like a list of sources (LFO, Envelope, etc) in the actions menu.

  The actions that go into action list could be named «VirtualButton\<ButtonNumber\>_SetAsModSource»
]]
---@param orig_name string
---@param fx_alias string
---@param param_idx integer
---@param preset_name? string
function midi_controller.setModSource(orig_name, fx_alias, param_idx, preset_name)
  local fx_idx = getFXIdxByName(orig_name, fx_alias, preset_name)
  ---@type Modulator
  local modulator = {
    target_name = fx_alias,
    fxIdx = fx_idx,
    parmeterIdx = param_idx
  }
  local lua_table_string = serpent.dump(modulator, { comment = false }) -- stringify the modulator
  reaper.SetExtState(namespace, table_name, lua_table_string, true)     -- set extstate to contain modulator
end

---@class ModTable
---@field PARAM_NR integer - the parameter that you want to modulate; 1 for the first, 2 for the second, etc
---@field PARAM_TYPE string | "wet" | "bypass"  - the type of the parameter, usually "", "wet" or "bypass"
---@field PARAMOD_ENABLE_PARAMETER_MODULATION boolean - Enable parameter modulation, baseline value(envelope overrides)-checkbox; true, checked; false, unchecked
---@field PARAMOD_BASELINE number - Enable parameter modulation, baseline value(envelope overrides)-slider; 0.000 to 1.000
---@field AUDIOCONTROL boolean             - is the Audio control signal(sidechain)-checkbox checked; true, checked; false, unchecked Note: if true, this needs all AUDIOCONTROL_-entries to be set
---@field AUDIOCONTROL_CHAN integer       - the Track audio channel-dropdownlist; When stereo, the first stereo-channel; nil, if not available
---@field AUDIOCONTROL_STEREO integer|nil      - 0, just use mono-channels; 1, use the channel AUDIOCONTROL_CHAN plus  AUDIOCONTROL_CHAN+1; nil, if not available
---@field AUDIOCONTROL_ATTACK number     - the Attack-slider of Audio Control Signal; 0-1000 ms; nil, if not available
---@field AUDIOCONTROL_RELEASE number    - the Release-slider; 0-1000ms; nil, if not available
---@field AUDIOCONTROL_MINVOLUME number  - the Min volume-slider; -60dB to 11.9dB; must be smaller than AUDIOCONTROL_MAXVOLUME; nil, if not available
---@field AUDIOCONTROL_MAXVOLUME number  - the Max volume-slider; -59.9dB to 12dB; must be bigger than AUDIOCONTROL_MINVOLUME; nil, if not available
---@field AUDIOCONTROL_STRENGTH number   - the Strength-slider; 0(0%) to 1000(100%)
---@field AUDIOCONTROL_DIRECTION integer  - the direction-radiobuttons; -1, negative; 0, centered; 1, positive
---@field X2 number=0.5                  - the audiocontrol signal shaping-x-coordinate
---@field Y2 number=0.5                  - the audiocontrol signal shaping-y-coordinate
---@field LFO boolean                      - if the LFO-checkbox checked; true, checked; false, unchecked Note: if true, this needs all LFO_-entries to be set
---@field LFO_SHAPE integer               - the LFO Shape-dropdownlist;  0, sine; 1, square; 2, saw L; 3, saw R; 4, triangle; 5, random; nil, if not available
---@field LFO_SHAPEOLD integer            - use the old-style of the LFO_SHAPE; 0, use current style of LFO_SHAPE;  1, use old style of LFO_SHAPE;  nil, if not available
---@field LFO_TEMPOSYNC boolean           - the Tempo sync-checkbox; true, checked; false, unchecked
---@field LFO_SPEED number                - the LFO Speed-slider; 0(0.0039Hz) to 1(8.0000Hz); nil, if not available
---@field LFO_STRENGTH number            - the LFO Strength-slider; 0.000(0.0%) to 1.000(100.0%)
---@field LFO_PHASE  number              - the LFO Phase-slider; 0.000 to 1.000; nil, if not available
---@field LFO_DIRECTION integer           - the LFO Direction-radiobuttons; -1, Negative; 0, Centered; 1, Positive
---@field LFO_PHASERESET number          - the LFO Phase reset-dropdownlist;  0, On seek/loop(deterministic output); 1, Free-running(non-deterministic output) nil, if not available
---@field MIDIPLINK boolean               - true, if any parameter-linking with MIDI-stuff; false, if not Note: if true, this needs all MIDIPLINK_-entries and PARMLINK_LINKEDPLUGIN=-100 to be set
---@field PARMLINK boolean                - the Link from MIDI or FX parameter-checkbox true, checked; false, unchecked
---@field PARMLINK_LINKEDPLUGIN number|nil    - the selected plugin; nil, if not available - will be ignored, when PARMLINK_LINKEDPLUGIN_RELATIVE is set;-1, nothing selected yet;-100, MIDI-parameter-settings;1 - the first fx-plugin;2 - the second fx-plugin;3 - the third fx-plugin, etc
---@field PARMLINK_LINKEDPLUGIN_RELATIVE number|nil - the linked plugin relative to the current one in the FXChain; - 0, use parameter of the current fx-plugin;- negative, use parameter of a plugin above of the current plugin(-1, the one above; -2, two above, etc);- positive, use parameter of a plugin below the current plugin(1, the one below; 2, two below, etc);- nil, use only the plugin linked absolute(the one linked with PARMLINK_LINKEDPARMIDX);
---@field PARMLINK_LINKEDPARMIDX integer|nil   - the id of the linked parameter; -1, if none is linked yet; nil, if not available. When MIDI, this is irrelevant. When FX-parameter:0 to n; 0 for the first; 1, for the second, etc
---@field PARMLINK_OFFSET   number|nil       - the Offset-slider; -1.00(-100%) to 1.00(+100%); nil, if not available
---@field PARMLINK_SCALE number | nil           - the Scale-slider; -1.00(-100%) to 1.00(+100%); nil, if not available
---@field MIDIPLINK_BUS integer|nil            - the MIDI-bus selected in the button-menu;  0 to 15 for bus 1 to 16;  nil, if not available
---@field MIDIPLINK_CHANNEL integer | nil       - the MIDI-channel selected in the button-menu;  0, omni; 1 to 16 for channel 1 to 16;  nil, if not available
---@field MIDIPLINK_MIDICATEGORY integer | nil  - the MIDI_Category selected in the button-menu; nil, if not available; 144, MIDI note ;160, Aftertouch ;176, CC 14Bit and CC ;192, Program Change ;208, Channel Pressure ;224, Pitch
---@field MIDIPLINK_MIDINOTE integer|nil       - the MIDI-note selected in the button-menu; nil, if not available; When MIDI note: 0(C-2) to 127(G8); When Aftertouch: 0(C-2) to 127(G8); When CC14 Bit: 128 to 159; see dropdownlist for the commands(the order of the list is the same as this numbering); When CC: 0 to 119; see dropdownlist for the commands(the order of the list is the same as this numbering); When Program Change: 0; When Channel Pressure: 0; When Pitch: 0;
---@field WINDOW_ALTERED boolean           - false, if the windowposition hasnt been altered yet; true, if the window has been altered. Note: if true, this needs all WINDOW_-entries to be set
---@field WINDOW_ALTEREDOPEN integer|nil      - if the position of the ParmMod-window is altered and currently open;  nil, unchanged; 0, unopened; 1, open
---@field WINDOW_XPOS number|nil              - the x-position of the altered ParmMod-window in pixels; nil, default position
---@field WINDOW_YPOS   number|nil            - the y-position of the altered ParmMod-window in pixels; nil, default position
---@field WINDOW_RIGHT number|nil            - the right-position of the altered ParmMod-window in pixels;  nil, default position; only readable
---@field WINDOW_BOTTOM number|nil            - the bottom-position of the altered ParmMod-window in pixels;  nil, default position; only readable

---@param orig_name string
---@param fx_alias string
---@param param_idx integer
---@param preset_name? string
function midi_controller.setModDestination(orig_name, fx_alias, param_idx, preset_name)
  local fx_idx = getFXIdxByName(orig_name, fx_alias, preset_name) ---find fxindex


  local ext_state = reaper.GetExtState(namespace, table_name)
  local ok, modulator = serpent.load(ext_state) ---@type boolean, Modulator
  if not ok then return end

  local track = reaper.GetSelectedTrack(0, 0)                                 -- get track
  local tracknumber = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") -- get track number
  -- get track index from tracknumber
  ---add 1, since ultraschall uses 1-based indexing
  local trackIndex = utils.getTrackIndex(tracknumber)

  local rv, trackstatechunk = ultraschall.GetTrackStateChunk_Tracknumber(trackIndex + 1) ---@type boolean, string -- get track state chunk
  local FXStateChunk = ultraschall.GetFXStateChunk(trackstatechunk) ---@type  string|nil, integer -- get FX state chunk
  local ParmModTable = ultraschall.GetParmModTable_FXStateChunk(FXStateChunk, fx_idx + 1, param_idx + 1) ---@type ModTable|nil -- get ParmModulationTable
  local noTable = ParmModTable == nil
  if ParmModTable == nil then
    ParmModTable = ultraschall.CreateDefaultParmModTable() ---@type ModTable -- get ParmModulationTable
  end

  ParmModTable.PARAM_NR = param_idx + 1
  ParmModTable.PARAMOD_ENABLE_PARAMETER_MODULATION = true         -- enable parameter modulation,
  ParmModTable.PARMLINK = true                                    -- set param linking,
  ParmModTable.PARMLINK_LINKEDPLUGIN = modulator.fxIdx + 1        --set linked plugin,
  ParmModTable.PARMLINK_LINKEDPARMIDX = modulator.parmeterIdx + 1 --set linked parameter
  ParmModTable.PARAMOD_BASELINE = 0.000
  ParmModTable.PARMLINK_SCALE = 1.00
  ParmModTable.PARMLINK_OFFSET = 0.00
  ---TODO add baseline, scale, offset

  if noTable then
    FXStateChunk = ultraschall.AddParmMod_ParmModTable(FXStateChunk, fx_idx + 1, ParmModTable) ---@type string
  else
    FXStateChunk = ultraschall.SetParmMod_ParmModTable(FXStateChunk, fx_idx + 1, ParmModTable) ---@type string -- updated FX state chunk
  end

  --- TODO is this redundant?
  local rv, StateChunk = ultraschall.SetFXStateChunk(trackstatechunk, FXStateChunk) ---@type boolean, string|nil -- set new FX state chunk
  if (not rv) then return end
  reaper.SetTrackStateChunk(track, StateChunk, false) -- set state chunk
end

function midi_controller.devAction()
  local orig_name = "JS: LFO"
  local source_fx = "JS: LFO_ALIAS"
  midi_controller.setModSource(orig_name, source_fx, 10)
  local param_name = "parameter modulation (link me !)"
  local dest_fx = "JS: Use slider1 for parameter modulation linking. [Dummy]"
  midi_controller.setModDestination(dest_fx, dest_fx, 0)
end

return midi_controller
