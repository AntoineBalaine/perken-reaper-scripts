-- The session's scene list and the moves that keep an automation lane right. Nothing here draws or
-- talks to REAPER, so the same rules can be tested alone and then written in the plugin.
--
-- A scene is { name, patch }, where `patch` is a copy of the library row that it plays. The list is
-- dense: scene 1 is the first, and the plugin's Scene parameter holds a position (0 for none). A lane
-- is a list of points { bar, scene }, standing for the points of the parameter's automation lane. Because
-- a point holds a position, moving or removing a scene changes what a position means, so the same
-- change is applied to the lane: the song then keeps playing the same scenes.
local M = {}

-- The Scene parameter has a fixed range, so that adding a scene never rescales the lane's points.
M.MAX = 127

-- Orders lane points by bar.
function M.bar_less(a, b)
  return a.bar < b.bar
end

-- Gives each scene an ID of its own, kept when the scene moves, so that the panel can follow a scene
-- while it is dragged. Scenes that have one keep it.
function M.ensure_uids(list)
  local top = 0
  for _, scene in ipairs(list) do top = math.max(top, scene.uid or 0) end
  for _, scene in ipairs(list) do
    if not scene.uid then
      top = top + 1
      scene.uid = top
    end
  end
end

-- Adds a copy of a patch at the end. Gives the position, or nil when the list is full.
function M.add(list, name, patch)
  if #list >= M.MAX then return nil end
  local copy = {}
  for k, v in pairs(patch) do copy[k] = v end
  list[#list + 1] = { name = name, patch = copy }
  M.ensure_uids(list)
  return #list
end

-- Where each position goes when the scene at `from` is moved to `to`.
function M.move_mapping(count, from, to)
  local map = {}
  for i = 1, count do
    if i == from then
      map[i] = to
    elseif from < to and i > from and i <= to then
      map[i] = i - 1
    elseif from > to and i >= to and i < from then
      map[i] = i + 1
    else
      map[i] = i
    end
  end
  return map
end

-- Where each position goes when the scene at `at` is removed: its own points fall to 0 (no scene).
function M.remove_mapping(count, at)
  local map = {}
  for i = 1, count do
    map[i] = i == at and 0 or (i > at and i - 1 or i)
  end
  return map
end

-- Gives every point its new position. The old positions are all read through the mapping, never
-- the already changed ones. Returns how many points changed.
function M.remap_lane(lane, map)
  local changed = 0
  for _, point in ipairs(lane) do
    local new = map[point.scene]
    if new and new ~= point.scene then
      point.scene = new
      changed = changed + 1
    end
  end
  return changed
end

-- Moves a scene and the lane with it. Returns the number of points that changed, or nil if the
-- move is not one.
function M.move(list, lane, from, to)
  if from == to or from < 1 or to < 1 or from > #list or to > #list then return nil end
  local map = M.move_mapping(#list, from, to)
  local scene = table.remove(list, from)
  table.insert(list, to, scene)
  return M.remap_lane(lane, map)
end

-- Removes a scene; the scenes after it move up, and the lane follows.
function M.remove(list, lane, at)
  if at < 1 or at > #list then return nil end
  local map = M.remove_mapping(#list, at)
  table.remove(list, at)
  return M.remap_lane(lane, map)
end

-- Orders presets by name without regard to case.
function M.preset_less(a, b)
  return a.name:lower() < b.name:lower()
end

-- Orders names without regard to case.
function M.text_less(a, b)
  return a:lower() < b:lower()
end

-- ---- templates ----
--
-- A template is the scenes' names and the IDs of their patches, one scene to a line, the two separated by
-- a tab. Because it holds an ID and not the patch, a template follows the library: a patch that
-- is no longer there is counted as missing when the template is read.

function M.to_text(list)
  local lines = {}
  for _, scene in ipairs(list) do
    -- A scene made from the plugin's own state has no library patch, so a template cannot hold it.
    if scene.patch.value and scene.patch.value > 0 then
      local name = scene.name:gsub("[\t\r\n]", " ")
      lines[#lines + 1] = ("%s\t%d"):format(name, scene.patch.value)
    end
  end
  return table.concat(lines, "\n") .. (#lines > 0 and "\n" or "")
end

-- Reads a template. `patch_by_id` maps a patch ID to the library's row for it. Returns the scenes, and the
-- number of lines that were left out because their patch is not in the library.
function M.from_text(text, patch_by_id)
  local list, missing = {}, 0
  for line in text:gmatch("[^\r\n]+") do
    local name, id = line:match("^(.-)\t(%d+)$")
    if name then
      local patch = patch_by_id[tonumber(id)]
      if patch then M.add(list, name, patch) else missing = missing + 1 end
    end
  end
  return list, missing
end

return M
