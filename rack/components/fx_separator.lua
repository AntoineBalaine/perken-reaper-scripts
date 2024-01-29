local drag_drop = require("state.dragAndDrop")

--- call to insert spaces between fx windows,
--- display the fx browser, and drag and drop fx
local fx_separator = {}

--- draw spaces between fx windows:
--- those spaces are the drag and drop destinations
--
--- if `is_last`, on click display the fx browser,
---@param idx integer
---@param is_last? boolean
function fx_separator:spaceBtwFx(idx, is_last)
  local ctx = self.ctx

  if reaper.ImGui_Button(ctx, '##Button between FX', 10, 220) and is_last then
    --- DISPLAY FX BROWSER
    reaper.Main_OnCommand(40271, 0)
  end
  fx_separator:dragDropTarget(idx)

  reaper.ImGui_SameLine(ctx, nil, 5)
end

---@param dest_idx integer
function fx_separator:dragDropTarget(dest_idx)
  if reaper.ImGui_BeginDragDropTarget(self.ctx) then
    local rv, payload_fxNumber = reaper.ImGui_AcceptDragDropPayload(self.ctx, drag_drop.types.drag_fx)
    ---fx number of the dragged fx: fx.number is 0-indexed, fx_idx is 1-indexed
    local src_fx_number = tonumber(payload_fxNumber)
    if rv and src_fx_number then
      reaper.ShowConsoleMsg(dest_idx .. '\n')
      reaper.ShowConsoleMsg(src_fx_number .. '\n')
      local is_copy = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt())
      --- if fx is dropped on a space adjacent to itself
      local is_adjacent = dest_idx == src_fx_number or dest_idx == src_fx_number + 1
      reaper.ShowConsoleMsg("is_adjacent " .. tostring(is_adjacent) .. '\n')
      if is_adjacent then -- if trying to COPY to adjacent spaces (can’t move to adjacent spaces)
        if is_copy then
          reaper.TrackFX_CopyToTrack(self.state.Track.track, src_fx_number, self.state.Track.track,
            dest_idx,
            not is_copy)
        end
      else -- if trying to move OR copy to non-adjacent spaces
        reaper.TrackFX_CopyToTrack(self.state.Track.track, src_fx_number, self.state.Track.track, dest_idx,
          not is_copy)
      end
    end
    reaper.ImGui_EndDragDropTarget(self.ctx)
  end
end

---@param parent_state Rack
function fx_separator:init(parent_state)
  self.state = parent_state.state
  self.ctx = parent_state.ctx
  return self
end

return fx_separator
