-- The lab's link to the real plugin: the VR-09 on the selected track, its Scene parameter, the plugin's
-- scene commands, and the automation lane of that parameter. Nothing here draws. Because the plugin
-- owns the scenes, the lab asks it and shows what it answers.
local M = {}

M.FX_NAME = "VR-09"
M.PARAM_NAME = "Scene"
-- The Scene parameter's fixed range (scenes.max_scenes in the plugin). A lane point holds the parameter's
-- value in the units that REAPER reports for it (TrackFX_GetParamEx), which run from `min` to `max`.
-- Those units may be 0 to 127 or 0 to 1, so a position is scaled across whatever REAPER reports.
M.RANGE = 127

-- The envelope point shape that holds its value until the next point, so that no scene is selected on
-- the way between two.
M.SQUARE_SHAPE = 1

-- The VR-09 of the selected track and its Scene parameter: { track, fx, param }, or nil and the reason.
function M.target()
  local track = reaper.GetSelectedTrack(0, 0)
  if not track then return nil, "Select the track that has the VR-09 first." end
  if not reaper.APIExists("VR09_Command") then
    return nil, "The VR-09 plugin is not loaded in this REAPER: install the new build and restart REAPER."
  end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, fx)
    if name:find(M.FX_NAME, 1, true) then
      for param = 0, reaper.TrackFX_GetNumParams(track, fx) - 1 do
        local _, param_name = reaper.TrackFX_GetParamName(track, fx, param)
        if param_name == M.PARAM_NAME then return { track = track, fx = fx, param = param } end
      end
      return nil, "This VR-09 has no Scene parameter: it is an older build. Install the new one and restart REAPER."
    end
  end
  return nil, "The selected track has no VR-09 on it."
end

-- Runs a plugin command; gives its JSON reply.
function M.command(target, name, arg)
  return reaper.VR09_Command(target.track, target.fx, name, arg or "")
end

function M.ok(reply)
  return reply ~= nil and reply:find('"ok":true', 1, true) ~= nil
end

function M.error_of(reply)
  return reply and reply:match('"error":"(.-)"') or "no answer from the plugin"
end

-- The scenes of a `scenes` reply: a list of { name, label, patch_id }, and the current position.
function M.read_scenes(reply)
  local list = {}
  for patch_id, name, label in reply:gmatch('"patch_id":(%d+),"name":"(.-)","label":"(.-)"}') do
    list[#list + 1] = {
      name = name:gsub('\\(["\\\\])', "%1"),
      label = label:gsub('\\(["\\\\])', "%1"),
      patch_id = tonumber(patch_id),
    }
  end
  return list, tonumber(reply:match('"current":(%d+)')) or 0
end

-- The mapping of a `scene_move` or `scene_remove` reply: map[old position] = new position.
function M.read_map(reply)
  local text = reply:match('"map":%[([%d,]*)%]')
  if not text then return nil end
  local map = {}
  for number in text:gmatch("%d+") do map[#map + 1] = tonumber(number) end
  return map
end

-- The value of a lane point that selects `position`, and the position that a point's value selects.
function M.value_of(position, min, max)
  return min + position / M.RANGE * (max - min)
end

function M.position_of(value, min, max)
  return math.floor((value - min) / (max - min) * M.RANGE + 0.5)
end

-- Gives every point of the Scene lane (and of its automation items) its new position, so that moving
-- or removing a scene leaves the song playing the same scenes. Each point is read once and written
-- once, so none is mapped twice. Returns how many points changed.
function M.remap_lane(target, map)
  local envelope = reaper.GetFXEnvelope(target.track, target.fx, target.param, false)
  if not envelope then return 0 end
  local _, min, max = reaper.TrackFX_GetParamEx(target.track, target.fx, target.param)
  local changed = 0
  reaper.Undo_BeginBlock()
  for item = -1, reaper.CountAutomationItems(envelope) - 1 do
    for index = 0, reaper.CountEnvelopePointsEx(envelope, item) - 1 do
      local _, time, value, shape, tension, selected = reaper.GetEnvelopePointEx(envelope, item, index)
      local position = M.position_of(value, min, max)
      local new = map[position]
      if new and new ~= position then
        reaper.SetEnvelopePointEx(envelope, item, index, time, M.value_of(new, min, max), shape, tension, selected, true)
        changed = changed + 1
      end
    end
    reaper.Envelope_SortPointsEx(envelope, item)
  end
  reaper.Undo_EndBlock("Move the points of the VR-09 scene lane", -1)
  reaper.UpdateArrange()
  return changed
end

-- Puts a square point at the edit cursor on the Scene lane, set to `position`. GetFXEnvelope creates the
-- lane when the track does not have one. Returns the time, or nil and the reason.
function M.insert_point(target, position)
  local envelope = reaper.GetFXEnvelope(target.track, target.fx, target.param, true)
  if not envelope then return nil, "REAPER could not create the lane." end
  local _, min, max = reaper.TrackFX_GetParamEx(target.track, target.fx, target.param)
  local time = reaper.GetCursorPosition()
  reaper.Undo_BeginBlock()
  reaper.InsertEnvelopePoint(envelope, time, M.value_of(position, min, max), M.SQUARE_SHAPE, 0, false, true)
  reaper.Envelope_SortPoints(envelope)
  reaper.Undo_EndBlock("Insert a VR-09 scene point", -1)
  reaper.UpdateArrange()
  return time
end

return M
