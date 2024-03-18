require 'busted.runner' ()
local State = require("state.state")
local table_helpers = require("helpers.table")
local spec_helpers = require("spec.spec_helpers")
local create_fx = spec_helpers.create_fx
local dummy_theme = require("spec.dummy_theme")
local theme = dummy_theme.theme

describe("State tests", function()
    local fx = create_fx()
    ---initialize state and pass the correct values
    _G.reaper = {
        TrackFX_GetNumParams = function() return 0 end,
        GetMediaTrackInfo_Value = function() return "trackNumber" end,
        GetLastTouchedFX = function() --[[ last_fx]] end,
        GetSelectedTrack2 = function() --[[MediaTrack]] end,
        GetTrackGUID = function() --[[trackGuid]] end,
        GetTrackName = function() --[[_, trackname]] end,
        TrackFX_Delete = function() --[[has_deleted]] end,
        TrackFX_GetCount = function() --[[trackFxCount]] end,
        TrackFX_GetEnabled = function(tr, fxnumber)
            if not fx[fxnumber + 1] then return nil end
            return fx[fxnumber + 1].enabled
        end,
        TrackFX_GetFXGUID = function() --[[fxGuid]] end,
        TrackFX_GetFXName = function(track, fx_number)
            return true, fx[fx_number + 1].name
        end,
        TrackFX_GetParamName = function() --[[_, paramName]] end,
        TrackFX_GetPreset = function(track, fx_number) return nil, "" end,
        ImGui_ColorConvertU32ToDouble4 = function(rgba) return 0.1, 0.1, 0.1, 0.1 end,
        ImGui_ColorConvertRGBtoHSV = function(r, g, b) return 0.1, 0.1, 0.1, 0.1 end,
        ImGui_ColorConvertHSVtoRGB = function(r, g, b) return 0.1, 0.1, 0.1, 0.1 end
    }
    local state = State:init("", theme)

    -- these are the calls that state:update() makes
    -- local track        = reaper.GetSelectedTrack2(0, 0, false)
    -- local _, trackName = reaper.GetTrackName(track)
    -- local has_deleted  = reaper.TrackFX_Delete(self.Track.track, fx.index - 1)
    -- local trackGuid    = reaper.GetTrackGUID(track) -- get the track's GUID
    -- local trackFxCount = reaper.TrackFX_GetCount(track)
    -- local last_fx      = reaper.GetLastTouchedFX()
    -- local _, fxName    = reaper.TrackFX_GetFXName(track, fxNumber)
    -- local _, paramName = reaper.TrackFX_GetParamName(track, fxNumber, paramNumber)
    -- local fxGuid       = reaper.TrackFX_GetFXGUID(track, fxNumber or 0)
    -- local fxEnabled    = reaper.TrackFX_GetEnabled(track, fxNumber)
    -- local fxGuid       = reaper.TrackFX_GetFXGUID(self.Track.track, idx)
    -- local _, fxName    = reaper.TrackFX_GetFXName(self.Track.track, idx)
    -- local fxEnabled    = reaper.TrackFX_GetEnabled(self.Track.track, idx)


    _G.reaper.GetSelectedTrack2 = function() return {} end
    _G.reaper.TrackFX_GetCount = function() return #fx end
    _G.reaper.TrackFX_GetFXGUID = function(_, idx) return fx[idx + 1].guid end
    _G.reaper.TrackFX_GetFXName = function(_, idx)
        if not idx then return "" end
        return nil, fx[idx + 1].name
    end
    _G.reaper.TrackFX_Delete = function(_, _) return true end

    it("state initialize #state_update", function()
        assert.is_nil(state.Track)
    end)
    it("state sets to nil if no track is selected #state_update", function()
        state:update():getTrackFx()
        assert.is_truthy(state.Track)

        _G.reaper.GetSelectedTrack2 = function() return nil end
        state:update():getTrackFx()
        assert.is_nil(state.Track)

        _G.reaper.GetSelectedTrack2 = function() return {} end -- set the function back
    end)
    it("read fx - read fx_list from reaper #state_update", function()
        local GetSelectedTrack2 = spy.on(_G.reaper, "GetSelectedTrack2")
        local TrackFX_GetCount = spy.on(_G.reaper, "TrackFX_GetCount")
        local TrackFX_GetFXGUID = spy.on(_G.reaper, "TrackFX_GetFXGUID")
        local TrackFX_GetFXName = spy.on(_G.reaper, "TrackFX_GetFXName")

        state:update():getTrackFx()

        assert.spy(GetSelectedTrack2).was.called(1)
        assert.spy(TrackFX_GetCount).was.called(1)
        assert.spy(TrackFX_GetFXGUID).was.called(3)
        assert.spy(TrackFX_GetFXName).was.called(3)
        assert.are.same(state.Track.fx_count, #fx)
        assert.are.same(#state.Track.fx_list, #fx)

        assert.are.same(state.Track.fx_list[1].guid, fx[1].guid)
        assert.True(state.Track.fx_by_guid[fx[1].guid].index == 1)
        assert.True(state.Track.fx_list[1].index == 1)
        assert.True(state.Track.fx_list[1].name == fx[1].name)

        assert.are.same(state.Track.fx_list[2].guid, fx[2].guid)
        assert.True(state.Track.fx_by_guid[fx[2].guid].index == 2)
        assert.True(state.Track.fx_list[2].index == 2)
        assert.True(state.Track.fx_list[2].name == fx[2].name)

        assert.are.same(state.Track.fx_list[3].guid, fx[3].guid)
        assert.True(state.Track.fx_by_guid[fx[3].guid].index == 3)
        assert.True(state.Track.fx_list[3].index == 3)
        assert.True(state.Track.fx_list[3].name == fx[3].name)
    end)

    it("remove fx - state:deleteFx (from inside the rack) #state_update", function()
        local TrackFX_Delete = spy.on(_G.reaper, "TrackFX_Delete")
        fx = create_fx()
        state:update():getTrackFx()


        state:deleteFx(2)
        local modified = fx[2]
        modified.index = 2
        modified.number = 1
        assert.True(state.Track.fx_count == 2)
        assert.True(#state.Track.fx_list == 2)
        assert.True(table_helpers.namedTableLength(state.Track.fx_by_guid) == 2)

        assert.spy(TrackFX_Delete).was.called(1)

        assert.True(state.Track.fx_by_guid[fx[2].guid] == nil) -- check that fx was removed

        assert.Truthy(state.Track.fx_by_guid[fx[1].guid])      -- check that fx[1] is still in same position
        assert.True(state.Track.fx_by_guid[fx[1].guid].index == 1)
        assert.True(state.Track.fx_list[1].index == 1)
        assert.are.same(state.Track.fx_list[1].guid, fx[1].guid)

        assert.Truthy(state.Track.fx_by_guid[fx[3].guid]) -- check that fx[3] is now in second position in fx_list and fx_guid
        assert.True(state.Track.fx_by_guid[fx[3].guid].index == 2)
        assert.True(state.Track.fx_list[2].index == 2)
        assert.are.same(state.Track.fx_list[2].guid, fx[3].guid)
    end)

    ---@param idx number
    local function removeFX(idx)
        state:update():getTrackFx() -- update state to contain all fx again
        local guid_to_be_removed = fx[idx].guid
        table.remove(fx, idx)       -- remove middle one from fx
        local modified = fx[2]
        modified.index = 2
        modified.number = 1
        state:update():getTrackFx() -- update state
        assert.are.same(state.Track.fx_count, #fx, #state.Track.fx_list)
        assert.are.same(#state.Track.fx_list, #fx)
        assert.True(state.Track.fx_by_guid[guid_to_be_removed] == nil)

        -- same as previous test
        assert.Truthy(state.Track.fx_by_guid[fx[1].guid]) -- check that fx[1] is still in same position
        assert.True(state.Track.fx_by_guid[fx[1].guid].index == 1)
        assert.True(state.Track.fx_list[1].index == 1)
        assert.are.same(state.Track.fx_list[1].guid, fx[1].guid)
        assert.are.same(state.Track.fx_list[1].name, fx[1].name)
        assert.are.same(state.Track.fx_list[1].enabled, fx[1].enabled)


        assert.Truthy(state.Track.fx_by_guid[fx[2].guid]) -- check that fx[3] is now in second position in fx_list and fx_guid
        assert.True(state.Track.fx_by_guid[fx[2].guid].index == 2)
        assert.True(state.Track.fx_list[2].index == 2)
        assert.are.same(state.Track.fx_list[2].guid, fx[2].guid)
        assert.are.same(state.Track.fx_list[2].name, fx[2].name)
        assert.are.same(state.Track.fx_list[2].enabled, fx[2].enabled)
    end
    ---FIXME if reaper removes an fx, this state doesn’t get updated correctly
    it("remove fx - remove middle fx from fx_list (from outside) #state_update", function()
        fx = create_fx()
        removeFX(2)
    end)
    pending("remove multiple fx in the middle of the list")
    it("remove fx - remove last fx from fx_list (from outside) #state_update", function()
        fx = create_fx()
        removeFX(3)
    end)

    it("update fx - change order of fx (from outside) #state_update", function()
        fx = create_fx()
        state:update():getTrackFx()
        fx[1], fx[2] = fx[2], fx[1]
        assert.True(#fx == 3)
        state:update():getTrackFx()
        assert.are.same(state.Track.fx_count, #fx, #state.Track.fx_list)

        assert.True(state.Track.fx_by_guid[fx[1].guid].index == 1)
        assert.True(state.Track.fx_by_guid[fx[2].guid].index == 2)
        assert.True(state.Track.fx_list[1].index == 1)
        assert.True(state.Track.fx_list[2].index == 2)
        assert.are.same(state.Track.fx_list[3].guid, fx[3].guid)
        assert.True(state.Track.fx_by_guid[fx[3].guid].index == 3)
    end)

    it("update fx - if an fx's 'enabled' is changed", function()
        fx = create_fx()
        state:update():getTrackFx()
        local modified = fx[2]
        modified.enabled = false
        assert.True(#fx == 3)
        state:update():getTrackFx()
        assert.are.same(state.Track.fx_count, #fx, #state.Track.fx_list)

        assert.True(state.Track.fx_by_guid[fx[1].guid].index == 1)
        assert.True(state.Track.fx_by_guid[fx[2].guid].index == 2)
        assert.True(state.Track.fx_list[1].index == 1)
        assert.True(state.Track.fx_list[2].index == 2)
        assert.True(state.Track.fx_list[2].enabled == false)

        assert.are.same(state.Track.fx_list[3].guid, fx[3].guid)
        assert.True(state.Track.fx_by_guid[fx[3].guid].index == 3)
    end)
end)
