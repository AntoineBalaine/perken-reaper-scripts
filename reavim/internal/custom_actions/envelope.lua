--@noindex
local utils = require("custom_actions.utils")

local envelope = {}

function envelope.setTimeSelectionToSelectedEnvelopePoints()
  local startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if startPos ~= 0 and endPos ~= 0 then
    return
  end

  envelope = reaper.GetSelectedEnvelope(0)
  if envelope then
    local count = reaper.CountEnvelopePoints(envelope)
    -- get those of the points that are selected
    -- find the first one and the last one
    -- set time selection to their positions
    local first, last = nil, nil

    for i = 0, count - 1 do
      local _, time, _, _, _, selected = reaper.GetEnvelopePoint(envelope, i)
      if selected then
        if not first then
          first = time
        end
        last = time
      end
    end

    reaper.GetSet_LoopTimeRange(true, false, first, last, false)
  end
end

function envelope.SelectPointsCrossingTimeSelection()
  local startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if startPos == 0 and endPos == 0 then
    return
  end

  envelope = reaper.GetSelectedEnvelope(0)
  if envelope then
    local count = reaper.CountEnvelopePoints(envelope)
    for i = 0, count - 1 do
      local _, time, _, _, _, selected = reaper.GetEnvelopePoint(envelope, i)
      if time >= startPos and time <= endPos then
        reaper.SetEnvelopePoint(envelope, i, time, nil, nil, nil, true, true)
      end
    end
  end
end

---Get an envelope and return min, max, center. By Cfillion
---@param env Envelope
---@return number min
---@return number max
---@return number center
local function getEnvelopeRange(env)
  local ranges = {
    ['PARMENV']  = function(chunk)
      local min, max, center = chunk:match('^[^%s]+ [^%s]+ ([^%s]+) ([^%s]+) ([^%s]+)')
      local min, max, center = tonumber(min), tonumber(max), tonumber(center)
      return min, max, center
    end,
    ['VOLENV']   = function()
      local range = reaper.SNM_GetIntConfigVar('volenvrange', 0)
      local maxs = {
        [3] = 1,
        [1] = 1,
        [2] = 2,
        [0] = 2,
        [6] = 4,
        [4] = 4,
        [7] = 16,
        [5] = 16,
      }
      local max = maxs[range] or 2
      return 0, max, max == 1 and 0.5 or 1
    end,
    ['PANENV']   = { -1, 1, 0 },
    ['WIDTHENV'] = { -1, 1, 0 },
    ['MUTEENV']  = { 0, 1, 0.5 },
    ['SPEEDENV'] = { 0.1, 4, 1 },
    ['PITCHENV'] = function()
      local range = reaper.SNM_GetIntConfigVar('pitchenvrange', 0) & 0x0F
      return -range, range, 0
    end,
    ['TEMPOENV'] = function()
      local min = reaper.SNM_GetIntConfigVar('tempoenvmin', 0)
      local max = reaper.SNM_GetIntConfigVar('tempoenvmax', 0)
      return min, max, (max + min) / 2
    end,
  }

  local ok, chunk = reaper.GetEnvelopeStateChunk(env, '', false)
  assert(ok, 'failed to read envelope state chunk')

  local envType = chunk:match('<([^%s]+)')
  for matchType, range in pairs(ranges) do
    if envType:find(matchType) then
      if type(range) == 'function' then
        return range(chunk)
      end
      return table.unpack(range)
    end
  end

  error('unknown envelope type')
end

---@return TrackEnvelope | nil
---@return number | nil
---@return number | nil
---@return number | nil
local function getEnvelopeMinMaxValues()
  local envelope = reaper.GetSelectedEnvelope(0)
  if not envelope then
    return
  end

  local minValue, maxValue, centerValue = getEnvelopeRange(envelope)

  local faderScaling = reaper.GetEnvelopeScalingMode(envelope)

  if faderScaling == 1 then
    minValue = reaper.ScaleToEnvelopeMode(1, minValue)
    maxValue = reaper.ScaleToEnvelopeMode(1, maxValue)
    centerValue = reaper.ScaleToEnvelopeMode(1, centerValue)
  end
  return envelope, minValue, maxValue, centerValue
end

---@param val "min" | "max" | "center" | "down" | "up"
local function pegPoint(val)
  local envelope, minValue, maxValue, centerValue = getEnvelopeMinMaxValues()
  if not envelope then
    return
  end

  local count = reaper.CountEnvelopePoints(envelope)
  for i = 0, count - 1 do
    local _, time, value, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
    if val == "min" then
      value = minValue
    elseif val == "max" then
      value = maxValue
    elseif val == "center" then
      value = centerValue
    elseif val == "down" then
      value = value - 3
    elseif val == "up" then
      value = value + 3
    end
    if selected then
      reaper.SetEnvelopePoint(envelope, i, time, value, shape, tension, true, true)
    end
  end
end

function envelope.insertToggleAtTimeSelection()
  -- get edges of time selection
  local startTime, endTime = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if startTime ~= endTime then
    -- get selected envelope
    local envelope = reaper.GetSelectedEnvelope(0)
    if envelope then
      --get envelope max value
      local _, minValue, maxValue, centerValue = getEnvelopeMinMaxValues()
      -- insert points in envelope at start and endtimes
      reaper.InsertEnvelopePoint(envelope, startTime, minValue or 0, 1, 0, true, true)
      reaper.InsertEnvelopePoint(envelope, endTime, maxValue or 100, 1, 0, true, true)
    end
  end
end

local function DeleteAtTimeSelection(time_selection, point_time, start_time, end_time, env, env_points_count)
  if time_selection == true then
    if point_time > start_time and point_time < end_time then
      reaper.DeleteEnvelopePointRange(env, start_time, end_time)
    end
  else
    local retval_last, time_last, valueSource_last, shape_last, tension_last, selectedOut_last = reaper.GetEnvelopePoint(
      env,
      env_points_count - 1)
    reaper.DeleteEnvelopePointRange(env, 0, time_last + 1)
  end
end

function envelope.deletePoints()
  -- if there are selected points, delete them
  -- are there any envelope lanes selected?
  local env = reaper.GetSelectedEnvelope(0)
  if env then
    local time_selection = false
    local start_time, end_time = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time ~= end_time then
      time_selection = true
    end
    -- if there is a time selection, delete points for selected envelope lanes in time selection
    -- otherwise, deletpoints
    local env_points_count = reaper.CountEnvelopePoints(env)

    reaper.Main_OnCommand(40335, 0) -- copy selected points
    if env_points_count > 0 and time_selection then
      for k = 0, env_points_count - 1 do
        local retval, point_time, valueOut, shapeOutOptional, tensionOutOptional, selectedOutOptional = reaper
            .GetEnvelopePoint(env, k)
        DeleteAtTimeSelection()
      end
    else
      local has_selected_points = false
      for k = 0, env_points_count - 1 do
        local _, _, _, _, _, selected = reaper
            .GetEnvelopePoint(env, k)
        if selected then
          has_selected_points = true
          break
        end
      end
      if has_selected_points then
        reaper.Main_OnCommand(40333, 0)
      else
        reaper.Main_OnCommand(40325, 0)
      end
    end
  else
    return
  end
end

function envelope.moveEnvelopePointDown()
  pegPoint("down")
end

function envelope.moveEnvelopePointUp()
  pegPoint("up")
end

function envelope.setPointMin()
  pegPoint("min")
end

function envelope.setPointMax()
  pegPoint("max")
end

function envelope.setPointCenter()
  pegPoint("center")
end

local function toggleVisible(tr_env)
  local br_env = reaper.BR_EnvAlloc(tr_env, false)
  local active, visible, armed, inLane, laneHeight, defaultShape, _, _, _, _, faderScaling = reaper.BR_EnvGetProperties(
    br_env)
  if active then -- A.K.A. ByPassed ???
    visible = not visible
    reaper.BR_EnvSetProperties(br_env, active, visible, armed, inLane, laneHeight, defaultShape, faderScaling)
    reaper.BR_EnvFree(br_env, true)
  else
    reaper.BR_EnvFree(br_env, false)
  end
end
-- Function to hide an envelope by modifying its state chunk
function HideEnvelope(envelope)
  local _, envelopeStateChunk = reaper.GetEnvelopeStateChunk(envelope, "", false)

  -- Check if the envelope is not already hidden
  if not envelopeStateChunk:match("VIS 1") then
    -- Add visibility information to the state chunk to hide the envelope
    envelopeStateChunk = envelopeStateChunk:gsub("VIS %d", "VIS 0")

    -- Set the modified state chunk back to the envelope
    reaper.SetEnvelopeStateChunk(envelope, envelopeStateChunk, false)
    reaper.UpdateArrange()
  end
end

-- always show an envelope for the last touched param
function envelope.autoMode()
  local retval, fx_tracknumber, fxnumber, paramIndex = reaper.GetLastTouchedFX()
  if not retval then return end
  local tr_idx = utils.getTrackIndex(fx_tracknumber)

  local sel_tr = reaper.GetSelectedTrack(0, 0)
  local sel_tr_num = reaper.GetMediaTrackInfo_Value(sel_tr, "IP_TRACKNUMBER")

  -- if selected track is same as track of last touched fx, then proceed
  if fx_tracknumber == sel_tr_num and tr_idx then
    local track = reaper.GetTrack(0, tr_idx)                            -- get media track
    local env_count = reaper.CountTrackEnvelopes(track)                 --get selected track's envelopes
    local env = reaper.GetFXEnvelope(track, fxnumber, paramIndex, true) -- get the fx Envelopes
    for i = 0, env_count - 1 do                                         -- iterate
      local open_env = reaper.GetTrackEnvelope(track, i)                -- get tr env
      local br_env = reaper.BR_EnvAlloc(open_env, false)
      local _, visible, _, _, _, _, _, _, _, _, _, _ =
          reaper.BR_EnvGetProperties(br_env)
      if open_env ~= env and visible then
        reaper.SetCursorContext(2, open_env)                          -- select env
        reaper.Main_OnCommand(40884, 0)                               -- Toggle hide/display selected envelope
        local env_points_count = reaper.CountEnvelopePoints(open_env) -- find if there's any points
        if env_points_count <= 1 then                                 -- if only one point, then bypass
          reaper.SetEnvelopeStateChunk(open_env, "BYPASS 1", false)   -- empty bypassed envelopes get cleared
        end
      end
      reaper.BR_EnvFree(br_env, false)
    end
  end
end

return envelope
