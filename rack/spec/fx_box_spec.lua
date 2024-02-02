require 'busted.runner' ()
local Rack = require("components.Rack")
local State = require("state.state")
local Fx_box = require("components.Fx_box")
local Fx_separator = require("components.fx_separator")
local spec_helpers = require("spec.spec_helpers")
local create_fx = spec_helpers.create_fx
local drag_drop = require("state.dragAndDrop")

function Rack:mockInit()
    self.state = State:init() -- initialize state, query selected track and its fx
    self.ctx = {}
    self.Browser = nil
    return self
end

local fx = create_fx()
_G.reaper = {
    GetLastTouchedFX = function() --[[ last_fx]] end,
    GetTrackGUID = function() --[[trackGuid]] end,
    GetTrackName = function() --[[_, trackname]] end,
    TrackFX_Delete = function() --[[has_deleted]] end,
    TrackFX_GetEnabled = function() --[[fxEnabled]] end,
    TrackFX_GetParamName = function() --[[_, paramName]] end,
    GetSelectedTrack2 = function() return {} end,
    TrackFX_GetCount = function() return #fx end,
    TrackFX_GetFXGUID = function(_, idx) return fx[idx + 1].guid end,
    TrackFX_GetFXName = function(_, idx)
        if not idx then return "" end
        return fx[idx + 1].name
    end,
    ImGui_SameLine = function() end,
    ImGui_Button = function() end, -- return something on click?,e
    ImGui_BeginDragDropTarget = function(_) return true end,
    ImGui_AcceptDragDropPayload =
    ---@param drag_type DragDropType
    ---@param payload_fxNumber number
        function(_,
                 drag_type,
                 payload_fxNumber)
            return true, payload_fxNumber
        end,
}
--     local rv, payload_fxNumber = reaper.ImGui_AcceptDragDropPayload(self.ctx, drag_drop.types.drag_fx)
--     ---fx number of the dragged fx: fx.number is 0-indexed, fx_idx is 1-indexed
--     local src_fx_idx = tonumber(payload_fxNumber)
--     if rv and src_fx_idx then
--         local is_copy = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt())
--         --- if fx is dropped on a space adjacent to itself
--         local is_adjacent = dest_idx == src_fx_idx or dest_idx == src_fx_idx + 1
--         if is_adjacent then -- if trying to COPY to adjacent spaces (can’t move to adjacent spaces)
--             if is_copy then
--                 reaper.TrackFX_CopyToTrack(self.state.Track.track, src_fx_idx - 1, self.state.Track.track,
--                     dest_idx - 1,
--                     not is_copy)
--             end
--         else                                            -- if trying to move OR copy to non-adjacent spaces
--             local is_descending = dest_idx > src_fx_idx -- adjust the destination index if moving fx down
--             if is_descending then
--                 dest_idx = dest_idx - 1
--             end
--             reaper.TrackFX_CopyToTrack(self.state.Track.track, src_fx_idx - 1, self.state.Track.track, dest_idx - 1,
--                 not is_copy)
--         end
--     end
--     reaper.ImGui_EndDragDropTarget(self.ctx)
-- end



fx_separator:dragDropTarget(idx)

---draw the fx list
local function MockDrawFxList()
    if not self.state.Track then
        return
    end

    for idx, fx in ipairs(self.state.Track.fx_list) do
        reaper.ImGui_PushID(self.ctx, tostring(idx))
        Fx_separator:spaceBtwFx(idx)
        Fx_box:display(fx)
        reaper.ImGui_PopID(self.ctx)
    end
    Fx_separator:spaceBtwFx(#self.state.Track.fx_list + 1, true)
end


describe("Drag and Drop tests", function()
    local rack = Rack:mockInit()
    Fx_box:init(rack)
    Fx_separator:init(rack)
    pending("drag and drop: reorder fx up")
    pending("drag and drop: reorder fx down")
end)
