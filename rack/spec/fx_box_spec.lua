if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
require 'busted.runner' ()
local dummy_theme = require("spec.dummy_theme")
local theme = dummy_theme.theme

local spec_helpers = require("spec.spec_helpers")
local create_fx = spec_helpers.create_fx
local fx = create_fx()
_G.reaper = {
    TrackFX_GetNumParams = function() return 0 end,
    GetMediaTrackInfo_Value = function() return "trackNumber" end,
    TrackFX_GetCount = function() return #fx end,
    GetLastTouchedFX = function() --[[ last_fx]] end,
    GetTrackGUID = function() --[[trackGuid]] end,
    GetTrackName = function() --[[_, trackname]] end,
    TrackFX_Delete = function() --[[has_deleted]] end,
    TrackFX_GetEnabled = function() --[[fxEnabled]] end,
    TrackFX_GetParamName = function() --[[_, paramName]] end,
    GetSelectedTrack2 = function() return {} end,
    TrackFX_GetFXGUID = function(_, idx) return fx[idx + 1].guid end,
    TrackFX_GetFXName = function(_, idx)
        if not idx then return "" end
        return fx[idx + 1].name
    end,
    ImGui_SameLine = function() end,
    ImGui_Button = function() end, -- return something on click?,e
    ImGui_BeginDragDropTarget = function(_) return true end,
    ImGui_EndDragDropTarget = function() return true end,
    ImGui_AcceptDragDropPayload =
    ---@param drag_type DragDropType
    ---@param payload_fxNumber number
        function(_,
                 drag_type,
                 payload_fxNumber)
            return true, payload_fxNumber
        end,
    ImGui_WindowFlags_NoScrollWithMouse = function() return 0 end,
    ImGui_WindowFlags_NoScrollbar = function() return 0 end,
    ImGui_Mod_Alt = function() return 0 end,
    LocalizeString = function() return "" end,
}

local State = require("state.state")
local Fx_box = require("components.Fx_box")
local Fx_separator = require("components.fx_separator")
local drag_drop = require("state.dragAndDrop")

local MockRack = {}
function MockRack:mockInit()
    self.state = State:init("", theme) -- initialize state, query selected track and its fx
    self.ctx = {}
    self.Browser = nil
    return self
end

describe("Drag and Drop tests", function()
    local rack = MockRack:mockInit()
    Fx_box:init(rack)
    Fx_separator:init(rack)
    rack.state:update():getTrackFx()

    --- move fx[1] to last position
    -- then move fx[1] to middle position
    ---@param origin_fx integer current index of the fx to be moved
    ---@param destination_position integer the destination-fx_separator’s index - don’t confuse with fx.index
    local function moveFX(origin_fx, destination_position)
        rack.state:update():getTrackFx()
        local Track = rack.state.Track
        assert.truthy(Track)
        if not Track then return end
        assert.True(
            fx[1].guid == Track.fx_list[1].guid
            and fx[2].guid == Track.fx_list[2].guid
            and fx[3].guid == Track.fx_list[3].guid
        ) --- assert fx_by_guid was also updated

        function _G.reaper.ImGui_BeginDragDropTarget() return true end

        ---feed the component the index of the fx we want to move
        function _G.reaper.ImGui_AcceptDragDropPayload()
            return true, origin_fx
        end

        ---Since we’re only re-ordering, don’t activate the «copy» key-modifier
        function _G.reaper.ImGui_IsKeyDown() return false end

        function _G.reaper.TrackFX_CopyToTrack(_, src_fx, _, dest_fx, is_move)
            local is_descending = dest_fx > src_fx
            src_fx = src_fx + 1
            dest_fx = dest_fx + (is_descending and 2 or 1)
            --- insert src_fx at dest_fx position, then remove src_fx.
            --- find fx_by_guid and update the index
            table.insert(fx, dest_fx, Track.fx_list[src_fx])
            if is_move then
                if not is_descending then
                    src_fx = src_fx + 1
                end
                table.remove(fx, src_fx)
            end
        end

        --- move fx[1] to last position
        Fx_separator:dragDropTarget(destination_position)
        rack.state:update():getTrackFx()

        local fx_list = Track.fx_list
        assert.are.same(fx_list[#fx_list].guid, fx[#fx].guid)                    --- assert fx[1] has been moved to end of fx_list
        assert.True(rack.state.Track.fx_by_guid[fx[#fx].guid].index == #fx_list) --- assert fx_by_guid was also updated

        assert.are.same(fx_list[1].guid, fx[1].guid)
        assert.True(rack.state.Track.fx_by_guid[fx[1].guid].index == 1)

        assert.are.same(fx_list[2].guid, fx[2].guid)
        assert.True(rack.state.Track.fx_by_guid[fx[2].guid].index == 2)
    end
    describe("drag and drop: move fx down #drag_drop", function()
        it("drag and drop: move first fx to end of list", function()
            fx = create_fx()
            local origin_fx = 1
            local destination_position = #fx + 1
            moveFX(origin_fx, destination_position)
            assert.True(fx[1].guid == "fx_guid" .. 2) --- assert fx[1] has been moved to end of fx_list
        end)
        it("drag and drop: move first fx to middle of list", function()
            fx = create_fx()
            local origin_fx = 1
            local destination_position = 3
            moveFX(origin_fx, destination_position)
            assert.True(fx[1].guid == "fx_guid" .. 2)
        end)
        it("drag and drop: move first fx to adjacent position", function()
            --- try to move the fx to the position immediately RIGHT of the current one
            fx = create_fx()
            local origin_fx = 1
            local destination_position = 2
            moveFX(origin_fx, destination_position)
            assert.True(fx[1].guid == "fx_guid" .. 1)

            --- Do it again, trying to move to the position immediately LEFT of the current one
            fx = create_fx()
            local origin_fx = 1
            local destination_position = 1
            moveFX(origin_fx, destination_position)
            assert.True(fx[1].guid == "fx_guid" .. 1)
        end)
    end)
    describe("drag and drop: move fx up #drag_drop", function()
        it("drag and drop: move last fx to start of list", function()
            fx = create_fx()
            local origin_fx = 3
            local destination_position = 1
            moveFX(origin_fx, destination_position)
            assert.True(fx[1].guid == "fx_guid" .. 3)
        end)
        it("drag and drop: move last fx to middle of list", function()
            fx = create_fx()
            local origin_fx = 3
            local destination_position = 2
            moveFX(origin_fx, destination_position)
            assert.True(fx[2].guid == "fx_guid" .. 3)
        end)
        it("drag and drop: move last fx to adjacent position", function()
            fx = create_fx()
            local origin_fx = 3
            local destination_position = 3
            moveFX(origin_fx, destination_position)
            assert.True(fx[3].guid == "fx_guid" .. 3)
        end)
        it("drag and drop: move middle fx to first position", function()
            fx = create_fx()
            local origin_fx = 2
            local destination_position = 1
            moveFX(origin_fx, destination_position)
            assert.True(fx[1].guid == "fx_guid" .. 2)
        end)
    end)
end)
