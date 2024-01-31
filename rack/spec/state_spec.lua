require 'busted.runner' ()
local State = require("state.state")
local table_helpers = require("helpers.table")

local function create_fx()
    ---Setup some FX to pass into the state
    ---@type TrackFX[]
    local fx = {}
    for idx = 1, 3 do
        ---@type TrackFX
        local cur_fx = {
            number = idx,
            name = "fxname" .. idx,
            guid = "fx_guid" .. idx,
            enabled = true,
            index = idx
        }
        table.insert(fx, cur_fx)
    end
    return fx
end
describe("State tests", function()
    _G.reaper = {
        GetLastTouchedFX = function() --[[ last_fx]] end,
        GetSelectedTrack2 = function() --[[MediaTrack]] end,
        GetTrackGUID = function() --[[trackGuid]] end,
        GetTrackName = function() --[[_, trackname]] end,
        TrackFX_Delete = function() --[[has_deleted]] end,
        TrackFX_GetCount = function() --[[trackFxCount]] end,
        TrackFX_GetEnabled = function() --[[fxEnabled]] end,
        TrackFX_GetFXGUID = function() --[[fxGuid]] end,
        TrackFX_GetFXName = function() --[[_, fxname]] end,
        TrackFX_GetParamName = function() --[[_, paramName]] end,
    }

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

    ---initialize state and pass the correct values
    local state = State:init()
    it("should initialize the state and fetch its values", function()
        assert.is_nil(state.Track)
        local fx = create_fx()

        _G.reaper.GetSelectedTrack2 = function() return {} end
        _G.reaper.TrackFX_GetCount = function() return #fx end
        _G.reaper.TrackFX_GetFXGUID = function(_, idx) return fx[idx + 1].guid end
        _G.reaper.TrackFX_GetFXName = function(_, idx)
            if not idx then return "" end
            return fx[idx + 1].name
        end


        local GetSelectedTrack2 = spy.on(_G.reaper, "GetSelectedTrack2")
        local TrackFX_GetCount = spy.on(_G.reaper, "TrackFX_GetCount")
        local TrackFX_GetFXGUID = spy.on(_G.reaper, "TrackFX_GetFXGUID")
        local TrackFX_GetFXName = spy.on(_G.reaper, "TrackFX_GetFXName")


        state:update():getTrackFx()

        assert.spy(GetSelectedTrack2).was.called(1)
        assert.spy(TrackFX_GetCount).was.called(1)
        assert.spy(TrackFX_GetFXGUID).was.called(4)
        assert.spy(TrackFX_GetFXName).was.called(4)
        assert.are.same(state.Track.fx_count, #fx, #state.Track.fx_list)
        assert.are.same(state.Track.fx_list[1].guid, fx[1].guid)
        assert.are.same(state.Track.fx_list[2].guid, fx[2].guid)
        assert.are.same(state.Track.fx_list[3].guid, fx[3].guid)
    end)
    it("should handle removing fx using internal functions", function()
        _G.reaper.TrackFX_Delete = function(_, _) return true end
        local TrackFX_Delete = spy.on(_G.reaper, "TrackFX_Delete")
        local fx = create_fx()

        state:deleteFx(2)
        assert.True(state.Track.fx_count == 2)
        assert.True(#state.Track.fx_list == 2)
        assert.True(table_helpers.namedTableLength(state.Track.fx_by_guid) == 2)

        assert.spy(TrackFX_Delete).was.called(1)
        assert.is_not["nil"](state.Track.fx_by_guid[fx[1].guid].guid)
        assert.is_not["nil"](state.Track.fx_by_guid[fx[3].guid].guid)
    end)

    pending("it should handle updating the state with new fx")
end)
