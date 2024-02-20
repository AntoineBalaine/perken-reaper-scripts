--[[
The fx_separator is the little space between each of the fx boxes in the rack.
It’s used as a drag and drop destination to re-order the fx.
Any changes in order here will be reflected in reaper’s track fx.
Order of steps is:
- instantiate with init() from the base of the app.
- display using spaceBtwFx().
- add the dragDropTarget() to the component.
Upon receiving a drag-drop payload, the component calls the reaper api to update the fx chain,
and leaves it to the state module to update the rack at the next defer cycle.

Bear in mind that this component is a singleton, so it’s a single instance that is re-used across every appearance between FX.
As a result, its internal state has to be updated every time it’s called. I’m not sure yet whether I like this or would rather have one instance per appearance.
]]
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
    if reaper.ImGui_Button(self.ctx, '##Button between FX', 10, 220) and is_last then
        if not reaper.ImGui_IsPopupOpen(self.ctx, self.Browser.name) then
            reaper.ImGui_OpenPopup(self.ctx, self.Browser.name)
        end
    end
    self.Browser:Popup()
    fx_separator:dragDropTarget(idx)

    reaper.ImGui_SameLine(self.ctx, nil, 0)
end

---@param dest_idx integer
function fx_separator:dragDropTarget(dest_idx)
    if reaper.ImGui_BeginDragDropTarget(self.ctx) then
        local rv, payload_fxNumber = reaper.ImGui_AcceptDragDropPayload(self.ctx, drag_drop.types.drag_fx)
        ---fx number of the dragged fx: fx.number is 0-indexed, fx_idx is 1-indexed
        local src_fx_idx = tonumber(payload_fxNumber)
        if rv and src_fx_idx then
            local is_copy = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt())
            --- if fx is dropped on a space adjacent to itself
            local is_adjacent = dest_idx == src_fx_idx or dest_idx == src_fx_idx + 1
            if is_adjacent then -- if trying to COPY to adjacent spaces (can’t move to adjacent spaces)
                if is_copy then
                    reaper.TrackFX_CopyToTrack(self.state.Track.track, src_fx_idx - 1, self.state.Track.track,
                        dest_idx - 1,
                        not is_copy)
                end
            else                                            -- if trying to move OR copy to non-adjacent spaces
                local is_descending = dest_idx > src_fx_idx -- adjust the destination index if moving fx down
                if is_descending then
                    dest_idx = dest_idx - 1
                end
                reaper.TrackFX_CopyToTrack(self.state.Track.track, src_fx_idx - 1, self.state.Track.track, dest_idx - 1,
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
    self.Browser = parent_state.Browser
    return self
end

return fx_separator
